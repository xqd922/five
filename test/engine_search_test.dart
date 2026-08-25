/// 搜索引擎战术测试。
///
/// 【设计思想】评估器的对错看分数关系，搜索引擎的对错看「选点」。
/// 下面每道题都是一个人类一眼就能答对的战术场景，
/// AI 答错任何一题都意味着引擎存在结构性缺陷。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:five_core/five_core.dart';

import 'package:five/engine/search.dart';

void main() {
  final engine = SearchEngine();

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

  group('SearchEngine 战术必答题', () {
    test('题1：己方四连 —— 一手成五必须立刻赢', () {
      final board = Board();
      placeLine(board, 4, 7, 1, 0, 4, Cell.black); // 黑活四 XXXX_
      board.place(3, 3, Cell.white); // 白随便一枚子

      final result = engine.findBestMove(
        board,
        Cell.black,
        maxDepth: 2,
        timeBudget: const Duration(seconds: 5),
      );

      // 成五点是 (8,7)；(3,7) 也成五但贴着白子无妨——两个都算对。
      expect(result.score, greaterThan(9000000), reason: '应识别为必胜');
      expect(result.move.y, 7);
      expect(result.move.x, anyOf(8, 3));
    });

    test('题2：对方冲四 —— 必须堵住唯一成五点', () {
      final board = Board();
      placeLine(board, 4, 7, 1, 0, 4, Cell.black); // 黑冲四威胁 OXXXX_
      board.place(3, 7, Cell.white); // 白已在左端堵了一头
      // 白方其他散子。
      board.place(7, 3, Cell.white);
      board.place(11, 11, Cell.black);

      final result = engine.findBestMove(
        board,
        Cell.white,
        maxDepth: 2,
        timeBudget: const Duration(seconds: 5),
      );

      // 黑的成五点只剩 (8,7)，白不堵就输。
      expect(result.move, const Point(8, 7),
          reason: '必须堵住黑棋唯一的成五点');
    });

    test('题3：能直接赢时绝不去做别的', () {
      final board = Board();
      placeLine(board, 4, 4, 1, 1, 4, Cell.white); // 白斜活四
      placeLine(board, 4, 10, 1, 0, 3, Cell.black); // 黑只有三连

      final result = engine.findBestMove(
        board,
        Cell.white,
        maxDepth: 2,
        timeBudget: const Duration(seconds: 5),
      );

      // 白的成五点：(3,3) 或 (8,8)。
      expect(result.score, greaterThan(9000000));
      expect(
        result.move,
        anyOf(const Point(3, 3), const Point(8, 8)),
        reason: '白棋应当直接成五，而不是去管黑三连',
      );
    });

    test('题4：空盘第一手下在天元附近', () {
      final result = engine.findBestMove(
        Board(),
        Cell.black,
        maxDepth: 2,
        timeBudget: const Duration(seconds: 5),
      );
      expect(result.move, const Point(7, 7));
    });
  });
}
