/// 棋盘绘制与坐标换算。
///
/// 本文件包含两个协作的部分：
/// 1. [BoardGeometry] —— 纯数学：像素坐标 ↔ 棋盘格坐标的互相换算，
///    绘制和手势识别共用同一套换算，保证「点哪儿落哪儿」永远一致；
/// 2. [BoardPainter] —— 在 Canvas 上依次画出：底板 → 网格 → 星位 →
///    棋子 → 末手标记 → 胜利连线。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:five_core/five_core.dart';

/// 棋盘几何换算器。
///
/// 布局约定：棋盘四周各留一个格宽的空白（margin），
/// 因此 15 路棋盘的总宽度被划分为 16 格：
/// 第 i 条线的像素位置 = (i + 1) × cellSize，i ∈ [0, 14]。
class BoardGeometry {
  /// 每格的像素尺寸。
  final double cellSize;

  const BoardGeometry(this.cellSize);

  /// 根据画布边长构造（棋盘恒为正方形）。
  factory BoardGeometry.forSide(double side) =>
      BoardGeometry(side / (Board.size + 1));

  /// 格坐标 → 画布像素中心点。
  Offset toPixel(int x, int y) =>
      Offset((x + 1) * cellSize, (y + 1) * cellSize);

  /// 像素点 → 最接近的格坐标；距离超过半格视为无效点击返回 null。
  ///
  /// 这个「半格容差」很关键：手指点到两条线之间时，
  /// 自动吸附到最近的交点；点到棋盘最外圈之外则不响应。
  Point? toCell(Offset position) {
    final x = (position.dx / cellSize).round() - 1;
    final y = (position.dy / cellSize).round() - 1;
    if (!Board.inBounds(x, y)) return null;
    final center = toPixel(x, y);
    final distance = (position - center).distance;
    return distance <= cellSize / 2 ? Point(x, y) : null;
  }
}

/// 棋盘配色方案，从 Material 3 的 ColorScheme 推导。
///
/// 【M3 抽象风的取舍】不用贴图木纹，而是让棋盘底色跟随主题种子色，
/// 黑白棋子在明暗两种模式下都保证对比度：
/// - 浅色模式：青瓷色系底 + 墨黑子 / 月白子；
/// - 深色模式：深青灰底 + 高亮黑子（带描边）/ 纯白子。
class BoardPalette {
  final Color board;
  final Color gridLine;
  final Color borderLine;
  final Color starPoint;
  final Color blackStone;
  final Color whiteStone;
  final Color whiteStoneEdge; // 深色模式下白子不需要描边，此色与白子同值
  final Color lastMark; // 末手标记色（与双方棋子都形成对比）
  final Color winLine;

  const BoardPalette({
    required this.board,
    required this.gridLine,
    required this.borderLine,
    required this.starPoint,
    required this.blackStone,
    required this.whiteStone,
    required this.whiteStoneEdge,
    required this.lastMark,
    required this.winLine,
  });

  /// 从当前主题推导配色。
  factory BoardPalette.fromTheme(ThemeData theme) {
    final scheme = theme.colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    // 深色模式下把棋盘底色调得更深一档，让白色网格线自然浮现。
    final boardColor =
        isDark ? Color.lerp(scheme.surfaceContainerLowest, Colors.black, .25)! : scheme.surfaceContainerHigh;

    return BoardPalette(
      board: boardColor,
      gridLine: scheme.onSurface.withValues(alpha: isDark ? .30 : .38),
      borderLine: scheme.onSurface.withValues(alpha: isDark ? .55 : .65),
      starPoint: scheme.onSurface.withValues(alpha: .55),
      blackStone: isDark ? const Color(0xFF1A1C1E) : scheme.onSurface,
      whiteStone: Colors.white,
      whiteStoneEdge: isDark ? Colors.white : scheme.outline,
      lastMark: scheme.error, // 用主题错误色做末手标记，醒目且随主题变化
      winLine: scheme.primary,
    );
  }
}

