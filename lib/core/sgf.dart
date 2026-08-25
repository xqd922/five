/// SGF 棋谱导出 —— M3 辅助功能之一。
///
/// SGF (Smart Game Format) 是棋类软件的通用交换格式。
/// 五子棋借用围棋的字段：GM[1]（棋类编号）、SZ[15]（路数），
/// 每手棋形如 ;B[hh]（黑方落到 h 列 h 行）。
/// 坐标字母从 a 起算：0→a, 7→h, 14→o。
///
/// 结构速览：`(;根节点属性;B[xx];W[yy]…)`——
/// 第一个 `;` 后是整局的元信息（规则、玩家、结果），
/// 之后每手棋一个 `;颜色[坐标]`。
///
/// 导出的文件可直接导入奕客、Sabaki 等主流棋谱工具复盘。
library;

import 'package:five/core/rules.dart';

abstract final class SgfExporter {
  /// 把整局手顺转换为 SGF 文本。
  ///
  /// [result] 为终局结果字符串（如 "B+" 黑胜 / "0" 平局），
  /// 进行中的对局传 null。
  static String export({
    required List<Point> moves,
    String blackName = 'Black',
    String whiteName = 'White',
    String? result,
  }) {
    final out = StringBuffer()
      ..write('(;GM[1]FF[4]SZ[15]AP[Five:1.0]')
      ..write('PB[$blackName]')
      ..write('PW[$whiteName]');
    if (result != null) out.write('RE[$result]');

    for (var i = 0; i < moves.length; i++) {
      final move = moves[i];
      final color = i.isEven ? 'B' : 'W'; // 第 0 手黑先
      out.write(';$color[${_coord(move.x)}${_coord(move.y)}]');
    }
    out.write(')');
    return out.toString();
  }

  /// 0..14 → 'a'..'o'。
  static String _coord(int value) => String.fromCharCode(97 + value);
}
