/// 局面评估器：给任意盘面打出一个整数分。
///
/// 正分表示 [stone] 方占优，负分表示对方占优，零为均势。
/// 这是 AI 引擎第 1 层（棋感）；第 3 层的 Alpha-Beta 搜索
/// 将在叶子节点反复调用它，因此性能与正确性同样重要。
///
/// 【算法】线扫描：
/// 1. 把全盘归纳为 72 条直线（15 横 + 15 竖 + 21×2 斜）；
/// 2. 每条线按当前视角编码成字符串（X=己方 / O=敌方·边界 / _=空），
///    并在两端各补一个 O——边界与敌子从此等价，模式表只需一套；
/// 3. 按棋型优先级跑预编译正则，累加分值。
///
/// 【已知取舍】模式表互斥性良好（活四不会被误计成活三），
/// 但眠三只收录了常见八种形态，长尾形态会漏检——
/// 漏检的是 5000 分量级的弱威胁，搜索深度会部分补偿，
/// 留待 M2 调参阶段用对弈胜率验证后再决定是否细化。
library;

import 'package:five/core/board.dart';
import 'package:five/core/rules.dart' show Point;

import 'package:five/engine/patterns.dart';

class Evaluator {
  /// —— 预编译模式表（按优先级从高到低，命中即停该层级）——
  ///
  /// 所有模式基于「两端补墙」后的编码串。
  static final RegExp _five = RegExp(r'XXXXX');
  static final RegExp _openFour = RegExp(r'_XXXX_');

  /// 冲四：直四被堵一头（XXXX 出现但不构成活四/五连），
  /// 或跳跃四 X_XXX / XX_XX / XXX_X（唯一成五点是那一个空）。
  static final RegExp _jumpFour = RegExp(r'X_XXX|XX_XX|XXX_X');

  /// 活三：连三且一侧至少两连空（__XXX_ / _XXX__），
  /// 以及跳活三 _X_XX_ / _XX_X_（中间空位落子即成活四）。
  static final RegExp _openThree = RegExp(r'__XXX_|_XXX__|_X_XX_|_XX_X_');

  /// 眠三常见九种：一头被墙堵死的连三/跳三，以及两头贴墙的死三。
  static final RegExp _sleepThree =
      RegExp(r'OXXX__|__XXXO|O_XXX_|_XXX_O|OX_XX|XX_XO|OXX_X|X_XXO|OXXX_O');

  /// 72 条线的坐标序列（几何结构恒定，进程内构建一次复用终身）。
  static final List<List<Point>> _lines = _buildLines();

  /// 评估 [board]，返回 [stone] 视角的分数 = 己方总分 − 对方总分。
  static int evaluate(Board board, int stone) {
    return scoreFor(board, stone) - scoreFor(board, opposite(stone));
  }

  /// [stone] 是否已成五连（终局检测，供搜索快速剪枝）。
  static bool hasFive(Board board, int stone) {
    for (final line in _lines) {
      if (_encode(line, board, stone).contains(_five)) return true;
    }
    return false;
  }

  /// 单方总分：扫描全部线，逐级匹配棋型累加。
  static int scoreFor(Board board, int stone) {
    var total = 0;
    for (final line in _lines) {
      final encoded = _encode(line, board, stone);

      // 五连：出现即封顶级分数，这条线不再可能有更高价值。
      if (encoded.contains(_five)) {
        total += patternScores[Pattern.five]!;
        continue;
      }
      if (encoded.contains(_openFour)) {
        total += patternScores[Pattern.openFour]!;
      }
      // 直四冲四：排除活四后出现的裸 XXXX 必然一头被墙。
      // （编码串里 XXXX 前后只要没有双空包围，就只剩冲四一种解释）
      if (encoded.contains('XXXX')) {
        total += patternScores[Pattern.four]!;
      }
      if (encoded.contains(_jumpFour)) {
        total += patternScores[Pattern.four]!;
      }
      if (encoded.contains(_openThree)) {
        total += patternScores[Pattern.openThree]!;
      }
      if (encoded.contains(_sleepThree)) {
        total += patternScores[Pattern.sleepThree]!;
      }
    }
    return total;
  }

  /// 把一条线上的格子按 [stone] 视角编码，并在首尾各补一面墙。
  static String _encode(List<Point> line, Board board, int stone) {
    final buffer = StringBuffer(PatternChars.blocked);
    for (final point in line) {
      buffer.write(encodeCell(board.get(point.x, point.y), stone));
    }
    buffer.write(PatternChars.blocked);
    return buffer.toString();
  }

  /// 构建 72 条线的几何坐标。
  ///
  /// 对角线只收长度 ≥5 的（更短的连不出任何棋型），
  /// 由常数 c = x−y（或 x+y）唯一确定每条 ↘ / ↗ 斜线。
  static List<List<Point>> _buildLines() {
    final lines = <List<Point>>[];
    final n = Board.size;

    // 15 条横线、15 条纵线。
    for (var i = 0; i < n; i++) {
      lines.add([for (var x = 0; x < n; x++) Point(x, i)]);
      lines.add([for (var y = 0; y < n; y++) Point(i, y)]);
    }

    // ↘ 方向（dx=1, dy=1）：c = x − y ∈ [−10, 10] 时长度 ≥5。
    for (var c = -n + 5; c <= n - 5; c++) {
      final line = <Point>[];
      for (var y = 0; y < n; y++) {
        final x = y + c;
        if (x >= 0 && x < n) line.add(Point(x, y));
      }
      lines.add(line);
    }

    // ↗ 方向（dx=1, dy=−1）：s = x + y，长度 ≥5 ⇔ |s − (n−1)| ≤ n−5，
    // 即 s ∈ [4, 24]，共 21 条（与 ↘ 方向完全对称）。
    final center = n - 1;
    for (var s = center - (n - 5); s <= center + (n - 5); s++) {
      final line = <Point>[];
      for (var y = 0; y < n; y++) {
        final x = s - y;
        if (x >= 0 && x < n) line.add(Point(x, y));
      }
      lines.add(line);
    }

    assert(lines.length == 72, '应有 72 条线，实际 ${lines.length}');
    return lines;
  }

  /// 对手颜色。
  static int opposite(int stone) =>
      stone == Cell.black ? Cell.white : Cell.black;
}
