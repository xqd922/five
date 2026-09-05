/// 棋盘绘制与坐标换算。
///
/// 本文件包含两个协作的部分：
/// 1. [BoardGeometry] —— 纯数学：像素坐标 ↔ 棋盘格坐标的互相换算，
///    绘制和手势识别共用同一套换算，保证「点哪儿落哪儿」永远一致；
/// 2. [BoardPainter] —— 在 Canvas 上依次画出：底板阴影与倒角 → 坐标标尺 → 网格 → 星位 →
///    拟真 3D 棋子（墨玉曜石 / 羊脂白玉）→ 末手标记 → 胜利光晕连线。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:five_core/five_core.dart';
import 'package:five/state/settings_provider.dart';

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
  Point? toCell(Offset position) {
    final x = (position.dx / cellSize).round() - 1;
    final y = (position.dy / cellSize).round() - 1;
    if (!Board.inBounds(x, y)) return null;
    final center = toPixel(x, y);
    final distance = (position - center).distance;
    return distance <= cellSize / 2 ? Point(x, y) : null;
  }
}

/// 棋盘配色方案，支持多种风格（经典榧木 / 水墨玄石 / 苍青碧玉）并自适应深浅色模式。
class BoardPalette {
  final BoardStyle style;
  final Color board;
  final Color boardTop;
  final Color boardBottom;
  final Color boardBevel;
  final Color boardBorder;
  final Color boardShadow;
  final Color gridLine;
  final Color borderLine;
  final Color starPoint;
  final Color coordinate;
  final Color blackStone;
  final Color whiteStone;
  final Color whiteStoneEdge;
  final Color lastMark;
  final Color winLine;

  const BoardPalette({
    this.style = BoardStyle.wood,
    required this.board,
    required this.boardTop,
    required this.boardBottom,
    required this.boardBevel,
    required this.boardBorder,
    required this.boardShadow,
    required this.gridLine,
    required this.borderLine,
    required this.starPoint,
    required this.coordinate,
    required this.blackStone,
    required this.whiteStone,
    required this.whiteStoneEdge,
    required this.lastMark,
    required this.winLine,
  });

