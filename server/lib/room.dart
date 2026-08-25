/// 对战房间：联机服务的核心业务逻辑。
///
/// 【零 IO 设计】本文件不 import dart:io——消息出口抽象为 [RoomSink]，
/// 真实服务器用 WebSocket 实现，单元测试用内存实现。
/// 这让「断线重连」「判负时机」「再战投票」这些最容易出 bug 的
/// 流程可以在毫秒级测试里反复演练。
///
/// 【权威判定】所有落子都经 [handleMove] 校验：阶段、轮次、合法性
/// 三关全过才落盘。客户端永远只是「提议」，这里才是真相。
library;

import 'dart:math';

import 'package:five_core/five_core.dart';

/// 房间向玩家投递消息的出口。
abstract class RoomSink {
  /// 向指定颜色的座位发消息（仅当该座位在线时才会真正送达）。
  void send(String seatColor, Map<String, Object?> message);
}

/// 加入结果：分配到的颜色与终身重连令牌。
class JoinResult {
  final String color;
  final String token;
  const JoinResult(this.color, this.token);
}

class Room {
  final String id;
  final RoomSink sink;

  /// 断线判负的宽限时长（外层据此设置定时器）。
  static const Duration reconnectGrace = Duration(seconds: 60);

  final Board _board = Board();
  final List<Point> _moves = [];

  /// 各座位的重连令牌：color → token。加入即占座，直到主动离开。
  final Map<String, String> _tokens = {};

  /// 当前在线的座位。
  final Set<String> _connected = {};

  /// 再战投票（终局后收集双方意图）。
  final Set<String> _rematchVotes = {};

  RoomPhase _phase = RoomPhase.waiting;
  WinInfo? _winInfo;

  Room(this.id, this.sink);

  // ---- 只读视图（供服务器层与测试断言） ----

  RoomPhase get phase => _phase;
  List<Point> get moves => List.unmodifiable(_moves);
  WinInfo? get winInfo => _winInfo;
  bool hasSeat(String color) => _tokens.containsKey(color);
  bool isConnected(String color) => _connected.contains(color);
  String? tokenOf(String color) => _tokens[color];
  bool get isFull => _tokens.length >= 2;

  static final Random _random = Random();

  // ------------------------------------------------------------------
  // 入座 / 重连 / 掉线
  // ------------------------------------------------------------------

  /// 尝试入座；满员返回 null。
  ///
  /// 首位玩家执黑并收到 [Msg.created]；
  /// 第二位玩家执白、收到带完整状态的 [Msg.joined]，
  /// 同时黑方收到 [Msg.peerJoined] —— 双方随即进入对局。
  JoinResult? join() {
    if (isFull) return null;
    final color = _tokens.isEmpty ? SeatColor.black : SeatColor.white;
    final token = _genToken();
    _tokens[color] = token;
    _connected.add(color);

    if (_tokens.length == 1) {
      // 先手等待中：只确认占座，不发局面。
      sink.send(color, {
        Msg.type: Msg.created,
        Msg.roomId: id,
        Msg.color: color,
        Msg.token: token,
        'phase': _phase.name,
      });
    } else {
      _beginPlaying();
      _sendState(SeatColor.white, Msg.joined);
      _sendState(SeatColor.black, Msg.peerJoined);
    }
    return JoinResult(color, token);
  }

  /// 凭令牌重新入座（断线重连）。校验颜色与令牌匹配。
  bool rejoin(String color, String token) {
    if (_tokens[color] != token) return false;
    final wasOffline = !_connected.contains(color);
    _connected.add(color);

    if (_phase == RoomPhase.reconnecting && wasOffline) {
      _phase = RoomPhase.playing; // 对局恢复
      _sendToOther(color, {Msg.type: Msg.peerRejoined});
    }
    _sendState(color, Msg.rejoined);
    return true;
  }

  /// 玩家掉线：对局中进入限时等待；等待对手阶段直接腾出房间。
  void markDisconnected(String color) {
    final wasSeated = _connected.remove(color);
    if (!wasSeated) return;

    if (_phase == RoomPhase.playing) {
      _phase = RoomPhase.reconnecting;
      _sendToOther(color, {Msg.type: Msg.peerLeft});
    } else if (_phase == RoomPhase.waiting) {
      _resetSeats(); // 还没开局，房间回到可加入状态
    }
    // reconnecting 阶段再次掉线：维持等待状态即可。
  }

  /// 重连宽限期已过仍未归队 → 判负。
  void onReconnectTimeout(String color) {
    if (_phase != RoomPhase.reconnecting || isConnected(color)) return;
    _finish(SeatColor.opposite(color), 'disconnect');
  }

  // ------------------------------------------------------------------
  // 对局动作
  // ------------------------------------------------------------------

