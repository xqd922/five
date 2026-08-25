/// 候选着法生成 —— AI 引擎第 2 层。
///
/// 【为什么要裁剪】15×15 有 225 个交叉点，但与战局相关的
/// 只有已有棋子附近的空位：距离所有棋子都超过 2 格的点，
/// 既构不成任何威胁也挡不住任何威胁，搜它们纯属浪费。
/// 实测中盘阶段这一刀能把候选从 ~180 个压到 ~30 个。
library;

import 'package:five/core/board.dart';
import 'package:five/core/rules.dart';

class CandidateGenerator {
  /// 与最近棋子的最大切比雪夫距离（棋盘格数）。
  static const int defaultRadius = 2;

  /// 生成当前局面下值得考虑的所有落点。
  ///
  /// 空盘时返回天元 (7,7)——五子棋第一手的最优位置没有争议。
  static List<Point> generate(Board board, {int radius = defaultRadius}) {
    if (board.stoneCount == 0) return const [Point(7, 7)];

    final candidates = <Point>[];
    for (var y = 0; y < Board.size; y++) {
      for (var x = 0; x < Board.size; x++) {
        if (!board.isEmpty(x, y)) continue;
        if (_hasStoneNearby(board, x, y, radius)) {
          candidates.add(Point(x, y));
        }
      }
    }
    return candidates;
  }

  /// (x, y) 的切比雪夫距离 [radius] 内是否存在任意棋子。
  static bool _hasStoneNearby(Board board, int x, int y, int radius) {
    for (var dy = -radius; dy <= radius; dy++) {
      for (var dx = -radius; dx <= radius; dx++) {
        if (dx == 0 && dy == 0) continue;
        final nx = x + dx, ny = y + dy;
        if (Board.inBounds(nx, ny) && !board.isEmpty(nx, ny)) return true;
      }
    }
    return false;
  }

  /// 给单个候选点做「粗略吸引力」打分，用于搜索前的着法排序。
  ///
  /// 直觉：周围双方棋子越密集，这个点的攻防价值越高。
  /// 这只是廉价的排序启发（让 Alpha-Beta 更早剪枝），
  /// 不追求精确——精确的判断交给真正的搜索去验证。
  static int orderScore(Board board, Point p) {
    var score = 0;
    for (var dy = -2; dy <= 2; dy++) {
      for (var dx = -2; dx <= 2; dx++) {
        final nx = p.x + dx, ny = p.y + dy;
        if (!Board.inBounds(nx, ny)) continue;
        final cell = board.get(nx, ny);
        if (cell == Cell.empty) continue;
        // 半径 1 内的邻居权重更高（贴身攻防）。
        score += (dx.abs() <= 1 && dy.abs() <= 1) ? 3 : 1;
      }
    }
    return score;
  }
}