  /// 默认从主题推导（保持向后兼容，默认使用经典榧木质感）。
  factory BoardPalette.fromTheme(ThemeData theme, {BoardStyle? style}) {
    final active = style ?? BoardStyle.wood;
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;

    return switch (active) {
      BoardStyle.wood => isDark
          ? BoardPalette(
              style: active,
              board: const Color(0xFF2A1C10),
              boardTop: const Color(0xFF322316),
              boardBottom: const Color(0xFF21150B),
              boardBevel: const Color(0xFF483523),
              boardBorder: const Color(0xFF150C06),
              boardShadow: Colors.black.withValues(alpha: .45),
              gridLine: const Color(0x8AD5B08A),
              borderLine: const Color(0xBFE2C5A5),
              starPoint: const Color(0xEAE2C5A5),
              coordinate: const Color(0x75D5B08A),
              blackStone: const Color(0xFF141518),
              whiteStone: Colors.white,
              whiteStoneEdge: const Color(0x55B0B8C2),
              lastMark: const Color(0xFFFFB74D),
              winLine: const Color(0xFFFFD54F),
            )
          : BoardPalette(
              style: active,
              board: const Color(0xFFE4BF83),
              boardTop: const Color(0xFFEED3A1),
              boardBottom: const Color(0xFFDCB779),
              boardBevel: const Color(0xFFFFF0D4),
              boardBorder: const Color(0xFFB08647),
              boardShadow: Colors.black.withValues(alpha: .22),
              gridLine: const Color(0xA356330E),
              borderLine: const Color(0xC7422306),
              starPoint: const Color(0xD9422306),
              coordinate: const Color(0x9456330E),
              blackStone: const Color(0xFF15171A),
              whiteStone: Colors.white,
              whiteStoneEdge: const Color(0x4DB0B8C2),
              lastMark: const Color(0xFFE65100),
              winLine: const Color(0xFFE65100),
            ),
      BoardStyle.zen => isDark
          ? BoardPalette(
              style: active,
              board: const Color(0xFF1B1E23),
              boardTop: const Color(0xFF22262D),
              boardBottom: const Color(0xFF16181D),
              boardBevel: const Color(0xFF2E343E),
              boardBorder: const Color(0xFF0F1114),
              boardShadow: Colors.black.withValues(alpha: .5),
              gridLine: const Color(0x6BB0BAC5),
              borderLine: const Color(0x99CAD5E2),
              starPoint: const Color(0xCCE2EAF3),
              coordinate: const Color(0x66B0BAC5),
              blackStone: const Color(0xFF111215),
              whiteStone: Colors.white,
              whiteStoneEdge: const Color(0x55A0AAB5),
              lastMark: const Color(0xFF4FC3F7),
              winLine: const Color(0xFF00E5FF),
            )
          : BoardPalette(
              style: active,
              board: const Color(0xFFE8EBEE),
              boardTop: const Color(0xFFF1F4F7),
              boardBottom: const Color(0xFFDFE3E7),
              boardBevel: const Color(0xFFFFFFFF),
              boardBorder: const Color(0xFFBAC1C7),
              boardShadow: Colors.black.withValues(alpha: .18),
              gridLine: const Color(0x85343B42),
              borderLine: const Color(0xB322272C),
              starPoint: const Color(0xD922272C),
              coordinate: const Color(0x80343B42),
              blackStone: const Color(0xFF15171A),
              whiteStone: Colors.white,
              whiteStoneEdge: const Color(0x45A0AAB5),
              lastMark: const Color(0xFF0288D1),
              winLine: const Color(0xFF0288D1),
            ),
      BoardStyle.jade => isDark
          ? BoardPalette(
              style: active,
              board: const Color(0xFF0E2223),
              boardTop: const Color(0xFF142E2F),
              boardBottom: const Color(0xFF081819),
              boardBevel: const Color(0xFF1E4244),
              boardBorder: const Color(0xFF040F10),
              boardShadow: Colors.black.withValues(alpha: .5),
              gridLine: const Color(0x7552D6CE),
              borderLine: const Color(0x9E78EAE3),
              starPoint: const Color(0xCC9DF6F1),
              coordinate: const Color(0x6E52D6CE),
              blackStone: const Color(0xFF101416),
              whiteStone: Colors.white,
              whiteStoneEdge: const Color(0x5552D6CE),
              lastMark: const Color(0xFF26A69A),
              winLine: const Color(0xFF00BFA5),
            )
          : BoardPalette(
              style: active,
              board: const Color(0xFFDCEEED),
              boardTop: const Color(0xFFE8F6F5),
              boardBottom: const Color(0xFFCEE4E3),
              boardBevel: const Color(0xFFF5FCFB),
              boardBorder: const Color(0xFF90B8B6),
              boardShadow: scheme.primary.withValues(alpha: .16),
              gridLine: const Color(0x7A0D4A47),
              borderLine: const Color(0xAD093936),
              starPoint: const Color(0xD0093936),
              coordinate: const Color(0x730D4A47),
              blackStone: const Color(0xFF121818),
              whiteStone: Colors.white,
              whiteStoneEdge: const Color(0x400D4A47),
              lastMark: const Color(0xFF00695C),
              winLine: const Color(0xFF00796B),
            ),
    };
  }
}

/// 棋盘画笔。
class BoardPainter extends CustomPainter {
  final Board board;
  final Point? lastMove;
  final List<Point>? winLine;
  final List<Point> moves;
  final bool showMoveNumbers;
  final Point? hint;
  final Point? droppingStone;
  final double dropScale;
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
    _drawCoordinates(canvas, geo, size);
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