  /// 处理落子提议。任何不合法的情况静默拒绝：
  /// 客户端 UI 已先行拦截，能到这里还非法的消息视为异常客户端。
  void handleMove(String color, int x, int y) {
    if (_phase != RoomPhase.playing) return;
    if (!isConnected(color)) return;
    if (!Board.inBounds(x, y) || !_board.isEmpty(x, y)) return;

    final stone = SeatColor.toStone(color);
    final expected = _moves.length.isEven ? Cell.black : Cell.white;
    if (stone != expected) return; // 没轮到你

    _board.place(x, y, stone);
    _moves.add(Point(x, y));

    final win = Rules.checkWin(_board, x, y);
    if (win != null) {
      _winInfo = win;
      _finish(SeatColor.fromStone(win.winner), 'five');
      return;
    }
    if (_board.isFull) {
      _finish(null, 'board_full');
      return;
    }

    // 全量回传手顺：见 protocol.dart 的设计说明。
    final payload = {
      Msg.type: Msg.moveApplied,
      Msg.moves: encodeMoves(_moves),
      'last': [x, y],
    };
    for (final seat in SeatColor.all) {
      if (isConnected(seat)) sink.send(seat, payload);
    }
  }

  /// 认输。
  void handleResign(String color) {
    if (_phase != RoomPhase.playing && _phase != RoomPhase.reconnecting) {
      return;
    }
    if (!hasSeat(color)) return;
    _finish(SeatColor.opposite(color), 'resign');
  }

  /// 再战投票；双方同意后开新局（座位与令牌保持不变，黑白互换让公平）。
  void voteRematch(String color) {
    if (_phase != RoomPhase.finished) return;
    _rematchVotes.add(color);
    _sendToOther(color, {Msg.type: Msg.rematchRequested});
    if (_rematchVotes.length == 2) {
      for (final seat in _tokens.keys.toList()) {
        if (isConnected(seat)) sink.send(seat, {Msg.type: Msg.newGame});
      }
      _swapSeats();
      _beginPlaying();
      for (final seat in _tokens.keys.toList()) {
        _sendState(seat, Msg.joined);
      }
    }
  }

  /// 主动离开：对局中等同认输；其他情况清出座位。
  void handleLeave(String color) {
    if (_phase == RoomPhase.playing || _phase == RoomPhase.reconnecting) {
      handleResign(color);
      return;
    }
    _connected.remove(color);
    _tokens.remove(color);
    if (_phase == RoomPhase.finished && _rematchVotes.remove(color) &&
        _tokens.isEmpty) {
      _resetSeats();
    }
  }

  // ------------------------------------------------------------------
  // 内部流程
  // ------------------------------------------------------------------

  /// 进入对局阶段（第二人加入或双方同意再战后调用）。
  void _beginPlaying() {
    _board.clear();
    _moves.clear();
    _winInfo = null;
    _rematchVotes.clear();
    _phase = RoomPhase.playing;
  }

  /// 再战时交换黑白，消除先手优势的不公平。
  void _swapSeats() {
    final blackToken = _tokens[SeatColor.black];
    _tokens[SeatColor.black] = _tokens[SeatColor.white]!;
    _tokens[SeatColor.white] = blackToken!;
  }

  void _finish(String? winnerColor, String reason) {
    _phase = RoomPhase.finished;
    final result = winnerColor == null
        ? '0'
        : '${winnerColor == SeatColor.black ? 'B' : 'W'}+$reason';
    final payload = {
      Msg.type: Msg.gameOver,
      Msg.result: result,
      Msg.reason: reason,
      if (_winInfo != null) Msg.line: encodeLine(_winInfo!.line),
    };
    for (final seat in _tokens.keys.toList()) {
      if (isConnected(seat)) sink.send(seat, payload);
    }
  }

  /// 完整状态同步（加入/重连/开局确认时）。
  void _sendState(String color, String type) {
    sink.send(color, {
      Msg.type: type,
      Msg.roomId: id,
      Msg.color: color,
      Msg.token: _tokens[color],
      Msg.moves: encodeMoves(_moves),
      'phase': _phase.name,
      if (_winInfo != null) Msg.line: encodeLine(_winInfo!.line),
    });
  }

  void _sendToOther(String color, Map<String, Object?> message) {
    final other = SeatColor.opposite(color);
    if (isConnected(other)) sink.send(other, message);
  }

  void _resetSeats() {
    _tokens.clear();
    _connected.clear();
    _board.clear();
    _moves.clear();
    _winInfo = null;
    _rematchVotes.clear();
    _phase = RoomPhase.waiting;
  }

  static String _genToken() =>
      List.generate(3, (_) => _random.nextInt(0xFFFFFFFF).toRadixString(36))
          .join();
}
