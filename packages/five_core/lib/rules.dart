/// 五子棋规则引擎：落子合法性与胜负判定。
///
/// 当前采用【无禁手自由规则】：任意一方先连成五子（或以上）即胜。
/// 这是最普及的大众玩法；若未来要支持「黑棋禁手」的连珠竞技规则，
/// 只需扩展本文件的合法性检查，上层代码无需改动。
library;

import 'board.dart';

/// 棋盘上的一个交叉点坐标。
///
/// 用不可变类（所有字段 final）而非可变对象，
/// 避免 UI 动画、AI 搜索中坐标被意外改坏的问题。
class Point {
  /// 列号（0 起，从左往右）。
  final int x;

  /// 行号（0 起，从上往下）。
  final int y;

  const Point(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      other is Point && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '($x,$y)';
}

/// 胜利信息：赢家 + 构成五连的整条连线坐标。
///
/// 连线坐标交给 UI 层画高亮描线动画使用，
/// 引擎本身不关心任何视觉表现。
class WinInfo {
  /// 获胜方棋子颜色（[Cell.black] 或 [Cell.white]）。
  final int winner;

  /// 从连线一端到另一端的全部坐标（按顺序排列）。
  ///
  /// 注意长度可能超过 5——无禁手规则下六连、七连同样获胜，
  /// 我们把实际连成的整条线都返回出去，UI 才能完整高亮。
  final List<Point> line;

  const WinInfo({required this.winner, required this.line});
}

/// 四个需要检查的方向：(dx, dy) 表示沿该方向每步的坐标增量。
///
/// 横向 →(1,0)、纵向 ↓(0,1)、斜向 ↘(1,1)、斜向 ↗(1,-1)。
/// 「反方向」不用单独列出：从落点向正负两个方向各延伸一次即可覆盖。
const List<(int, int)> _directions = [(1, 0), (0, 1), (1, 1), (1, -1)];

/// 规则相关的纯函数集合。
///
/// 全部是静态方法：规则没有状态，不需要实例化。
abstract final class Rules {
  /// 这一手棋是否合法（无禁手规则下 = 在界内且落在空位上）。
  static bool isLegalMove(Board board, int x, int y) => board.isEmpty(x, y);

  /// 刚刚在 (x, y) 落下的这枚子是否构成胜利。
  ///
  /// 算法：以 (x, y) 为中心，对 4 个方向分别向正反两端延伸，
  /// 统计连续同色棋子的数量并沿途收集坐标。
  /// 任一方向凑满 5 子立即返回胜利——无需继续扫描其余方向。
  ///
  /// 时间复杂度 O(1)：最坏也只检查落点周围 4×8 个格子，
  /// 与全盘 225 格无关。这是落子即时判定的关键。
  static WinInfo? checkWin(Board board, int x, int y) {
    final stone = board.get(x, y);
    assert(stone != Cell.empty, 'checkWin 只能在有子的位置调用');

    for (final (dx, dy) in _directions) {
      // 收集该方向的完整连线：先反向延伸到线头，再统一向正向走到底。
      final line = <Point>[Point(x, y)];

      // 向「负方向」延伸（如横向的左端），把遇到的同色子插到队头。
      var cx = x - dx, cy = y - dy;
      while (Board.inBounds(cx, cy) && board.get(cx, cy) == stone) {
        line.insert(0, Point(cx, cy));
        cx -= dx;
        cy -= dy;
      }

      // 向「正方向」延伸（如横向的右端），追加到队尾。
      cx = x + dx;
      cy = y + dy;
      while (Board.inBounds(cx, cy) && board.get(cx, cy) == stone) {
        line.add(Point(cx, cy));
        cx += dx;
        cy += dy;
      }

      if (line.length >= 5) {
        return WinInfo(winner: stone, line: line);
      }
    }
    return null; // 四个方向都不足五连，未分胜负。
  }

  /// 棋盘是否已满且无人获胜 → 平局。
  static bool isDraw(Board board, {WinInfo? win}) =>
      win == null && board.isFull;
}
