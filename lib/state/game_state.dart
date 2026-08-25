/// 对局的不可变状态快照。
///
/// 【为什么强调不可变】Riverpod 靠「引用是否变化」判断要不要通知 UI 重绘。
/// 如果 Board 被原地修改而 GameState 还是同一个对象，
/// Riverpod 会认为"什么都没发生"，界面就不会更新。
/// 因此每手棋都通过 board.copy() 造出新棋盘、新状态——
/// 整盘才 225 字节，这个拷贝的成本可以忽略不计。
library;

import 'package:five_core/five_core.dart';

import 'package:five/engine/ai_service.dart';

/// 对局模式。M2 起支持人机；在线联机将来作为第三种加入，
/// GameSession 抽象会保证三种模式共用同一套状态机。
enum GameMode {
  /// 本地双人：同屏轮流执子。
  localTwoPlayer,

  /// 人机对战：人类执黑先行，AI 执白。
  vsAi,
}

/// 对局进行到的阶段。
enum GameStatus {
  /// 对局中。
  playing,

  /// 已分胜负（详见 [GameState.winInfo]）。
  won,

  /// 平局：棋盘下满无人五连。
  draw,
}

/// 一局棋的完整描述：盘面 + 手顺 + 结果 + 模式配置。
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

  /// 对局模式（决定悔棋语义与是否触发 AI）。
  final GameMode mode;

  /// AI 难度；仅 [GameMode.vsAi] 模式有意义。
  final AiLevel? aiLevel;

  /// AI 执子颜色；双人模式为 null。
  final int? aiStone;

  /// AI 是否正在后台思考（UI 据此显示指示器、冻结输入）。
  final bool aiThinking;

  /// AI 提示的推荐落点；未请求或已过期时为 null。
  final Point? hint;

  /// 提示是否正在计算中（与 aiThinking 分开，互不干扰显示）。
  final bool hintLoading;

  /// 复盘回放正在查看的手数（0..moves.length）；
  /// null 表示不在回放模式、跟随最新局面。
  final int? replayIndex;

  const GameState({
    required this.board,
    required this.moves,
    required this.status,
    this.winInfo,
    this.mode = GameMode.localTwoPlayer,
    this.aiLevel,
    this.aiStone,
    this.aiThinking = false,
    this.hint,
    this.hintLoading = false,
    this.replayIndex,
  });

  /// 一局新棋：空盘，黑先行（默认双人模式）。
  /// 注意不能用 const：Board 的构造器会分配字节数组，不是常量。
  factory GameState.initial() => GameState(
        board: Board(),
        moves: const [],
        status: GameStatus.playing,
      );

  /// 该谁落子：总手数为偶数 → 黑方；奇数 → 白方。
  int get currentStone => moves.length.isEven ? Cell.black : Cell.white;

  /// 最近一手的位置；尚未落子时为 null。
  Point? get lastMove => moves.isEmpty ? null : moves.last;

  /// 通用字段复制。传 null 的字段保持原值；
  /// 需要显式清空的引用字段（hint/replayIndex）传哨兵值后由调用方处理。
  GameState copyWith({
    Board? board,
    List<Point>? moves,
    GameStatus? status,
    WinInfo? winInfo,
    GameMode? mode,
    AiLevel? aiLevel,
    int? aiStone,
    bool? aiThinking,
    Point? hint,
    bool? hintLoading,
    int? replayIndex,
  }) {
    return GameState(
      board: board ?? this.board,
      moves: moves ?? this.moves,
      status: status ?? this.status,
      winInfo: winInfo ?? this.winInfo,
      mode: mode ?? this.mode,
      aiLevel: aiLevel ?? this.aiLevel,
      aiStone: aiStone ?? this.aiStone,
      aiThinking: aiThinking ?? this.aiThinking,
      // 引用类型字段无法用 ?? 区分「未传」与「显式置空」，
      // 这里约定：置空场景统一走 clearHint/clearReplay 等专用构造。
      hint: hint ?? this.hint,
      hintLoading: hintLoading ?? this.hintLoading,
      replayIndex: replayIndex ?? this.replayIndex,
    );
  }

  /// 更新 AI 提示（[newHint] 传 null 即清除）。
  ///
  /// 不并入 copyWith 的原因：null 语义有歧义——「没传」和「要清空」
  /// 在 ?? 表达式里无法区分，专设方法让意图一目了然。
  GameState withHint(Point? newHint, {bool loading = false}) {
    return GameState(
      board: board,
      moves: moves,
      status: status,
      winInfo: winInfo,
      mode: mode,
      aiLevel: aiLevel,
      aiStone: aiStone,
      aiThinking: aiThinking,
      hint: newHint,
      hintLoading: loading,
      replayIndex: replayIndex,
    );
  }

  /// 进入/退出复盘回放视图；[index] 传 null 表示退出回放、跟随最新。
  GameState withReplay(int? index) {
    return GameState(
      board: board,
      moves: moves,
      status: status,
      winInfo: winInfo,
      mode: mode,
      aiLevel: aiLevel,
      aiStone: aiStone,
      aiThinking: aiThinking,
      hint: hint,
      hintLoading: hintLoading,
      replayIndex: index,
    );
  }

  /// 当前是否轮到 AI 行棋。
  bool get isAiTurn =>
      mode == GameMode.vsAi &&
      aiStone == currentStone &&
      status == GameStatus.playing;

  /// 推导「下完第 [moveCount] 手时」的盘面（复盘回放的核心）。
  ///
  /// 从空盘按手顺重放——一局最多 225 手、每手一次字节写入，
  /// 微秒级完成，无需为它做任何缓存优化。
  Board boardAt(int moveCount) {
    final board = Board();
    for (var i = 0; i < moveCount && i < moves.length; i++) {
      board.place(moves[i].x, moves[i].y,
          i.isEven ? Cell.black : Cell.white);
    }
    return board;
  }

  /// UI 实际应绘制的盘面：回放中显示历史盘面，否则显示最新盘面。
  Board get displayBoard =>
      replayIndex == null ? board : boardAt(replayIndex!);

  /// UI 实际应高亮的「最近一手」：回放中是所查看的那一手。
  Point? get displayLastMove => replayIndex == null
      ? lastMove
      : (replayIndex! == 0 ? null : moves[replayIndex! - 1]);
}
