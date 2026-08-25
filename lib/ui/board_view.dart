/// 棋盘交互视图：绘制、手势、落子弹入动画的组装层。
///
/// 【职责边界】本组件是「哑」的：
/// 它只负责展示传入的盘面、把手势换算成格坐标后回调出去。
/// 落子规则、状态变更全部由上层（GameScreen → 控制器）处理。
///
/// 【动画】监测到手数增加时，对新落的子播放 140ms 弹入缩放；
/// 悔棋/回放（手数减少或跳变）不触发——只有「下了一手」才配得上动画。
library;

import 'package:flutter/material.dart';

import 'package:five_core/five_core.dart';
import 'package:five/ui/board_painter.dart';

class BoardView extends StatefulWidget {
  /// 要绘制的盘面。
  final Board board;

  /// 最近一手坐标（末手标记）。
  final Point? lastMove;

  /// 获胜连线（胜利高亮）。
  final List<Point>? winLine;

  /// 手顺表（手数标记用）。
  final List<Point> moves;

  /// 是否显示落子顺序数字。
  final bool showMoveNumbers;

  /// AI 提示标记位置。
  final Point? hint;

  /// 玩家点击了某个交叉点；无效点击不会触发。
  ///
  /// 对局结束后上层应传 null 来冻结输入，而不是在这里判断状态。
  final void Function(Point cell)? onCellTap;

  const BoardView({
    super.key,
    required this.board,
    required this.lastMove,
    required this.winLine,
    this.moves = const [],
    this.showMoveNumbers = false,
    this.hint,
    this.onCellTap,
  });

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dropController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
  );

  /// 正在播放入场动画的那一手。
  Point? _dropping;

  @override
  void didUpdateWidget(covariant BoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 仅当「恰好多出一手且末手变化」时弹入——覆盖人类落子与 AI 落子，
    // 排除悔棋（手数减少）与回放跳转（末手未变）。
    final grew = widget.moves.length == oldWidget.moves.length + 1;
    if (grew && widget.lastMove != oldWidget.lastMove) {
      setState(() => _dropping = widget.lastMove);
      _dropController.forward(from: 0).whenComplete(() {
        if (mounted) setState(() => _dropping = null);
      });
    }
  }

  @override
  void dispose() {
    _dropController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Material 3 配色推导出的棋盘调色板，随主题明暗自动切换。
    final palette = BoardPalette.fromTheme(Theme.of(context));
    final interactive = widget.onCellTap != null;

    return AspectRatio(
      aspectRatio: 1, // 棋盘恒为正方形，宽度交给父级约束
      child: AnimatedBuilder(
        animation: _dropController,
        builder: (context, _) {
          return CustomPaint(
            painter: BoardPainter(
              board: widget.board,
              lastMove: widget.lastMove,
              winLine: widget.winLine,
              moves: widget.moves,
              showMoveNumbers: widget.showMoveNumbers,
              hint: widget.hint,
              palette: palette,
              droppingStone: _dropping,
              dropScale:
                  Curves.easeOutBack.transform(_dropController.value),
            ),
            child: interactive
                ? GestureDetector(
                    behavior: HitTestBehavior.opaque, // 空白区域也响应
                    onTapUp: (details) {
                      // 与绘制共用同一套几何换算——
                      // 「画在哪」和「点在哪」天然对齐。
                      final geo = BoardGeometry.forSide(
                        context.size?.shortestSide ?? 0,
                      );
                      final cell = geo.toCell(details.localPosition);
                      if (cell != null) widget.onCellTap!(cell);
                    },
                  )
                : null, // 只读模式（终局/复盘/等待对方）
          );
        },
      ),
    );
  }
}
