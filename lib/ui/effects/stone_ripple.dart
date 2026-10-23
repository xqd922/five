/// 落子涟漪效果：在刚落下的棋子位置向外扩散一圈波纹。
///
/// 增强落子的触觉反馈感，让每一步都有"重量"。
library;

import 'package:flutter/material.dart';

/// 落子涟漪动画。
///
/// 在棋盘上层叠加一个从落子点向外扩散的圆环。
class StoneRipple extends StatefulWidget {
  final Offset center;
  final Color color;
  final double maxRadius;

  const StoneRipple({
    super.key,
    required this.center,
    required this.color,
    this.maxRadius = 30.0,
  });

  @override
  State<StoneRipple> createState() => _StoneRippleState();
}

class _StoneRippleState extends State<StoneRipple>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward().whenComplete(() {
        // 动画结束后自动移除。
        if (mounted) {
          // 通知父级移除此 widget（通过 setState 或回调）。
        }
      });
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
          painter: _RipplePainter(
            center: widget.center,
            color: widget.color,
            maxRadius: widget.maxRadius,
            progress: _controller.value,
          ),
        );
      },
    );
  }
}

class _RipplePainter extends CustomPainter {
  final Offset center;
  final Color color;
  final double maxRadius;
  final double progress;

  _RipplePainter({
    required this.center,
    required this.color,
    required this.maxRadius,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radius = maxRadius * progress;
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    // 外圈扩散环。
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: opacity * 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * (1.0 - progress * 0.5),
    );

    // 内圈（稍慢）。
    if (progress < 0.8) {
      final innerProgress = progress / 0.8;
      final innerRadius = maxRadius * 0.6 * innerProgress;
      final innerOpacity = (1.0 - innerProgress).clamp(0.0, 1.0);

      canvas.drawCircle(
        center,
        innerRadius,
        Paint()
          ..color = color.withValues(alpha: innerOpacity * 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
