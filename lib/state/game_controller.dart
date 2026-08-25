/// 对局控制器：唯一有权修改 [GameState] 的地方。
///
/// 【Riverpod 心智模型】
/// - `Notifier` = 一个装着状态、暴露修改方法的盒子；
/// - UI 通过 `ref.watch` 盒子里的状态，状态一变界面自动重建；
/// - 所有修改必须走这里的方法，UI 组件自己绝不直接改棋盘——
///   这条纪律让「人类点击落子」「AI 计算落子」「AI 提示计算」
///   走同一套入口与校验。
///
/// 【异步任务与失效保护】
/// AI 思考与 AI 提示都是后台 Isolate 任务，等待期间用户可能重开/悔棋。
/// 两者共用「代数计数器」防竞态：任何局面重置使代数 +1，
/// 过期结果回来后自然被丢弃，绝不让旧棋落到新局面上。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:five_core/five_core.dart';

import 'package:five/engine/ai_service.dart';
import 'package:five/state/game_state.dart';
import 'package:five/state/stats_provider.dart';

/// 全局唯一的对局状态提供者。
final gameControllerProvider =
    NotifierProvider<GameController, GameState>(GameController.new);

class GameController extends Notifier<GameState> {
  @override
  GameState build() => GameState.initial();

  /// 异步任务的失效代数：任何局面重置都会使其增长。
  int _aiGeneration = 0;

  /// 当前这局是否已计入战绩（防止「终局→悔棋→再终局」重复计数）。
  bool _resultCounted = false;

  /// 按指定配置开一局新棋（首页选完模式/难度后调用）。
  void startNewGame({
    GameMode mode = GameMode.localTwoPlayer,
    AiLevel? aiLevel,
  }) {
    _aiGeneration++; // 作废一切在途的 AI 计算。
    _resultCounted = false; // 新的一局，战绩重新可计。
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
    if (current.aiThinking || current.hintLoading) return;
    if (current.isAiTurn) return; // 双保险：轮到 AI 时人不许下
    if (!Rules.isLegalMove(current.board, x, y)) return;

    _commitMove(current, x, y);
    _scheduleAiIfNeeded();
  }

