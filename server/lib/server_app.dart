/// WebSocket 服务壳层：连接管理 + 消息路由 + 断线计时。
///
/// 【分层】Room（纯逻辑）不碰网络；本文件负责：
/// - HTTP 升级为 WebSocket；
/// - 把每条消息解析后路由到对应房间的对应方法；
/// - 掉线时启动宽限定时器，超时调用 room.onReconnectTimeout；
/// - 空房间回收，防内存泄漏。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:five_core/five_core.dart';

import 'room.dart';

/// 单个客户端连接的服务器侧视图。
class ClientConnection {
  final WebSocket socket;

  /// 入座信息：加入/重连成功后填充。
  String? roomId;
  String? seatColor;
  String? token;

  ClientConnection(this.socket);
}

class FiveServer {
  final HttpServer httpServer;

  /// roomId → 房间。
  final Map<String, Room> _rooms = {};

  /// 在线连接注册表：roomId → seatColor → socket。
  /// [RoomSink] 投递消息时按此反查。
  final Map<String, Map<String, WebSocket>> _roomSeats = {};

  /// 重连宽限定时器：roomId → (color → timer)。
  final Map<String, Map<String, Timer>> _graceTimers = {};

  static final Random _random = Random();

  /// 当前活跃房间数（健康检查用）。
  int get roomCount => _rooms.length;

  FiveServer._(this.httpServer);

  /// 取出某房间某座位当前的在线 socket（供 sink 投递）。
  Iterable<WebSocket> socketsFor(String roomId, String seatColor) sync* {
    final socket = _roomSeats[roomId]?[seatColor];
    if (socket != null) yield socket;
  }

  /// 在 [port] 上启动服务。返回运行中的实例。
  static Future<FiveServer> start({
    int port = 8080,
    InternetAddress? address,
  }) async {
    final server = await HttpServer.bind(
      address ?? InternetAddress.anyIPv4,
      port,
    );
    final app = FiveServer._(server);
    server.listen(app._handleHttp, onError: (_) {});
    return app;
  }

  Future<void> stop() async {
    for (final timers in _graceTimers.values) {
      for (final t in timers.values) {
        t.cancel();
      }
    }
    await httpServer.close(force: true);
  }

  // ------------------------------------------------------------------
  // 连接生命周期
  // ------------------------------------------------------------------

