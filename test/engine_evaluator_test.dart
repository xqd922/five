/// 评估器单元测试。
///
/// 核心思路：摆出「棋型一眼可辨」的局面，断言分数的相对关系。
/// 评估器的绝对数值不重要（调参阶段会改），但棋型间的强弱顺序
/// 必须永远正确——这是 AI 不出昏招的底线。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:five_core/five_core.dart';
import 'package:five/engine/evaluator.dart';
import 'package:five/engine/patterns.dart';

void main() {
  /// 从 (x, y) 沿 (dx, dy) 连放 count 枚 [stone]。
  void placeLine(
    Board board,
    int x,
    int y,
    int dx,
    int dy,
    int count,
    int stone,
  ) {
    for (var i = 0; i < count; i++) {
      board.place(x + dx * i, y + dy * i, stone);
    }
  }

  group('Evaluator 基础性质', () {
    test('空盘评估为零', () {
      expect(Evaluator.evaluate(Board(), Cell.black), 0);
    });

    test('对称局面评估为零', () {
      final board = Board();
      placeLine(board, 5, 7, 1, 0, 3, Cell.black);
      placeLine(board, 5, 8, 1, 0, 3, Cell.white); // 白方镜像一条三连
      // 双方各有同型棋子 → 差值为零（允许因线扫描方向产生的极小偏差，
      // 但此例完全同构，应为精确零）。
      expect(
        Evaluator.scoreFor(board, Cell.black),
        Evaluator.scoreFor(board, Cell.white),
      );
    });

    test('己方占优返回正分，被动局面返回负分', () {
      final board = Board();
      placeLine(board, 5, 7, 1, 0, 3, Cell.black); // 黑活三级局面
      expect(Evaluator.evaluate(board, Cell.black), isPositive);
      expect(Evaluator.evaluate(board, Cell.white), isNegative);
    });

    test('hasFive 正确识别终局', () {
      final board = Board();
      placeLine(board, 4, 7, 1, 0, 5, Cell.black);
      expect(Evaluator.hasFive(board, Cell.black), isTrue);
      expect(Evaluator.hasFive(board, Cell.white), isFalse);
    });
  });

  group('Evaluator 棋型强弱排序', () {
    int scoreOf(void Function(Board) setup) {
      final board = Board();
      setup(board);
      return Evaluator.scoreFor(board, Cell.black);
    }

    test('五连 > 活四 > 冲四 > 活三', () {
      final fiveScore = scoreOf((b) => placeLine(b, 4, 7, 1, 0, 5, Cell.black));
      final openFourScore =
          scoreOf((b) => placeLine(b, 5, 7, 1, 0, 4, Cell.black));
      final fourScore = scoreOf((b) {
        placeLine(b, 5, 7, 1, 0, 4, Cell.black);
        b.place(4, 7, Cell.white); // 左端堵死 → 冲四
      });
      final openThreeScore =
          scoreOf((b) => placeLine(b, 6, 7, 1, 0, 3, Cell.black));

      expect(fiveScore, greaterThan(openFourScore));
      expect(openFourScore, greaterThan(fourScore));
      expect(fourScore, greaterThan(openThreeScore));
    });

    test('跳冲四（X_XXX）也被识别为冲四量级', () {
      final jumpFourScore = scoreOf((b) {
        b.place(5, 7, Cell.black);
        b.place(7, 7, Cell.black);
        b.place(8, 7, Cell.black);
        b.place(9, 7, Cell.black);
      });
      final openThreeScore =
          scoreOf((b) => placeLine(b, 6, 7, 1, 0, 3, Cell.black));

      expect(jumpFourScore, greaterThan(openThreeScore));
    });

    test('眠三弱于活三', () {
      final sleepThreeScore = scoreOf((b) {
        placeLine(b, 5, 7, 1, 0, 3, Cell.black);
        b.place(4, 7, Cell.white); // 左堵
        b.place(9, 7, Cell.white); // 右堵死两连空的可能
      });
      final openThreeScore =
          scoreOf((b) => placeLine(b, 6, 7, 1, 0, 3, Cell.black));

      expect(sleepThreeScore, lessThan(openThreeScore));
      expect(sleepThreeScore, greaterThan(0)); // 但仍优于无子
    });

    test('斜向棋型同样被识别', () {
      final diagOpenThree =
          scoreOf((b) => placeLine(b, 5, 5, 1, 1, 3, Cell.black));
      expect(diagOpenThree,
          greaterThanOrEqualTo(patternScores[Pattern.openThree]!));
    });
  });

  group('Evaluator 性能冒烟', () {
    test('中盘复杂局面单次评估在毫秒级', () {
      final board = Board();
      var stone = Cell.black;
      // 随手摆一个 40 子的密集中盘（伪随机但确定性）。
      var seed = 42;
      for (var i = 0; i < 40; i++) {
        seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
        final x = (seed >> 7) % Board.size;
        final y = (seed >> 13) % Board.size;
        if (board.isEmpty(x, y)) {
          board.place(x, y, stone);
          stone = Evaluator.opposite(stone);
        }
      }

      final watch = Stopwatch()..start();
      Evaluator.evaluate(board, Cell.black);
      watch.stop();

      // 宽松上限：CI 与低端机也要稳过。当前实现实测远低于此值。
      expect(watch.elapsedMilliseconds, lessThan(50));
    });
  });
}