/// 棋盘画笔。
class BoardPainter extends CustomPainter {
  /// 要绘制的盘面。
  final Board board;

  /// 最近一手（画标记用）；可为 null。
  final Point? lastMove;

  /// 获胜连线（画高亮用）；可为 null。
  final List<Point>? winLine;

  /// 手顺表（配合 [showMoveNumbers] 在每颗子上标序号）。
  final List<Point> moves;

  /// 是否显示手数数字。
  final bool showMoveNumbers;

  /// AI 提示落点（画特殊标记）；可为 null。
  final Point? hint;

  /// 正在播放入场动画的棋子；可为 null（无动画）。
  final Point? droppingStone;

  /// 入场缩放系数：0 = 刚出现，1 = 完全落下。easeOutBack 曲线会
  /// 短暂超过 1 再回弹，形成「弹」的手感。
  final double dropScale;

  /// 配色。
  final BoardPalette palette;

  BoardPainter({
    required this.board,
    required this.lastMove,
    required this.winLine,
    this.moves = const [],
    this.showMoveNumbers = false,
    this.hint,
    this.droppingStone,
    this.dropScale = 1.0,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geo = BoardGeometry.forSide(size.shortestSide);

    _drawBase(canvas, size);
    _drawGrid(canvas, geo);
    if (hint != null && board.get(hint!.x, hint!.y) == Cell.empty) {
      _drawHintMark(canvas, geo, hint!);
    }
    _drawStones(canvas, geo);
    if (showMoveNumbers) {
      _drawMoveNumbers(canvas, geo);
    }
    if (winLine != null) {
      _drawWinLine(canvas, geo, winLine!);
    }
    if (lastMove != null && winLine == null) {
      _drawLastMoveMark(canvas, geo, lastMove!);
    }
  }

  /// 底板：一块带圆角的整体色块。
  void _drawBase(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      Paint()..color = palette.board,
    );
  }

  /// 网格：15 横线 × 15 纵线，外框加粗，5 个星位点。
  void _drawGrid(Canvas canvas, BoardGeometry geo) {
    final first = geo.toPixel(0, 0);
    final last = geo.toPixel(Board.size - 1, Board.size - 1);
    final halfLineWidth = geo.cellSize / 28; // 内部细线的视觉厚度

    final thin = Paint()
      ..color = palette.gridLine
      ..strokeWidth = math.max(1, halfLineWidth)
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < Board.size; i++) {
      final p = geo.toPixel(i, 0); // 第 i 列顶点
      final q = geo.toPixel(i, Board.size - 1); // 第 i 列底点
      canvas.drawLine(p, q, thin);

      final r = geo.toPixel(0, i); // 第 i 行左端
      final s = geo.toPixel(Board.size - 1, i); // 第 i 行右端
      canvas.drawLine(r, s, thin);
    }

