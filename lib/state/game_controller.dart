/// 对局控制器：唯一有权修改 [GameState] 的地方。
///
/// 【Riverpod 心智模型】
/// - `Notifier` = 一个装着状态、暴露修改方法的盒子；
/// - UI 通过 `ref.watch` 盒子里的状态，状态一变界面自动重建；
/// - 所有修改必须走这里的方法，UI 组件自己绝不直接改棋盘——
///   这条纪律保证了「任何来源的落子（点击、AI、将来的网络包）」
///   都经过同一套规则校验，这正是将来接 AI / 联机时零重构的关键。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:five/core/board.dart';
import 'package:five/core/rules.dart';
import 'package:five/state/game_state.dart';

/// 全局唯一的对局状态提供者。
///
/// UI 里这样使用：
/// ```dart
/// final game = ref.watch(gameControllerProvider); // 读状态
/// ref.read(gameControllerProvider.notifier).placeAt(x, y); // 调方法
/// ```
final gameControllerProvider =
    NotifierProvider<GameController, GameState>(GameController.new);

class GameController extends Notifier<GameState> {
  @override
  GameState build() => GameState.initial();

  /// 尝试在 (x, y) 落子。
  ///
  /// 所有可能不合法的情况都在这里拦截：对局已结束、坐标越界、
  /// 该点已有子。校验通过后依次更新盘面 → 记录手顺 → 判定胜负。
  void placeAt(int x, int y) {
    final current = state;
    if (current.status != GameStatus.playing) return;
    if (!Rules.isLegalMove(current.board, x, y)) return;

    // 复制出新盘面再落子，保证旧状态对象不被污染（见 game_state.dart 注释）。
    final newBoard = current.board.copy();
    newBoard.place(x, y, current.currentStone);

    // 判定新阶段：先看是否五连获胜，再看棋盘是否下满成平局。
    final win = Rules.checkWin(newBoard, x, y);
    final GameStatus newStatus;
    if (win != null) {
      newStatus = GameStatus.won;
    } else if (newBoard.isFull) {
      newStatus = GameStatus.draw;
    } else {
      newStatus = GameStatus.playing;
    }

    state = GameState(
      board: newBoard,
      moves: [...current.moves, Point(x, y)],
      status: newStatus,
      winInfo: win,
    );
  }

  /// 悔棋一步（M1 双人模式语义：撤销最后一手）。
  ///
  /// 实现方式是「重放」而不是反向删除：
  /// 从空盘重新摆一遍剩余的手顺。理由：
  /// - 重放的最终盘面由代码推导而来，绝不会与手顺记录不一致；
  /// - 将来人机模式要"撤两手"，只需在这里多弹出一手，逻辑不变。
  /// 一局最多 225 手，重放开销微秒级，完全不必优化。
  void undo() {
    if (state.moves.isEmpty) return;

    final remaining = state.moves.sublist(0, state.moves.length - 1);
    final board = Board();
    for (var i = 0; i < remaining.length; i++) {
      final move = remaining[i];
      board.place(move.x, move.y,
          i.isEven ? Cell.black : Cell.white); // 奇偶推颜色，见 GameState.moves
    }

    state = GameState(
      board: board,
      moves: remaining,
      status: GameStatus.playing, // 允许从终局悔棋回到对局中（休闲玩法）
    );
  }

  /// 清盘开新局。
  void restart() => state = GameState.initial();
}
