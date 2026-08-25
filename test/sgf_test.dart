/// SGF 导出测试。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:five_core/five_core.dart';

void main() {
  group('SgfExporter', () {
    test('空局只输出根节点', () {
      final sgf = SgfExporter.export(moves: const []);
      expect(sgf, startsWith('(;GM[1]'));
      expect(sgf, contains('SZ[15]'));
      expect(sgf, endsWith(')'));
      expect(';B['.allMatches(sgf).length, 0);
    });

    test('手顺坐标与黑白交替正确', () {
      final sgf = SgfExporter.export(moves: const [
        Point(7, 7), // 黑 → h h
        Point(8, 7), // 白 → i h
        Point(7, 8), // 黑 → h i
      ]);
      expect(sgf, contains(';B[hh]'));
      expect(sgf, contains(';W[ih]'));
      expect(sgf, contains(';B[hi]'));
      // 黑白严格交替：2黑1白。
      expect(';B['.allMatches(sgf).length, 2);
      expect(';W['.allMatches(sgf).length, 1);
    });

    test('边界坐标映射到 a 和 o', () {
      final sgf = SgfExporter.export(moves: const [
        Point(0, 0), // a a
        Point(14, 14), // o o
      ]);
      expect(sgf, contains(';B[aa]'));
      expect(sgf, contains(';W[oo]'));
    });

    test('终局结果写入 RE 字段', () {
      final sgf = SgfExporter.export(
        moves: const [],
        result: 'B+5',
      );
      expect(sgf, contains('RE[B+5]'));
    });
  });
}
