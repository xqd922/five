/// 棋盘交互视图：把 [BoardPainter] 的绘制与触摸手势组装成一个组件。
///
/// 【职责边界】本组件是「哑」的：
/// 它只负责展示传入的盘面、把手势换算成格坐标后回调出去。
/// 落子规则、状态变更全部由上层（GameScreen → GameController）处理。
/// 这样拆分让棋盘可以被任意场景复用（对局、将来的复盘回放），
/// 也让手势换算逻辑可以脱离业务单独测试。
library;

import 'package:flutter/material.dart';

import 'package:five/core/board.dart';
import 'package:five/core/rules.dart';
import 'package:five/ui/board_painter.dart';

class BoardView extends StatelessWidget {
  /// 要绘制的盘面。
  final Board board;

  /// 最近一手坐标（末手标记）。
  final Point? lastMove;

  /// 获胜连线（胜利高亮）。
  final List<Point>? winLine;

  /// 玩家点击了某个交叉点；无效点击（界外/半格外）不会触发。
  ///
  /// 对局结束后上层应传 null 来冻结输入，而不是在这里判断状态。
  final void Function(Point cell)? onCellTap;

  const BoardView({
    super.key,
    required this.board,
    required this.lastMove,
    required this.winLine,
    this.onCellTap,
  });

  @override
  Widget build(BuildContext context) {
    // Material 3 配色推导出的棋盘调色板，随主题明暗自动切换。
    final palette = BoardPalette.fromTheme(Theme.of(context));
    final interactive = onCellTap != null;

    return AspectRatio(
      aspectRatio: 1, // 棋盘恒为正方形，宽度交给父级约束
      child: CustomPaint(
        painter: BoardPainter(
          board: board,
          lastMove: lastMove,
          winLine: winLine,
          palette: palette,
        ),
        child: interactive
            ? GestureDetector(
                behavior: HitTestBehavior.opaque, // 空白区域也要响应点击
                onTapUp: (details) {
                  // 用与绘制完全相同的几何模型反算格子——
                  // 「画在哪」和「点在哪」共用一套数学，天然对齐。
                  final geo = BoardGeometry.forSide(
                    context.size?.shortestSide ?? 0,
                  );
                  final cell = geo.toCell(details.localPosition);
                  if (cell != null) onCellTap!(cell);
                },
              )
            : null, // 传入 null 回调 = 观看模式（终局/复盘时）
      ),
    );
  }
}