  void _handleHttp(HttpRequest request) {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      WebSocketTransformer.upgrade(request).then(_handleSocket);
    } else {
      // 健康检查端点：部署平台探活用。
      if (request.uri.path == '/health') {
        request.response
          ..write(jsonEncode({'ok': true, 'rooms': _rooms.length}))
          ..close();
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.close();
      }
    }
  }

  void _handleSocket(WebSocket socket) {
    final client = ClientConnection(socket);
    // 连接关闭/出错都会走 onDone/onError → 统一进入断线处理；
    // 无需保留订阅句柄——socket 销毁时监听随之结束。
    socket.listen(
      (data) => _handleMessage(client, data),
      onDone: () => _handleDisconnect(client),
      onError: (_) => _handleDisconnect(client),
      cancelOnError: true,
    );
  }

  void _handleDisconnect(ClientConnection client) {
    final room = _rooms[client.roomId];
    final color = client.seatColor;
    if (room == null || color == null) return;

    // 从注册表摘除该连接。
    final seatSocket = _roomSeats[room.id]?[color];
    if (identical(seatSocket, client.socket)) {
      _roomSeats[room.id]!.remove(color);
      if (_roomSeats[room.id]!.isEmpty) _roomSeats.remove(room.id);
    }

    room.markDisconnected(color);

    if (room.phase == RoomPhase.reconnecting) {
      // 启动判负倒计时；期间重连则取消。
      _graceTimers.putIfAbsent(room.id, () => {})[color]?.cancel();
      _graceTimers[room.id]![color] = Timer(Room.reconnectGrace, () {
        room.onReconnectTimeout(color);
        _maybeCollectRoom(room.id);
      });
    } else if (room.phase == RoomPhase.waiting) {
      _maybeCollectRoom(room.id);
    }
  }

  // ------------------------------------------------------------------
  // 消息路由
  // ------------------------------------------------------------------

  void _handleMessage(ClientConnection client, Object? data) {
    Map<String, Object?> msg;
    try {
      msg = (jsonDecode(data as String) as Map).cast<String, Object?>();
    } catch (_) {
      return; // 非 JSON / 非对象：静默忽略。
    }
    switch (msg[Msg.type]) {
      case Msg.ping:
        client.socket.add(jsonEncode({Msg.type: Msg.pong}));
      case Msg.create:
        _createRoom(client);
      case Msg.join:
        _joinRoom(client, msg[Msg.roomId] as String? ?? '');
      case Msg.rejoin:
        _rejoinRoom(client, msg);
      case Msg.move:
        _withOwnRoom(client, (room) => room.handleMove(
              client.seatColor!,
              (msg[Msg.x] as num?)?.toInt() ?? -1,
              (msg[Msg.y] as num?)?.toInt() ?? -1,
            ));
      case Msg.resign:
        _withOwnRoom(client, (room) => room.handleResign(client.seatColor!));
      case Msg.leave:
        _withOwnRoom(client, (room) => room.handleLeave(client.seatColor!));
        client.roomId = null;
        client.seatColor = null;
      case Msg.rematch || Msg.rematchAccept:
        _withOwnRoom(
            client, (room) => room.voteRematch(client.seatColor!));
    }
  }

  /// 只在已入座时才执行动作的守卫。
  void _withOwnRoom(ClientConnection client, void Function(Room) action) {
    final room = _rooms[client.roomId];
    final color = client.seatColor;
    if (room == null || color == null) return;
    action(room);
  }

  // ------------------------------------------------------------------
  // 入座流程
  // ------------------------------------------------------------------

  void _createRoom(ClientConnection client) {
    // 一个连接同时只在一个房间里。
    if (client.roomId != null) return;

    String roomId;
    do {
      roomId = (1000 + _random.nextInt(9000)).toString();
    } while (_rooms.containsKey(roomId));

    final room = Room(roomId, _WebSocketSink(roomId, this));
    _rooms[roomId] = room;

    final result = room.join();
    _bindClient(client, roomId, result!.color, result.token);
  }

  void _joinRoom(ClientConnection client, String roomId) {
    if (client.roomId != null) return;
    final room = _rooms[roomId];
    if (room == null) {
      client.socket.add(jsonEncode({Msg.type: Msg.error, Msg.message: '房间不存在'}));
      return;
    }
    final result = room.join();
    if (result == null) {
      client.socket.add(jsonEncode({Msg.type: Msg.error, Msg.message: '房间已满'}));
      return;
    }
    _bindClient(client, roomId, result.color, result.token);
  }

  void _rejoinRoom(ClientConnection client, Map<String, Object?> msg) {
    final roomId = msg[Msg.roomId] as String?;
    final token = msg[Msg.token] as String?;
    final room = _rooms[roomId ?? ''];
    if (room == null || token == null) {
      client.socket.add(jsonEncode({Msg.type: Msg.error, Msg.message: '无法重连'}));
      return;
    }

    // 凭令牌找到自己的座位（重连可能换了颜色——再战后黑白互换）。
    for (final seat in SeatColor.all) {
      if (room.tokenOf(seat) == token) {
        final ok = room.rejoin(seat, token);
        if (!ok) break;
        _bindClient(client, room.id, seat, token);
        _graceTimers[room.id]?[seat]?.cancel();
        return;
      }
    }
    client.socket.add(jsonEncode({Msg.type: Msg.error, Msg.message: '无法重连'}));
  }

  void _bindClient(
    ClientConnection client,
    String roomId,
    String color,
    String token,
  ) {
    client.roomId = roomId;
    client.seatColor = color;
    client.token = token;
    // 注册进投递表（重连时覆盖旧 socket——旧连接若还在会被自然淘汰）。
    _roomSeats.putIfAbsent(roomId, () => {})[color] = client.socket;
  }

  /// 房间无人且无对局价值时回收。
  void _maybeCollectRoom(String roomId) {
    final room = _rooms[roomId];
    if (room == null) return;
    final empty = !room.isConnected(SeatColor.black) &&
        !room.isConnected(SeatColor.white);
    if (empty && room.phase != RoomPhase.playing) {
      _rooms.remove(roomId);
      _graceTimers.remove(roomId)?.values.forEach((t) => t.cancel());
    }
  }
}

/// [RoomSink] 的 WebSocket 实现：按座位找到在线连接并发送。
///
/// 连接与座位的映射由 [_bindClient] 维护在连接对象上，
/// 这里反查：遍历该房间的所有连接找匹配座位。
class _WebSocketSink implements RoomSink {
  final String roomId;
  final FiveServer server;

  _WebSocketSink(this.roomId, this.server);

  @override
  void send(String seatColor, Map<String, Object?> message) {
    // 查找实现见 FiveServer._connectionsOf。
    for (final socket in server.socketsFor(roomId, seatColor)) {
      socket.add(jsonEncode(message));
    }
  }
}
