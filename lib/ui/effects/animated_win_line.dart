/// 胜利连线动画：从第一颗子到最后一颗子逐步画出高亮线。
///
/// 像一笔「签收」般扫过五颗胜利棋子，配合光晕扩散效果。
library;

import 'package:flutter/material.dart';

/// 胜利连线动画 Widget。
///
/// 包裹在棋盘上层，透明度不影响底层绘制。
/// [linePoints] 是像素坐标列表（由 BoardGeometry 转换后的）。
/// [color] 是连线主色。
class AnimatedWinLine extends StatefulWidget {
  final List<Offset> linePoints;
  final Color color;
  final double strokeWidth;

  const AnimatedWinLine({
    super.key,
    required this.linePoints,
    required this.color,
    this.strokeWidth = 8.0,
  });

  @override
  State<AnimatedWinLine> createState() => _AnimatedWinLineState();
}

class _AnimatedWinLineState extends State<AnimatedWinLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;
  late final Animation<double> _glowIntensity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // 线条生长：先快后慢。
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    // 光晕：线条画完后闪一下再淡出。
    _glowIntensity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.5), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.5, end: 0.8), weight: 40),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size.infinite,
          painter: _WinLinePainter(
            points: widget.linePoints,
            color: widget.color,
            strokeWidth: widget.strokeWidth,
            progress: _progress.value,
            glowIntensity: _glowIntensity.value,
          ),
        );
      },
    );
  }
}

/// 胜利连线画笔。
class _WinLinePainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final double progress; // 0..1 线条生长进度
  final double glowIntensity; // 光晕强度

  _WinLinePainter({
    required this.points,
    required this.color,
    required this.strokeWidth,
    required this.progress,
    required this.glowIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    // 计算总路径长度。
    double totalLength = 0;
    for (var i = 1; i < points.length; i++) {
      totalLength += (points[i] - points[i - 1]).distance;
    }

    final targetLength = totalLength * progress;

    // 构建路径，按进度截断。
    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    double accumulated = 0;
    for (var i = 1; i < points.length; i++) {
      final segLen = (points[i] - points[i - 1]).distance;
      if (accumulated + segLen <= targetLength) {
        path.lineTo(points[i].dx, points[i].dy);
        accumulated += segLen;
      } else {
        // 在段中间截断。
        final remaining = targetLength - accumulated;
        final t = remaining / segLen;
        final dx = points[i - 1].dx + (points[i].dx - points[i - 1].dx) * t;
        final dy = points[i - 1].dy + (points[i].dy - points[i - 1].dy) * t;
        path.lineTo(dx, dy);
        break;
      }
    }

    // 光晕层（宽、半透明）。
    if (glowIntensity > 0.1) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.25 * glowIntensity)
          ..strokeWidth = strokeWidth * 3
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, strokeWidth),
      );
    }

    // 主线。
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    // 亮点：线头位置的发光圆。
    if (progress > 0 && progress < 1) {
      final headPos = _getPointAtLength(points, targetLength);
      canvas.drawCircle(
        headPos,
        strokeWidth * 1.5,
        Paint()
          ..color = color.withValues(alpha: 0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    // 终点标记：画完后在两端画圆点。
    if (progress >= 0.99) {
      final endpointPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(points.first, strokeWidth * 0.8, endpointPaint);
      canvas.drawCircle(points.last, strokeWidth * 0.8, endpointPaint);
    }
  }

  /// 获取路径上距起点指定长度处的坐标。
  Offset _getPointAtLength(List<Offset> pts, double targetLen) {
    double acc = 0;
    for (var i = 1; i < pts.length; i++) {
      final segLen = (pts[i] - pts[i - 1]).distance;
      if (acc + segLen >= targetLen) {
        final t = (targetLen - acc) / segLen;
        return Offset(
          pts[i - 1].dx + (pts[i].dx - pts[i - 1].dx) * t,
          pts[i - 1].dy + (pts[i].dy - pts[i - 1].dy) * t,
        );
      }
      acc += segLen;
    }
    return pts.last;
  }

  @override
  bool shouldRepaint(covariant _WinLinePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.glowIntensity != glowIntensity;
}
