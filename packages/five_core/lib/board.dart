/// 棋盘数据结构。
///
/// 这是整个项目最底层的一块砖：只负责「记录哪里有什么子」，
/// 不含任何游戏规则逻辑（那是 [rules.dart] 的职责）。
/// 保持纯粹的好处：AI 引擎、UI、未来的联机模块都依赖同一份可靠的数据。
library;

import 'dart:typed_data';

/// 棋盘格子的三种状态，用整数常量表示。
///
/// 【为什么不用 enum】后续竞技级 AI 引擎每秒要评估成千上万个局面，
/// 整数比较比枚举更快、拷贝棋盘时也更省内存——这是棋类引擎的通行做法。
/// 用带名字的常量类封装，兼顾性能与可读性。
///
/// `abstract final` 表示：这个类不能被继承也不能被实例化，
/// 它只是三个常量的「容器」，防止调用方写出 `Cell()` 这种无意义代码。
abstract final class Cell {
  /// 空位。
  static const int empty = 0;

  /// 黑子。
  static const int black = 1;

  /// 白子。
  static const int white = 2;
}

/// 15 路标准五子棋棋盘。
///
/// 内部用一维字节数组存储全部 225 个交叉点，
/// 二维坐标 (x, y) 与一维下标的换算公式：`index = y * size + x`。
/// （x 是列号、y 是行号，均从左上角 (0, 0) 开始）
///
/// 字节数组 Uint8List 的优势：
/// - 每格只占 1 字节，整盘仅 225 字节，复制棋盘做 AI 推演几乎零成本；
/// - 内存连续，CPU 缓存友好，搜索时的批量扫描明显快于嵌套列表。
class Board {
  /// 棋盘边长（路数）。标准五子棋为 15 路。
  static const int size = 15;

  /// 全部格子内容，行优先排列。
  final Uint8List _cells;

  /// 创建一张空棋盘。
  Board() : _cells = Uint8List(size * size);

  /// 从已有棋盘快速复制的私有构造器（供 [copy] 使用）。
  Board._fromCells(this._cells);

  /// 读取指定坐标的格子内容，返回 [Cell] 三种常量之一。
  int get(int x, int y) => _cells[y * size + x];

  /// 坐标是否落在棋盘内。
  ///
  /// UI 手势换算出的坐标可能越界（点到了棋盘外），
  /// 任何落子操作前都必须先经过这一关。
  static bool inBounds(int x, int y) =>
      x >= 0 && x < size && y >= 0 && y < size;

  /// 指定坐标是否为空位（可落子）。
  bool isEmpty(int x, int y) => inBounds(x, y) && get(x, y) == Cell.empty;

  /// 在指定坐标放置一枚棋子。
  ///
  /// 只改数据、不做规则校验——校验是 [rules.dart] 的职责。
  /// 这样拆分让单元测试可以随意摆出任意局面来验证规则。
  void place(int x, int y, int stone) {
    assert(inBounds(x, y), '落子坐标越界: ($x, $y)');
    assert(stone == Cell.black || stone == Cell.white, '非法棋子: $stone');
    _cells[y * size + x] = stone;
  }

  /// 移除指定坐标的棋子（悔棋时使用）。
  void remove(int x, int y) {
    assert(inBounds(x, y), '移除坐标越界: ($x, $y)');
    _cells[y * size + x] = Cell.empty;
  }

  /// 清空整个棋盘（新一局时使用）。
  void clear() => _cells.fillRange(0, _cells.length, Cell.empty);

  /// 棋盘是否已满（用于判定平局）。
  bool get isFull => !_cells.contains(Cell.empty);

  /// 当前棋子总数。
  int get stoneCount {
    var count = 0;
    for (final cell in _cells) {
      if (cell != Cell.empty) count++;
    }
    return count;
  }

  /// 产生一份完全独立的副本。
  ///
  /// Dart 中对象默认按引用传递——如果直接把 Board 传给别人修改，
  /// 原棋盘会被一起改动。所以任何需要「假设性推演」的场景
  /// （比如 M2 的 AI 试探性落子）都必须先 copy 再动手。
  Board copy() => Board._fromCells(Uint8List.fromList(_cells));

  /// 调试输出：打印成字符画，控制台看局面用。
  @override
  String toString() {
    final buffer = StringBuffer();
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        buffer.write(switch (get(x, y)) {
          Cell.black => 'X',
          Cell.white => 'O',
          _ => '.',
        });
        buffer.write(' ');
      }
      buffer.writeln();
    }
    return buffer.toString();
  }
}
