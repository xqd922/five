/// 对局的不可变状态快照。
///
/// 【为什么强调不可变】Riverpod 靠「引用是否变化」判断要不要通知 UI 重绘。
/// 如果 Board 被原地修改而 GameState 还是同一个对象，
/// Riverpod 会认为"什么都没发生"，界面就不会更新。
/// 因此每手棋都通过 board.copy() 造出新棋盘、新状态——
/// 整盘才 225 字节，这个拷贝的成本可以忽略不计。
library;

import 'package:five/core/board.dart';
import 'package:five/core/rules.dart';

/// 对局进行到的阶段。
enum GameStatus {
  /// 对局中。
  playing,

  /// 已分胜负（详见 [GameState.winInfo]）。
  won,

  /// 平局：棋盘下满无人五连。
  draw,
}

/// 一局棋的完整描述：盘面 + 手顺 + 结果。
class GameState {
  /// 当前盘面。
  final Board board;

  /// 落子顺序表。第 0 手是黑方（五子棋黑先）。
  ///
  /// 由奇偶性即可推出每一手的颜色：
  /// 偶数下标（0,2,4…）为黑，奇数下标为白。
  /// 这份历史同时服务于悔棋和将来的复盘回放。
  final List<Point> moves;

  /// 当前阶段。
  final GameStatus status;

  /// 胜利连线信息；未分胜负时为 null。
  final WinInfo? winInfo;

  const GameState({
    required this.board,
    required this.moves,
    required this.status,
    this.winInfo,
  });

  /// 一局新棋：空盘，黑先行。
  factory GameState.initial() => GameState(
        board: Board(),
        moves: const [],
        status: GameStatus.playing,
      );

  /// 该谁落子：总手数为偶数 → 黑方；奇数 → 白方。
  int get currentStone =>
      moves.length.isEven ? Cell.black : Cell.white;

  /// 最近一手的位置；尚未落子时为 null。
  Point? get lastMove => moves.isEmpty ? null : moves.last;
}