    // 外框：比内线粗一倍，勾勒出「盘」的边界感。
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(first.dx, first.dy, last.dx, last.dy),
        const Radius.circular(4),
      ),
      Paint()
        ..color = palette.borderLine
        ..strokeWidth = halfLineWidth * 2
        ..style = PaintingStyle.stroke,
    );

    // 星位：四个角星 + 天元。标准 15 路棋盘位于 (3,3) 及对称位。
    final starPaint = Paint()..color = palette.starPoint;
    const starPositions = [(3, 3), (11, 3), (3, 11), (11, 11), (7, 7)];
    for (final (x, y) in starPositions) {
      canvas.drawCircle(
        geo.toPixel(x, y),
        geo.cellSize / 10,
        starPaint,
      );
    }
  }

  /// 全部棋子：圆形 + 微阴影，黑子深色白子浅色。
  void _drawStones(Canvas canvas, BoardGeometry geo) {
    final baseRadius = geo.cellSize * 0.44;

    for (var y = 0; y < Board.size; y++) {
      for (var x = 0; x < Board.size; x++) {
        final stone = board.get(x, y);
        if (stone == Cell.empty) continue;

        // 入场动画：正在弹入的子按曲线缩放，其余保持原大。
        final isDropping =
            droppingStone != null && droppingStone!.x == x && droppingStone!.y == y;
        final radius = baseRadius * (isDropping ? dropScale : 1.0);
        if (radius <= 0.01) continue; // 缩放起点为 0 时直接跳过绘制

        final center = geo.toPixel(x, y);

        // 阴影：向下偏移一小段，营造轻微悬浮感。
        canvas.drawCircle(
          center.translate(0, radius * .12),
          radius,
          Paint()
            ..color = Colors.black.withValues(alpha: .25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );

        final fill = Paint()
          ..color = stone == Cell.black
              ? palette.blackStone
              : palette.whiteStone;
        canvas.drawCircle(center, radius, fill);

        // 白子在浅色棋盘上需要一圈描边才不会「融化」进底色。
        if (stone == Cell.white) {
          canvas.drawCircle(
            center,
            radius,
            Paint()
              ..color = palette.whiteStoneEdge
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4,
          );
        }
      }
    }
  }

  /// 末手标记：在最新落子上画一个小圆环，一眼看出刚才下在哪。
  void _drawLastMoveMark(Canvas canvas, BoardGeometry geo, Point move) {
    final paint = Paint()
      ..color = palette.lastMark
      ..style = PaintingStyle.stroke
      ..strokeWidth = geo.cellSize / 14;
    canvas.drawCircle(geo.toPixel(move.x, move.y), geo.cellSize * 0.18, paint);
  }

  /// AI 提示标记：半透明主色圆盘 + 细描边，视觉上「悬浮」于棋盘之上、
  /// 与真实棋子明显区分。只在空位上绘制。
  void _drawHintMark(Canvas canvas, BoardGeometry geo, Point point) {
    final center = geo.toPixel(point.x, point.y);
    final radius = geo.cellSize * 0.44;

    canvas.drawCircle(
      center,
      radius,
      Paint()..color = palette.winLine.withValues(alpha: .28),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = palette.winLine
        ..style = PaintingStyle.stroke
        ..strokeWidth = geo.cellSize / 12,
    );
  }

  /// 手数数字：每颗子上标出它是第几乎（1 起）。
  ///
  /// 用 TextPainter 把文字画进 Canvas；字号随格子缩放，
  /// 黑子上用白字、白子上用黑字保证对比度。
  void _drawMoveNumbers(Canvas canvas, BoardGeometry geo) {
    if (moves.isEmpty) return;

    final fontSize = geo.cellSize * 0.42;
    for (var i = 0; i < moves.length; i++) {
      final move = moves[i];
      if (board.get(move.x, move.y) == Cell.empty) continue; // 回放安全防护

      final isBlackStone =
          board.get(move.x, move.y) == Cell.black;
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: TextStyle(
            color: isBlackStone ? Colors.white : Colors.black,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        geo.toPixel(move.x, move.y) -
            Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  /// 胜利连线：一条粗描边从线头贯穿到线尾，端点是圆帽。
  void _drawWinLine(Canvas canvas, BoardGeometry geo, List<Point> line) {
    if (line.isEmpty) return;
    final paint = Paint()
      ..color = palette.winLine
      ..strokeWidth = geo.cellSize / 9
      ..strokeCap = StrokeCap.round;
    final start = geo.toPixel(line.first.x, line.first.y);
    final end = geo.toPixel(line.last.x, line.last.y);
    canvas.drawLine(start, end, paint);
  }

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) {
    // 盘面内容变化的可观测信号：手数不同、末手不同、胜负出现、
    // 提示变化、显示开关切换。
    // 手数相同但末手不同的情况出现在「悔棋后改下别处」。
    return oldDelegate.board.stoneCount != board.stoneCount ||
        oldDelegate.lastMove != lastMove ||
        oldDelegate.winLine != winLine ||
        oldDelegate.hint != hint ||
        oldDelegate.droppingStone != droppingStone ||
        oldDelegate.dropScale != dropScale ||
        oldDelegate.showMoveNumbers != showMoveNumbers ||
        oldDelegate.palette != palette;
  }
}
