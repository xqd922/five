/// WebSocket 客户端封装：连接、心跳、消息流。
///
/// 【职责边界】只管「连接活着、消息可达」，
/// 不理解任何业务语义（那是 OnlineController 的事）。
///
/// 【移动网络现实】NAT 网关会在数十秒内掐断空闲 TCP 连接，
/// 因此每 25 秒发一次应用层 ping 保活；
/// 服务端用协议层 pong 应答，双向流量都能刷新 NAT 映射。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:five_core/five_core.dart';

/// 连接状态。
enum WsState {
  /// 未连接（初始/主动关闭后）。
  idle,

  /// 正在建立连接。
  connecting,

  /// 已连接且心跳正常。
  connected,
}

class WsClient {
  WebSocket? _socket;
  Timer? _heartbeat;
  StreamSubscription? _subscription;
  bool _manuallyClosed = false;

  final _stateCtrl = StreamController<WsState>.broadcast();
  final _messageCtrl = StreamController<Map<String, Object?>>.broadcast();

  /// 连接状态流。
  Stream<WsState> get states => _stateCtrl.stream;

  /// 收到的业务消息流（已解码为 JSON Map）。
  Stream<Map<String, Object?>> get messages => _messageCtrl.stream;

  WsState get state =>
      _socket != null && _socket!.readyState == WebSocket.open
          ? WsState.connected
          : (_socket == null ? WsState.idle : WsState.connecting);

  /// 建立连接。重复调用会先关闭旧连接。
  Future<void> connect(String url) async {
    await close();
    _manuallyClosed = false;
    _stateCtrl.add(WsState.connecting);

    try {
      final socket = await WebSocket.connect(url);
      if (_manuallyClosed) {
        // 用户在连接期间放弃了。
        await socket.close();
        return;
      }
      _socket = socket;
      _stateCtrl.add(WsState.connected);

      _subscription = socket.listen(
        (data) {
          if (data is! String) return;
          try {
            final decoded = jsonDecode(data);
            if (decoded is Map) {
              _messageCtrl.add(decoded.cast<String, Object?>());
            }
          } catch (_) {/* 坏帧静默丢弃 */}
        },
        onDone: () => _teardown(),
        onError: (_) => _teardown(),
        cancelOnError: true,
      );

      _startHeartbeat();
    } on SocketException catch (e) {
      _teardown();
      _messageCtrl.add({
        Msg.type: Msg.error,
        Msg.message: '无法连接服务器: ${e.message}',
      });
    }
  }

  /// 发送一条 JSON 消息；未连接时静默丢弃（上层状态机自会感知掉线）。
  void send(Map<String, Object?> message) {
    final socket = _socket;
    if (socket != null && socket.readyState == WebSocket.open) {
      socket.add(jsonEncode(message));
    }
  }

  /// 主动关闭并停止一切定时任务。
  Future<void> close() async {
    _manuallyClosed = true;
    _stopHeartbeat();
    await _subscription?.cancel();
    _subscription = null;
    final socket = _socket;
    _socket = null;
    if (socket != null && socket.readyState == WebSocket.open) {
      await socket.close();
    }
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeat = Timer.periodic(const Duration(seconds: 25), (_) {
      send({Msg.type: Msg.ping});
    });
  }

  void _stopHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  /// 连接意外断开的统一收尾。
  void _teardown() {
    _stopHeartbeat();
    _socket = null;
    if (!_manuallyClosed) _stateCtrl.add(WsState.idle);
  }
}
