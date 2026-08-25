/// 棋型定义与分值表 —— AI 引擎的「棋感」来源。
///
/// 【术语速成】
/// - 活四 (open four)：_XXXX_ 两端皆空 → 无论对手堵哪头，
///   另一头都能成五。等于下一手必胜。
/// - 冲四 (four)：一端被堵的四连（OXXXX_）或中间断开的四
///   （XXX_X）。只有一个成五点，对手可以挡。
/// - 活三 (open three)：下一步能形成「活四」的三连。
/// - 眠三 (sleep three)：只能形成「冲四」的三连，威胁弱一级。
///
/// 分值刻意拉开数量级：一个活四的价值必须远超任意多个眠三之和，
/// 否则 AI 会做出"贪十个小便宜而漏掉致命杀招"的蠢事。
library;

import 'package:five/core/board.dart';

/// 七种可识别的棋型，按威胁从高到低排列。
enum Pattern {
  /// 五连（或更长）—— 终局。
  five,

  /// 活四 _XXXX_。
  openFour,

  /// 冲四：OXXXX_ / _XXXXO / XXX_X / XX_XX / X_XXX。
  four,

  /// 活三：__XXX_ 或 _XXX__（至少一侧有两连空）。
  openThree,

  /// 眠三：仅能形成冲四的三连。
  sleepThree,

  /// 活二。
  openTwo,

  /// 眠二。
  sleepTwo,
}

/// 各棋型的基准分值。
///
/// 数值来自公开的五子棋引擎实践经验的典型量级；
/// 后续 M2 调参阶段会通过对弈胜率微调，但数量级关系不能破坏：
/// five > openFour > four > openThree > sleepThree > openTwo > sleepTwo
const Map<Pattern, int> patternScores = {
  Pattern.five: 10000000,
  Pattern.openFour: 1000000,
  Pattern.four: 100000,
  Pattern.openThree: 50000,
  Pattern.sleepThree: 5000,
  Pattern.openTwo: 500,
  Pattern.sleepTwo: 100,
};

/// 把一枚己方棋子周围的格子编码为模式串所用的字符。
abstract final class PatternChars {
  /// 己方棋子。
  static const String self = 'X';

  /// 敌方棋子与棋盘边界（对模式而言等价：都是「此路不通」）。
  static const String blocked = 'O';

  /// 空位。
  static const String empty = '_';
}

/// 将 [stone] 视角下的单个格内容转为编码字符。
String encodeCell(int cellContent, int stone) {
  if (cellContent == Cell.empty) return PatternChars.empty;
  return cellContent == stone ? PatternChars.self : PatternChars.blocked;
}