  /// 底板：双层圆角色块 + 柔和投影 + 材质渐变 + 优雅倒角边框。
  void _drawBase(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    const radius = Radius.circular(18);
    final rrect = RRect.fromRectAndRadius(rect, radius);

    // 1. 底板外围柔和立体投影
    final shadowPaint = Paint()
      ..color = palette.boardShadow
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.shift(const Offset(0, 6)), radius),
      shadowPaint,
    );

    // 2. 底板渐变质感填充
    final basePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [palette.boardTop, palette.boardBottom],
      ).createShader(rect);
    canvas.drawRRect(rrect, basePaint);

    // 3. 木纹风格专有微弱仿生纹理（温润质感）
    if (palette.style == BoardStyle.wood) {
      _drawSubtleGrain(canvas, rect);
    }

    // 4. 内沿高光倒角
    final innerBevel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = palette.boardBevel.withValues(alpha: .5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(1.0), const Radius.circular(17)),
      innerBevel,
    );

    // 5. 外沿深色立体包边
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = palette.boardBorder;
    canvas.drawRRect(rrect, borderPaint);
  }

  /// 绘制极细腻的仿生木纹线条，增加天然材质感。
  void _drawSubtleGrain(Canvas canvas, Rect rect) {
    final grainPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.black.withValues(alpha: .035);

    final path = Path();
    final step = rect.height / 7;
    for (var i = 1; i < 7; i++) {
      final y = rect.top + i * step;
      path.reset();
      path.moveTo(rect.left, y);
      path.quadraticBezierTo(
        rect.left + rect.width * 0.45,
        y + (i.isEven ? 8.0 : -6.0),
        rect.right,
        y + (i.isEven ? -4.0 : 5.0),
      );
      canvas.drawPath(path, grainPaint);
    }
  }

  /// 绘制棋盘四周边框坐标标尺（横向 A-O，纵向 1-15，棋道美学）。
  void _drawCoordinates(Canvas canvas, BoardGeometry geo, Size size) {
    const letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K', 'L', 'M', 'N', 'O', 'P'];
    final fontSize = geo.cellSize * 0.28;
    final textStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      color: palette.coordinate,
      fontFamily: 'Roboto',
    );

    // 上下横向字母 (A-O)
    for (var i = 0; i < Board.size; i++) {
      final colPixel = geo.toPixel(i, 0).dx;
      final textSpan = TextSpan(text: letters[i], style: textStyle);
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();

      // 顶部
      tp.paint(canvas, Offset(colPixel - tp.width / 2, geo.cellSize * 0.42 - tp.height / 2));
      // 底部
      tp.paint(canvas, Offset(colPixel - tp.width / 2, size.height - geo.cellSize * 0.42 - tp.height / 2));
    }

    // 左右纵向数字 (15 到 1)
    for (var i = 0; i < Board.size; i++) {
      final rowPixel = geo.toPixel(0, i).dy;
      final numStr = '${Board.size - i}';
      final textSpan = TextSpan(text: numStr, style: textStyle);
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();

      // 左侧
      tp.paint(canvas, Offset(geo.cellSize * 0.42 - tp.width / 2, rowPixel - tp.height / 2));
      // 右侧
      tp.paint(canvas, Offset(size.width - geo.cellSize * 0.42 - tp.width / 2, rowPixel - tp.height / 2));
    }
  }

  /// 网格：15 横线 × 15 纵线，外框加粗立体双线，5 个星位点。
  void _drawGrid(Canvas canvas, BoardGeometry geo) {
    final first = geo.toPixel(0, 0);
    final last = geo.toPixel(Board.size - 1, Board.size - 1);
    final halfLineWidth = math.max(1.0, geo.cellSize / 30);

    final linePaint = Paint()
      ..color = palette.gridLine
      ..strokeWidth = halfLineWidth
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < Board.size; i++) {
      // 纵线
      final top = geo.toPixel(i, 0);
      final bottom = geo.toPixel(i, Board.size - 1);
      canvas.drawLine(top, bottom, linePaint);

      // 横线
      final left = geo.toPixel(0, i);
      final right = geo.toPixel(Board.size - 1, i);
      canvas.drawLine(left, right, linePaint);
    }

    // 网格外框：加粗并带柔和圆角
    final borderRect = Rect.fromLTRB(first.dx, first.dy, last.dx, last.dy);
    canvas.drawRRect(
      RRect.fromRectAndRadius(borderRect, const Radius.circular(3)),
      Paint()
        ..color = palette.borderLine
        ..strokeWidth = halfLineWidth * 2.2
        ..style = PaintingStyle.stroke,
    );

    // 星位：四个角星 + 天元，外圈微光晕 + 实心内核
    const starPositions = [(3, 3), (11, 3), (3, 11), (11, 11), (7, 7)];
    final starHaloPaint = Paint()..color = palette.starPoint.withValues(alpha: .22);
    final starCorePaint = Paint()..color = palette.starPoint;
    final starRadius = math.max(2.4, geo.cellSize / 11);

    for (final (x, y) in starPositions) {
      final center = geo.toPixel(x, y);
      canvas.drawCircle(center, starRadius * 1.5, starHaloPaint);
      canvas.drawCircle(center, starRadius, starCorePaint);
    }
  }

  /// 拟真 3D 棋子绘制：
  /// - 物理级投射投影（模拟顶光偏左上的漫射倒影）
  /// - 黑子：曜石墨玉质感，径向多层高光 + 边缘暗部反光
  /// - 白子：羊脂白玉质感，乳润珠光渐变 + 柔光高光弧
  void _drawStones(Canvas canvas, BoardGeometry geo) {
    final baseRadius = geo.cellSize * 0.44;

    for (var y = 0; y < Board.size; y++) {
      for (var x = 0; x < Board.size; x++) {
        final stone = board.get(x, y);
        if (stone == Cell.empty) continue;

        // 入场动画缩放
        final isDropping =
            droppingStone != null && droppingStone!.x == x && droppingStone!.y == y;
        final radius = baseRadius * (isDropping ? dropScale : 1.0);
        if (radius <= 0.05) continue;

        final center = geo.toPixel(x, y);

        // —— 1. 拟真触地弥散阴影 ——
        final shadowOffset = Offset(radius * 0.14, radius * 0.22);
        final shadowRadius = radius * 0.98;
        canvas.drawCircle(
          center + shadowOffset,
          shadowRadius,
          Paint()
            ..color = Colors.black.withValues(alpha: .36)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.28),
        );

        if (stone == Cell.black) {
          // —— 2. 黑子（曜石墨玉）——
          final focalPoint = Offset(center.dx - radius * 0.30, center.dy - radius * 0.32);
          final blackShader = RadialGradient(
            center: Alignment.center,
            focal: Alignment(
              (focalPoint.dx - center.dx) / radius,
              (focalPoint.dy - center.dy) / radius,
            ),
            focalRadius: 0.05,
            radius: 0.95,
            colors: const [
              Color(0xFF565B66), // 顶部柔和环境反射
              Color(0xFF282B32), // 弧面过渡
              Color(0xFF15171A), // 墨玉深层
              Color(0xFF0A0B0D), // 边缘极黑
            ],
            stops: const [0.0, 0.35, 0.72, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: radius));

          canvas.drawCircle(center, radius, Paint()..shader = blackShader);

          // 墨玉镜面微光弧（左上精美高光点）
          final specularCenter = Offset(center.dx - radius * 0.32, center.dy - radius * 0.34);
          canvas.drawOval(
            Rect.fromCenter(
              center: specularCenter,
              width: radius * 0.44,
              height: radius * 0.26,
            ),
            Paint()
              ..color = Colors.white.withValues(alpha: .24)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
          );
        } else {
          // —— 3. 白子（羊脂白玉 / 蛤碁石）——
          final focalPoint = Offset(center.dx - radius * 0.26, center.dy - radius * 0.28);
          final whiteShader = RadialGradient(
            center: Alignment.center,
            focal: Alignment(
              (focalPoint.dx - center.dx) / radius,
              (focalPoint.dy - center.dy) / radius,
            ),
            focalRadius: 0.08,
            radius: 0.98,
            colors: const [
              Color(0xFFFFFFFF), // 珠光高光原点
              Color(0xFFF7F9FB), // 洁白表面
              Color(0xFFE2E7ED), // 侧弧阴影
              Color(0xFFB8C2CC), // 边缘深陷沉淀
            ],
            stops: const [0.0, 0.28, 0.70, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: radius));

          canvas.drawCircle(center, radius, Paint()..shader = whiteShader);

          // 白子外轮廓柔光描边（代替粗硬黑线，高级温润）
          canvas.drawCircle(
            center,
            radius,
            Paint()
              ..color = palette.whiteStoneEdge
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(0.9, radius * 0.06),
          );

          // 白子饱满反光弧
          final specularCenter = Offset(center.dx - radius * 0.28, center.dy - radius * 0.30);
          canvas.drawOval(
            Rect.fromCenter(
              center: specularCenter,
              width: radius * 0.48,
              height: radius * 0.30,
            ),
            Paint()
              ..color = Colors.white.withValues(alpha: .7)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0),
          );
        }
      }
    }
  }

  /// 末手标记：在最新落子上绘制尊贵金色/珊瑚色光芒圆环与中心定位点。
  void _drawLastMoveMark(Canvas canvas, BoardGeometry geo, Point move) {
    final center = geo.toPixel(move.x, move.y);
    final isBlack = board.get(move.x, move.y) == Cell.black;
    final accentColor = isBlack ? const Color(0xFFFFCA28) : const Color(0xFFE65100);

    // 1. 外层光晕
    canvas.drawCircle(
      center,
      geo.cellSize * 0.26,
      Paint()
        ..color = accentColor.withValues(alpha: .4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // 2. 精致外环
    canvas.drawCircle(
      center,
      geo.cellSize * 0.22,
      Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.8, geo.cellSize / 18),
    );

    // 3. 中心圆点
    canvas.drawCircle(
      center,
      geo.cellSize * 0.06,
      Paint()..color = accentColor,
    );
  }

  /// AI 提示标记：灵动呼吸感准星圆盘，科技感与东方棋道结合。
  void _drawHintMark(Canvas canvas, BoardGeometry geo, Point point) {
    final center = geo.toPixel(point.x, point.y);
    final radius = geo.cellSize * 0.44;

    // 1. 外围呼吸光环
    canvas.drawCircle(
      center,
      radius * 0.88,
      Paint()
        ..color = palette.winLine.withValues(alpha: .25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // 2. 瞄准圆环
    canvas.drawCircle(
      center,
      radius * 0.65,
      Paint()
        ..color = palette.winLine
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.0, geo.cellSize / 14),
    );

    // 3. 核心准星亮斑
    canvas.drawCircle(
      center,
      radius * 0.18,
      Paint()..color = palette.winLine,
    );
  }

  /// 手数数字：清晰易读的序号标识，搭配文字背光阴影保证无论底色如何都清晰可辨。
  void _drawMoveNumbers(Canvas canvas, BoardGeometry geo) {
    if (moves.isEmpty) return;

    final fontSize = geo.cellSize * 0.44;
    for (var i = 0; i < moves.length; i++) {
      final move = moves[i];
      if (board.get(move.x, move.y) == Cell.empty) continue;

      final isBlackStone = board.get(move.x, move.y) == Cell.black;
      final textColor = isBlackStone ? const Color(0xFFFFFDE7) : const Color(0xFF14171A);

      final textPainter = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: TextStyle(
            color: textColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            fontFamily: 'Roboto',
            shadows: [
              Shadow(
                color: isBlackStone ? Colors.black : Colors.white.withValues(alpha: .8),
                blurRadius: 2,
              ),
            ],
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

  /// 胜利连线：光芒穿引，五子联珠黄金光晕。
  void _drawWinLine(Canvas canvas, BoardGeometry geo, List<Point> line) {
    if (line.isEmpty) return;

    final start = geo.toPixel(line.first.x, line.first.y);
    final end = geo.toPixel(line.last.x, line.last.y);

    // 1. 给五颗胜利棋子点亮黄金光环
    final haloPaint = Paint()
      ..color = const Color(0xFFFFD54F).withValues(alpha: .6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    for (final p in line) {
      canvas.drawCircle(geo.toPixel(p.x, p.y), geo.cellSize * 0.44, haloPaint);
    }

    // 2. 底层辉光粗线
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = const Color(0xFFFFB300).withValues(alpha: .5)
        ..strokeWidth = geo.cellSize * 0.32
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // 3. 核心亮金连线
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = const Color(0xFFFFF9C4)
        ..strokeWidth = math.max(3.5, geo.cellSize * 0.12)
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) {
    return oldDelegate.board != board ||
        oldDelegate.lastMove != lastMove ||
        oldDelegate.winLine != winLine ||
        oldDelegate.showMoveNumbers != showMoveNumbers ||
        oldDelegate.hint != hint ||
        oldDelegate.droppingStone != droppingStone ||
        oldDelegate.dropScale != dropScale ||
        oldDelegate.palette != palette;
  }
}