  /// 统一的落子提交：复制盘面 → 更新 → 判定胜负 → 发布新状态。
  ///
  /// 落子必然使旧的 AI 提示失效、并退出回放视图——在这一个出口
  /// 统一处理，所有触发路径（点击/AI 回来）都不会遗漏。
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
      // hint 清空、replayIndex 清空：见方法注释。
    );

    _recordResultIfNeeded(newStatus);
  }

  /// 终局时把人机模式的结果计入战绩（每局只计一次）。
  void _recordResultIfNeeded(GameStatus status) {
    if (_resultCounted || status == GameStatus.playing) return;
    if (state.mode != GameMode.vsAi) return;
    _resultCounted = true;
    // 人执黑、AI 执白：黑胜=人胜，白胜=AI 胜。
    ref.read(statsProvider.notifier).record(
          humanWon: status == GameStatus.draw
              ? null
              : state.winInfo!.winner == Cell.black,
        );
  }

  // ------------------------------------------------------------------
  // AI 对战回合
  // ------------------------------------------------------------------

  /// 若当前该 AI 行棋，发起一次后台计算；结果回来后自动落子。
  void _scheduleAiIfNeeded() {
    final current = state;
    if (!current.isAiTurn) return;

    final generationAtLaunch = _aiGeneration;
    state = state.copyWith(aiThinking: true); // UI 立刻显示"思考中"
    _runAiTurn(current, generationAtLaunch);
  }

  Future<void> _runAiTurn(GameState snapshot, int generation) async {
    try {
      final move = await AiService.findBestMove(
        snapshot.board,
        snapshot.currentStone,
        snapshot.aiLevel ?? AiLevel.medium,
      );

      if (generation != _aiGeneration || !ref.mounted) return;

      final latest = state;
      if (!latest.isAiTurn) {
        state = latest.copyWith(aiThinking: false);
        return;
      }

      _commitMove(latest, move.x, move.y);
      state = state.copyWith(aiThinking: false);
      _scheduleAiIfNeeded(); // 防御性兜底：理论上已轮到人类。
    } catch (error) {
      // Isolate 崩溃也绝不能把界面留在"永久思考中"。
      if (generation == _aiGeneration && ref.mounted) {
        state = state.copyWith(aiThinking: false);
      }
    }
  }

  // ------------------------------------------------------------------
  // AI 提示（人机模式下为当前行棋的人类推荐一手）
  // ------------------------------------------------------------------

  /// 请求 AI 提示。仅在对局进行中、轮到人类时有效。
  ///
  /// 用「进阶」档的搜索参数——提示的价值在于可靠，
  /// 与对局难度设置无关（入门局也值得得到好建议）。
  void requestHint() {
    final current = state;
    if (current.status != GameStatus.playing ||
        current.hintLoading ||
        current.isAiTurn) {
      return;
    }

    final generationAtLaunch = _aiGeneration;
    final humanStone = current.currentStone;
    state = current.withHint(null, loading: true);

    () async {
      try {
        final move =
            await AiService.findBestMove(current.board, humanStone, AiLevel.medium);
        if (generationAtLaunch != _aiGeneration || !ref.mounted) return;
        // 局面可能已变（用户自己落了子），只有仍轮到原颜色才展示。
        if (state.status == GameStatus.playing &&
            state.currentStone == humanStone) {
          state = state.withHint(move, loading: false);
        } else {
          state = state.withHint(null, loading: false);
        }
      } catch (error) {
        if (generationAtLaunch == _aiGeneration && ref.mounted) {
          state = state.withHint(null, loading: false);
        }
      }
    }();
  }

  // ------------------------------------------------------------------
  // 复盘回放（终局后逐步查看）
  // ------------------------------------------------------------------

  /// 把回放视图定位到第 [index] 手之后的状态（0 = 开局空盘）。
  void replayTo(int index) {
    final current = state;
    if (index < 0 || index > current.moves.length) return;
    state = current.withReplay(index);
  }

  /// 退出回放，回到最新局面。
  void replayExit() => state = state.withReplay(null);

  // ------------------------------------------------------------------
  // 悔棋与重开
  // ------------------------------------------------------------------

  /// 悔棋：
  /// - 双人模式撤一手；
  /// - 人机模式撤两手（撤销 AI 应手 + 自己上一手），回到你的决策点；
  ///   若最后一手是你自己的（AI 未回）只撤一手。
  void undo() {
    if (state.moves.isEmpty) return;

    _aiGeneration++; // 在途的 AI 结果作废。

    var count = state.mode == GameMode.vsAi ? 2 : 1;
    if (state.mode == GameMode.vsAi && state.currentStone == Cell.white) {
      count = 1;
    }
    count = count > state.moves.length ? state.moves.length : count;

    final remaining = state.moves.sublist(0, state.moves.length - count);
    final board = Board();
    for (var i = 0; i < remaining.length; i++) {
      board.place(remaining[i].x, remaining[i].y,
          i.isEven ? Cell.black : Cell.white);
    }

    state = GameState(
      board: board,
      moves: remaining,
      status: GameStatus.playing, // 允许从终局悔棋回到对局中（休闲玩法）
      mode: state.mode,
      aiLevel: state.aiLevel,
      aiStone: state.aiStone,
      // hint / replayIndex 归零：局面变了，旧提示与回放位置全部失效。
    );
    _scheduleAiIfNeeded(); // 人机模式下撤两手后仍轮到人类，此调用是空操作。
  }

  /// 清盘开新局（保留当前模式与难度）。
  void restart() => startNewGame(mode: state.mode, aiLevel: state.aiLevel);
}
