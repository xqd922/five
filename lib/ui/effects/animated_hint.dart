/// AI 提示的脉冲发光动画。
///
/// 当 AI 推荐一个落点时，该位置显示一个呼吸式发光标记，
/// 比静态的半透明圆盘更吸引注意力。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 脉冲提示标记 Widget。
///
/// 覆盖在棋盘上层，对齐到指定格子的像素坐标。
class AnimatedHintMarker extends StatefulWidget {
  final Offset center;
  final double cellSize;
  final Color color;

  const AnimatedHintMarker({
    super.key,
    required this.center,
    required this.cellSize,
    required this.color,
  });

  @override
  State<AnimatedHintMarker> createState() => _AnimatedHintMarkerState();
}

class _AnimatedHintMarkerState extends State<AnimatedHintMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
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
          painter: _HintPainter(
            center: widget.center,
            cellSize: widget.cellSize,
            color: widget.color,
            progress: _controller.value,
          ),
        );
      },
    );
  }
}

class _HintPainter extends CustomPainter {
  final Offset center;
  final double cellSize;
  final Color color;
  final double progress;

  _HintPainter({
    required this.center,
    required this.cellSize,
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final baseRadius = cellSize * 0.44;

    // 呼吸效果：半径和透明度周期性变化。
    final breathe = (math.sin(progress * math.pi * 2) + 1) / 2; // 0..1
    final radius = baseRadius * (0.85 + 0.15 * breathe);
    final opacity = 0.15 + 0.15 * breathe;

    // 外层光晕（大、模糊）。
    canvas.drawCircle(
      center,
      radius * 1.6,
      Paint()
        ..color = color.withValues(alpha: opacity * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // 中层半透明填充。
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = color.withValues(alpha: opacity),
    );

    // 内层描边环。
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.4 + 0.3 * breathe)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cellSize / 12,
    );

    // 中心小圆点（引导视线）。
    canvas.drawCircle(
      center,
      cellSize * 0.08,
      Paint()..color = color.withValues(alpha: 0.6 + 0.3 * breathe),
    );

    // 扫描射线（从中心向外的四条短线，旋转）。
    final rayAngle = progress * math.pi * 2;
    final rayPaint = Paint()
      ..color = color.withValues(alpha: 0.2 * breathe)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 4; i++) {
      final angle = rayAngle + i * math.pi / 2;
      final innerR = radius * 1.1;
      final outerR = radius * 1.5;
      canvas.drawLine(
        center + Offset(math.cos(angle) * innerR, math.sin(angle) * innerR),
        center + Offset(math.cos(angle) * outerR, math.sin(angle) * outerR),
        rayPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HintPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
