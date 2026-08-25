/// 房间逻辑单元测试。
///
/// 用内存版 RoomSink 捕获所有出站消息，
/// 完整演练「开局 → 对弈 → 掉线重连/认输 → 再战」全生命周期。
library;

import 'package:five_core/five_core.dart';
import 'package:five_server/room.dart';
import 'package:test/test.dart';

/// 内存信箱：按颜色记录所有发往该玩家的消息。
class MemorySink implements RoomSink {
  final Map<String, List<Map<String, Object?>>> inbox = {};

  @override
  void send(String seatColor, Map<String, Object?> message) =>
      inbox.putIfAbsent(seatColor, () => []).add(message);

  /// 该玩家收到的第 [n] 条（0 起）指定类型消息。
  Map<String, Object?> msg(String color, String type, [int n = 0]) =>
      inbox[color]!.where((m) => m[Msg.type] == type).toList()[n];
}

void main() {
  late MemorySink sink;
  late Room room;

  setUp(() {
    sink = MemorySink();
    room = Room('1234', sink);
  });

  /// 标准开局：两人入座并走一手黑棋到 (7,7)。
  JoinResult setupPlaying() {
    room.join();
    final white = room.join()!;
    expect(room.phase, RoomPhase.playing);
    return white;
  }

  group('入座与开局', () {
    test('首人执黑等待，次人执白即开局', () {
      final black = room.join()!;
      expect(black.color, SeatColor.black);
      expect(room.phase, RoomPhase.waiting);

      final white = room.join()!;
      expect(white.color, SeatColor.white);
      expect(room.phase, RoomPhase.playing);

      expect(sink.msg(SeatColor.black, Msg.created)[Msg.type], Msg.created);
      expect(sink.msg(SeatColor.white, Msg.joined)[Msg.color],
          SeatColor.white);
      expect(sink.msg(SeatColor.black, Msg.peerJoined), isNotEmpty);
    });

    test('满员后无法再加入', () {
      room.join();
      room.join();
      expect(room.join(), isNull);
    });
  });

  group('落子判定', () {
    test('合法落子广播全量手顺', () {
      setupPlaying();

      room.handleMove(SeatColor.black, 7, 7);

      for (final color in SeatColor.all) {
        final applied = sink.msg(color, Msg.moveApplied);
        expect(applied[Msg.moves], [
          [7, 7]
        ]);
      }
    });

    test('轮次错误 / 占位 / 界外一律拒绝', () {
      setupPlaying();

      room.handleMove(SeatColor.white, 8, 8); // 白抢黑的手
      room.handleMove(SeatColor.black, -1, 0); // 界外
      room.handleMove(SeatColor.black, 8, 8);
      room.handleMove(SeatColor.black, 9, 9); // 连续两手黑

      expect(room.moves.length, 1); // 只有第一手生效
      expect(room.moves.first, const Point(8, 8));
    });

    test('五连即终局并返回连线', () {
      setupPlaying();

      // 黑连五 (0..4,7)，白随手应四手。
      for (var i = 0; i < 5; i++) {
        room.handleMove(SeatColor.black, i, 7);
        if (i < 4) room.handleMove(SeatColor.white, i, 8);
      }

      final over = sink.msg(SeatColor.black, Msg.gameOver);
      expect(over[Msg.result], 'B+five');
      expect(over[Msg.reason], 'five');
      expect(room.phase, RoomPhase.finished);
      final line = over[Msg.line] as List;
      expect(line.length, 5);
    });
  });

  group('断线与重连', () {
    test('对局中断线进入宽限，对手收到通知', () {
      setupPlaying();
      room.markDisconnected(SeatColor.black);

      expect(room.phase, RoomPhase.reconnecting);
      expect(sink.msg(SeatColor.white, Msg.peerLeft), isNotEmpty);
    });

    test('令牌校验失败的重连被拒', () {
      setupPlaying();
      // 黑方的令牌在其首条消息（created）里。
      expect(sink.msg(SeatColor.black, Msg.created)[Msg.token], isA<String>());

      room.markDisconnected(SeatColor.black);
      expect(room.rejoin(SeatColor.black, 'wrong-token'), isFalse);
      expect(room.phase, RoomPhase.reconnecting);
    });

    test('正确令牌重连恢复对局并同步状态', () {
      room.join();
      room.join();
      final token =
          sink.msg(SeatColor.black, Msg.created)[Msg.token] as String;

      room.handleMove(SeatColor.black, 7, 7);
      room.markDisconnected(SeatColor.black);
      expect(room.rejoin(SeatColor.black, token), isTrue);
      expect(room.phase, RoomPhase.playing);

      final state = sink.msg(SeatColor.black, Msg.rejoined);
      expect(state[Msg.moves], [
        [7, 7]
      ]);
      expect(sink.msg(SeatColor.white, Msg.peerRejoined), isNotEmpty);
    });

    test('宽限超时未归 → 判对方胜', () {
      setupPlaying();
      room.markDisconnected(SeatColor.black);
      room.onReconnectTimeout(SeatColor.black);

      expect(room.phase, RoomPhase.finished);
      expect(sink.msg(SeatColor.white, Msg.gameOver)[Msg.result],
          'W+disconnect');
    });

    test('超时前已重连则不判负', () {
      setupPlaying();
      final token =
          sink.msg(SeatColor.black, Msg.created)[Msg.token] as String;
      room.markDisconnected(SeatColor.black);
      room.rejoin(SeatColor.black, token);
      room.onReconnectTimeout(SeatColor.black);

      expect(room.phase, RoomPhase.playing); // 已归队，无事发生
    });
  });

  group('终局与再战', () {
    test('认输立即终局', () {
      setupPlaying();
      room.handleResign(SeatColor.white);

      expect(room.phase, RoomPhase.finished);
      expect(sink.msg(SeatColor.black, Msg.gameOver)[Msg.result],
          'B+resign');
    });

    test('双方同意再战 → 新局且黑白互换', () {
      setupPlaying();
      room.handleResign(SeatColor.white);
      expect(room.phase, RoomPhase.finished);

      room.voteRematch(SeatColor.black);
      expect(room.phase, RoomPhase.finished); // 只有一票不开局
      expect(
          sink.msg(SeatColor.white, Msg.rematchRequested), isNotEmpty);

      room.voteRematch(SeatColor.white);
      expect(room.phase, RoomPhase.playing);
      // 原黑方的令牌如今对应白色座位。
      final oldBlackToken =
          sink.msg(SeatColor.black, Msg.created)[Msg.token] as String;
      expect(room.tokenOf(SeatColor.white), oldBlackToken);
      // 新局空盘状态已同步（黑方首次收到 joined 就是在新局开始时）。
      expect(sink.msg(SeatColor.black, Msg.joined, 0)[Msg.moves], isEmpty);
    });
  });

  group('房间回收', () {
    test('等待阶段掉线直接腾出房间', () {
      room.join();
      room.markDisconnected(SeatColor.black);
      expect(room.hasSeat(SeatColor.black), isFalse);
      expect(room.join(), isNotNull); // 又能加入了
    });
  });
}
