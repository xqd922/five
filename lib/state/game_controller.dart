/// 对局控制器：唯一有权修改 [GameState] 的地方。
///
/// 【Riverpod 心智模型】
/// - `Notifier` = 一个装着状态、暴露修改方法的盒子；
/// - UI 通过 `ref.watch` 盒子里的状态，状态一变界面自动重建；
/// - 所有修改必须走这里的方法，UI 组件自己绝不直接改棋盘——
///   这条纪律让「人类点击落子」与「AI 计算落子」走完全相同的入口。
///
/// 【AI 调度与失效保护】
/// AI 在后台 Isolate 思考期间，用户可能重开或悔棋。
/// 用「代数计数器」解决竞态：每次局面重置代数 +1，
/// AI 结果回来时代数对不上就丢弃——绝不让过期的棋落到新局面上。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:five/core/board.dart';
import 'package:five/core/rules.dart';

import 'package:five/engine/ai_service.dart';
import 'package:five/state/game_state.dart';

/// 全局唯一的对局状态提供者。
final gameControllerProvider =
    NotifierProvider<GameController, GameState>(GameController.new);

class GameController extends Notifier<GameState> {
  @override
  GameState build() => GameState.initial();

  /// AI 任务的失效代数：任何局面重置都会使其增长，
  /// 后台返回的旧结果因此自然作废。
  int _aiGeneration = 0;

  /// 按指定配置开一局新棋（首页选完模式/难度后调用）。
  void startNewGame({
    GameMode mode = GameMode.localTwoPlayer,
    AiLevel? aiLevel,
  }) {
    _aiGeneration++; // 作废一切在途的 AI 计算。
    state = GameState(
      board: Board(),
      moves: const [],
      status: GameStatus.playing,
      mode: mode,
      aiLevel: aiLevel,
      // 人机模式固定 AI 执白（人类执黑先行）——M2 的简化约定。
      aiStone: mode == GameMode.vsAi ? Cell.white : null,
    );
    _scheduleAiIfNeeded();
  }

  /// 尝试在 (x, y) 落子。人机模式下 AI 回合会拒绝人类输入。
  void placeAt(int x, int y) {
    final current = state;
    if (current.status != GameStatus.playing) return;
    if (current.aiThinking) return; // AI 思考中不接受落子
    if (current.isAiTurn) return; // 双保险：轮到 AI 时人不许下
    if (!Rules.isLegalMove(current.board, x, y)) return;

    _commitMove(current, x, y);
    _scheduleAiIfNeeded();
  }

  /// 统一的落子提交：复制盘面 → 更新 → 判定胜负 → 发布新状态。
  void _commitMove(GameState current, int x, int y) {
    final newBoard = current.board.copy();
    newBoard.place(x, y, current.currentStone);

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
      mode: current.mode,
      aiLevel: current.aiLevel,
      aiStone: current.aiStone,
      aiThinking: current.aiThinking,
    );
  }

  /// 若当前该 AI 行棋，发起一次后台计算；结果回来后自动落子。
  void _scheduleAiIfNeeded() {
    final current = state;
    if (!current.isAiTurn) return;

    final generationAtLaunch = _aiGeneration;

    // 先把 thinking 标志发布出去，UI 立刻显示"思考中"。
    state = _copyWithThinking(state, true);

    _runAiTurn(current, generationAtLaunch);
  }

  /// 执行一次完整的 AI 回合：后台计算 → 校验 → 落子。
  ///
  /// [snapshot] 是发起时刻的状态快照（盘面不会再被主线程改动，
  /// 因为 thinking 期间输入已被冻结）；[generation] 用于竞态校验。
  Future<void> _runAiTurn(GameState snapshot, int generation) async {
    try {
      final move = await AiService.findBestMove(
        snapshot.board,
        snapshot.currentStone,
        snapshot.aiLevel ?? AiLevel.medium,
      );

      // 竞态防护：等待期间发生过重开/悔棋 → 这份结果已过期。
      if (generation != _aiGeneration || !ref.mounted) return;

      final latest = state;
      if (!latest.isAiTurn) {
        // 局面已终局等原因不再需要 AI 走子，只解除思考标志。
        state = _copyWithThinking(latest, false);
        return;
      }

      _commitMove(latest, move.x, move.y);
      state = _copyWithThinking(state, false);
      _scheduleAiIfNeeded(); // 理论上已轮到人类；防御性兜底。
    } catch (error) {
      // Isolate 崩溃也绝不能把界面留在“永久思考中”。
      if (generation == _aiGeneration && ref.mounted) {
        state = _copyWithThinking(state, false);
      }
    }
  }

  /// 悔棋：
  /// - 双人模式撤一手；
  /// - 人机模式撤两手（撤销 AI 应手 + 自己上一手），回到你的决策点；
  ///   若 AI 正在思考则同时取消这次计算。
  void undo() {
    if (state.moves.isEmpty) return;

    _aiGeneration++; // 在途的 AI 结果作废。

    var count = state.mode == GameMode.vsAi ? 2 : 1;
    // 人机模式下若最后一手是人类自己下的（AI 还没回），只撤一手。
    if (state.mode == GameMode.vsAi && state.currentStone == Cell.white) {
      count = 1;
    }
    count = count > state.moves.length ? state.moves.length : count;

    final remaining =
        state.moves.sublist(0, state.moves.length - count);
    state = _replayFromMoves(remaining,
        base: state); // 保留模式配置，清掉终局/思考标志。
  }

  /// 清盘开新局（保留当前模式与难度）。
  void restart() => startNewGame(
        mode: state.mode,
        aiLevel: state.aiLevel,
      );

  /// 从手顺表重建整局状态（悔棋的核心实现）。
  ///
  /// 「重放」比「反向删除」可靠：最终盘面由代码从零推导，
  /// 永远不会与手顺记录不一致。
  GameState _replayFromMoves(List<Point> moves, {required GameState base}) {
    final board = Board();
    for (var i = 0; i < moves.length; i++) {
      board.place(moves[i].x, moves[i].y,
          i.isEven ? Cell.black : Cell.white);
    }
    return GameState(
      board: board,
      moves: moves,
      status: GameStatus.playing,
      mode: base.mode,
      aiLevel: base.aiLevel,
      aiStone: base.aiStone,
      aiThinking: false,
    );
  }

  /// 复制状态但更新 aiThinking（其余字段原样保留）。
  GameState _copyWithThinking(GameState s, bool thinking) => GameState(
        board: s.board,
        moves: s.moves,
        status: s.status,
        winInfo: s.winInfo,
        mode: s.mode,
        aiLevel: s.aiLevel,
        aiStone: s.aiStone,
        aiThinking: thinking,
      );
}
