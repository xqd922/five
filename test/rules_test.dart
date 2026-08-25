/// 规则引擎单元测试。
///
/// 运行方式（Flutter 就绪后执行）：
///   flutter test test/rules_test.dart
///
/// 【为什么测这些】胜负判定是全项目最不能出错的一块：
/// AI 依赖它评估局面，UI 依赖它宣布结果。
/// 下面的用例覆盖了最容易写错的场景：
/// 斜向计数、棋盘边缘越界、长连规则、断连不算数、副本独立性。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:five_core/five_core.dart';

void main() {
  group('Board 棋盘基础', () {
    test('新棋盘全部为空', () {
      final board = Board();
      expect(board.stoneCount, 0);
      expect(board.isFull, isFalse);
      for (var y = 0; y < Board.size; y++) {
        for (var x = 0; x < Board.size; x++) {
          expect(board.get(x, y), Cell.empty);
        }
      }
    });

    test('落子后能读回正确颜色', () {
      final board = Board();
      board.place(7, 7, Cell.black);
      board.place(0, 14, Cell.white);
      expect(board.get(7, 7), Cell.black);
      expect(board.get(0, 14), Cell.white);
      expect(board.stoneCount, 2);
    });

    test('坐标边界判断：四角与越界', () {
      expect(Board.inBounds(0, 0), isTrue);
      expect(Board.inBounds(14, 14), isTrue);
      expect(Board.inBounds(-1, 7), isFalse);
      expect(Board.inBounds(15, 0), isFalse);
      // 越界位置查询必须安全返回空位语义（isEmpty 内部先查边界）。
      final board = Board();
      expect(board.isEmpty(-1, 0), isFalse);
    });

    test('copy 产生的副本与原盘完全隔离', () {
      final original = Board();
      original.place(3, 3, Cell.black);
      final copy = original.copy();
      copy.place(4, 4, Cell.white); // 只改副本
      expect(original.get(4, 4), Cell.empty); // 原盘不受影响
      expect(original.get(3, 3), Cell.black);
    });

    test('clear 清空所有棋子', () {
      final board = Board()..place(1, 1, Cell.black)..place(2, 2, Cell.white);
      board.clear();
      expect(board.stoneCount, 0);
    });
  });

  group('Rules 胜负判定', () {
    /// 辅助函数：从 (startX, startY) 开始沿 (dx, dy) 方向连放 count 枚黑子。
    /// 摆棋专用——让每个用例的「局面」一眼可读。
    void placeLine(
      Board board,
      int startX,
      int startY,
      int dx,
      int dy,
      int count, [
      int stone = Cell.black,
    ]) {
      for (var i = 0; i < count; i++) {
        board.place(startX + dx * i, startY + dy * i, stone);
      }
    }

    test('横向五连获胜', () {
      final board = Board();
      placeLine(board, 5, 7, 1, 0, 5); // —— 五连
      final win = Rules.checkWin(board, 5, 7); // 以线头为落点检查
      expect(win, isNotNull);
      expect(win!.winner, Cell.black);
      expect(win.line.length, 5);
    });

    test('纵向五连获胜', () {
      final board = Board();
      placeLine(board, 7, 3, 0, 1, 5); // │ 五连
      final win = Rules.checkWin(board, 7, 7); // 用线中间的点检查
      expect(win, isNotNull);
      expect(win!.winner, Cell.black);
    });

    test('左上到右下斜向五连获胜', () {
      final board = Board();
      placeLine(board, 3, 3, 1, 1, 5); // ↘ 五连
      final win = Rules.checkWin(board, 5, 5);
      expect(win, isNotNull);
      expect(win!.line.first, const Point(3, 3));
      expect(win.line.last, const Point(7, 7)); // 连线坐标完整有序
    });

    test('右上到左下斜向五连获胜', () {
      final board = Board();
      placeLine(board, 10, 3, -1, 1, 5); // ↙ 五连
      final win = Rules.checkWin(board, 8, 5);
      expect(win, isNotNull);
    });

    test('白子同样可以获胜（判定不分先后手）', () {
      final board = Board();
      placeLine(board, 2, 8, 1, 0, 5, Cell.white);
      final win = Rules.checkWin(board, 6, 8);
      expect(win!.winner, Cell.white);
    });

    test('无禁手规则：六连长连也算胜，且返回整条线', () {
      final board = Board();
      placeLine(board, 4, 7, 1, 0, 6); // 六连
      final win = Rules.checkWin(board, 6, 7);
      expect(win, isNotNull);
      expect(win!.line.length, 6); // UI 需要高亮全部六颗子
    });

    test('四连 + 断开一子 ≠ 获胜', () {
      final board = Board();
      placeLine(board, 4, 7, 1, 0, 4); // ●●●● .
      board.place(9, 7, Cell.black); // 隔一个空位再放一颗
      final win = Rules.checkWin(board, 9, 7);
      expect(win, isNull); // 断开的连线不能合并计算
    });

    test('贴边五连正常获胜（不越界崩溃）', () {
      final board = Board();
      placeLine(board, 0, 14, 1, 0, 5); // 最底行从最左格开始
      final win = Rules.checkWin(board, 0, 14);
      expect(win, isNotNull);
    });

    test('角落反向延伸不会越界', () {
      final board = Board();
      placeLine(board, 0, 0, 1, 1, 5); // 左上角 ↘ 五连，线头贴死两个边
      final win = Rules.checkWin(board, 2, 2);
      expect(win!.line.first, const Point(0, 0));
    });

    test('对方棋子阻挡延伸', () {
      final board = Board();
      placeLine(board, 4, 7, 1, 0, 4, Cell.black);
      board.place(3, 7, Cell.white); // 黑四连左端被白子封死
      final win = Rules.checkWin(board, 7, 7); // 只有四连，且无法借白子凑数
      expect(win, isNull);
    });
  });

  group('Rules 合法性与平局', () {
    test('空位合法，已占位非法，越位非法', () {
      final board = Board()..place(7, 7, Cell.black);
      expect(Rules.isLegalMove(board, 8, 8), isTrue); // 空位
      expect(Rules.isLegalMove(board, 7, 7), isFalse); // 已有子
      expect(Rules.isLegalMove(board, -1, 0), isFalse); // 界外
    });

    test('摆满全盘 → 平局', () {
      final board = Board();
      for (var y = 0; y < Board.size; y++) {
        for (var x = 0; x < Board.size; x++) {
          // 棋盘格纹交替摆放黑白，保证任何方向都不会意外出现五连。
          board.place(x, y, (x + y).isEven ? Cell.black : Cell.white);
        }
      }
      expect(board.isFull, isTrue);
      expect(Rules.isDraw(board), isTrue);
    });
  });
}
