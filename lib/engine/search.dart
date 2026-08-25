/// 搜索引擎 —— AI 引擎第 3 层。
///
/// 【Negamax 视角】Alpha-Beta 的对称简写：
/// 「我方分数 = −(对手在子节点的分数)」，一行完成极小极大翻转。
/// 配合三件套把有效搜索深度推到实用水平：
/// 1. 候选裁剪（candidates.dart）——少搜无关点；
/// 2. 着法排序（orderScore）——好着先搜，剪枝更早触发；
/// 3. 迭代加深（iterative deepening）——从浅到深逐层搜索，
///    超时就停，永远有「当前能给出的最好答案」在手。
///
/// 【尚未包含、留给调参阶段】Zobrist 置换表、必胜/必杀快速通道。
library;

import 'package:five/core/board.dart';
import 'package:five/core/rules.dart';

import 'package:five/engine/candidates.dart';
import 'package:five/engine/evaluator.dart';
import 'package:five/engine/patterns.dart';

/// 搜索结论：推荐着法 + 该着法的局面评分。
class SearchResult {
  final Point move;
  final int score;

  /// 实际完成的搜索深度（迭代加深可能因超时而未达上限）。
  final int depth;

  const SearchResult({
    required this.move,
    required this.score,
    required this.depth,
  });
}

/// 内部超时信号：沿调用栈一路抛回根节点。
class _SearchTimeout implements Exception {}

class SearchEngine {
  /// 「负无穷」哨兵：比任何真实评估都小，又远不会在加减中溢出 64 位。
  static const int _inf = 1 << 60;

  /// 胜利基准分（与 patternScores[Pattern.five] 保持一致；
  /// Map 下标不是编译期常量，这里只能写字面量）。
  /// 减去剩余深度使「更快获胜」的线路得分更高，
  /// 避免 AI 在两条都能赢的路里故意绕远路。
  static const int _winScore = 10000000;

  /// 每探查多少节点检查一次时钟（频繁查时钟本身也有开销）。
  static const int _timeCheckInterval = 2048;

  int _nodes = 0;
  DateTime? _deadline;
  Board? _board;

  /// 为 [stone] 寻找最佳着法。
  ///
  /// [maxDepth] 控制算力上限（难度分级的主要旋钮），
  /// [timeBudget] 是硬时限——超时立即返回已找到的最好结果。
  SearchResult findBestMove(
    Board board,
    int stone, {
    int maxDepth = 4,
    Duration timeBudget = const Duration(seconds: 3),
  }) {
    _board = board;
    _nodes = 0;
    _deadline = DateTime.now().add(timeBudget);

    var candidates = CandidateGenerator.generate(board);
    if (candidates.isEmpty) {
      // 理论上只在满盘时发生；防御性返回任意点。
      return SearchResult(move: const Point(7, 7), score: 0, depth: 0);
    }

    // 迭代加深主循环：上一层的结果作为下一层的排序依据。
    var bestResult = SearchResult(
      move: candidates.first,
      score: Evaluator.evaluate(board, stone),
      depth: 0,
    );

    for (var depth = 1; depth <= maxDepth; depth++) {
      try {
        bestResult = _searchRoot(board, stone, candidates, depth);
      } on _SearchTimeout {
        break; // 超时：保留上一层的完整结果。
      }
      // 已找到必胜路线或必败中唯一挣扎，无需更深。
      if (bestResult.score.abs() >= _winScore - maxDepth * 1000) break;
    }
    return bestResult;
  }

  /// 根节点搜索：遍历候选并保留最优者，同时用结果优化下一轮排序。
  SearchResult _searchRoot(
    Board board,
    int stone,
    List<Point> candidates,
    int depth,
  ) {
    var bestScore = -_inf;
    var bestMove = candidates.first;

    // 根层排序：粗排即可显著提高首着命中率。
    final sorted = [...candidates]..sort((a, b) => CandidateGenerator
        .orderScore(board, b)
        .compareTo(CandidateGenerator.orderScore(board, a)));

    for (final move in sorted) {
      board.place(move.x, move.y, stone);

      int score;
      if (Rules.checkWin(board, move.x, move.y) != null) {
        score = _winScore; // 这一手直接赢下。
      } else {
        score = -_negamax(depth - 1, -_inf, -bestScore,
            Evaluator.opposite(stone));
      }

      board.remove(move.x, move.y);

      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }
    return SearchResult(move: bestMove, score: bestScore, depth: depth);
  }

  /// Negamax 核心：返回 [toMove] 视角下当前局面的分数。
  ///
  /// alpha / beta 是「当前已知的最优下界 / 对方的最优上界」，
  /// 一旦 alpha ≥ beta 说明这条线无论再怎么走都不会被选择，直接放弃。
  int _negamax(int depth, int alpha, int beta, int toMove) {
    _nodes++;
    if (_nodes % _timeCheckInterval == 0 &&
        DateTime.now().isAfter(_deadline!)) {
      throw _SearchTimeout();
    }

    if (depth == 0) return Evaluator.evaluate(_board!, toMove);

    final moves = CandidateGenerator.generate(_board!)..sort((a, b) =>
        CandidateGenerator
            .orderScore(_board!, b)
            .compareTo(CandidateGenerator.orderScore(_board!, a)));
    if (moves.isEmpty) return 0; // 满盘平局。

    var best = -_inf;
    for (final move in moves) {
      _board!.place(move.x, move.y, toMove);

      int score;
      if (Rules.checkWin(_board!, move.x, move.y) != null) {
        score = _winScore - depth; // 剩余深度越大 = 赢得越快 → 分越高。
      } else {
        score =
            -_negamax(depth - 1, -beta, -alpha, Evaluator.opposite(toMove));
      }

      _board!.remove(move.x, move.y);

      if (score > best) best = score;
      if (best > alpha) alpha = best;
      if (alpha >= beta) break; // β 剪枝：对方已有更好的选择。
    }
    return best;
  }
}
