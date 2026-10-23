/// 现代化加载动画：三个弹跳圆点 + 可选文案。
///
/// 替代默认的 CircularProgressIndicator，更有活力感。
/// 支持两种风格：弹跳圆点（AI 思考中）和涟漪扩散（连接中）。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 弹跳圆点加载器。
///
/// 三个圆依次弹跳，相位错开形成波浪效果。
/// [color] 默认取主题主色。
/// [size] 控制单个圆点的直径。
class BouncingDotsLoader extends StatefulWidget {
  final Color? color;
  final double size;
  final String? label;

  const BouncingDotsLoader({
    super.key,
    this.color,
    this.size = 8.0,
    this.label,
  });

  @override
  State<BouncingDotsLoader> createState() => _BouncingDotsLoaderState();
}

class _BouncingDotsLoaderState extends State<BouncingDotsLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) SizedBox(width: widget.size * 0.6),
              _buildDot(i, color),
            ],
            if (widget.label != null) ...[
              const SizedBox(width: 10),
              Text(
                widget.label!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDot(int index, Color color) {
    // 每个圆点相位错开 0.15。
    final t = (_controller.value + index * 0.15) % 1.0;

    // 弹跳曲线：先上后下。
    final bounce = math.sin(t * math.pi);
    final yOffset = -bounce * widget.size * 1.5;

    // 缩放：弹起时略大，落下时略小。
    final scale = 1.0 + bounce * 0.2;

    // 透明度：高点最亮。
    final opacity = 0.4 + bounce * 0.6;

    return Transform.translate(
      offset: Offset(0, yOffset),
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: color.withValues(alpha: opacity),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// 涟漪加载器（连接等待时使用）。
///
/// 从中心向外扩散的同心圆环，有呼吸感。
class RippleLoader extends StatefulWidget {
  final Color? color;
  final double size;

  const RippleLoader({
    super.key,
    this.color,
    this.size = 40.0,
  });

  @override
  State<RippleLoader> createState() => _RippleLoaderState();
}

class _RippleLoaderState extends State<RippleLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _RipplePainter(
            progress: _controller.value,
            color: color,
          ),
        );
      },
    );
  }
}

class _RipplePainter extends CustomPainter {
  final double progress;
  final Color color;

  _RipplePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.shortestSide / 2;

    for (var i = 0; i < 3; i++) {
      final t = (progress + i * 0.33) % 1.0;
      final radius = maxRadius * t;
      final opacity = (1.0 - t).clamp(0.0, 1.0);

      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: opacity * 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }

    // 中心小圆（呼吸效果）。
    final breathe = (math.sin(progress * math.pi * 2) + 1) / 2;
    final centerRadius = maxRadius * 0.15 + maxRadius * 0.1 * breathe;
    canvas.drawCircle(
      center,
      centerRadius,
      Paint()..color = color.withValues(alpha: 0.3 + 0.3 * breathe),
    );
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// 脉冲光环加载器（AI 深度思考时使用）。
///
/// 中心棋子图案 + 向外脉冲的光环，暗示"正在计算"。
class PulseRingLoader extends StatefulWidget {
  final Color? color;
  final double size;

  const PulseRingLoader({
    super.key,
    this.color,
    this.size = 48.0,
  });

  @override
  State<PulseRingLoader> createState() => _PulseRingLoaderState();
}

class _PulseRingLoaderState extends State<PulseRingLoader>
    with TickerProviderStateMixin {
  late final AnimationController _ringController;
  late final AnimationController _rotateController;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _ringController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;

    return AnimatedBuilder(
      animation: Listenable.merge([_ringController, _rotateController]),
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _PulseRingPainter(
            ringProgress: _ringController.value,
            rotateProgress: _rotateController.value,
            color: color,
          ),
        );
      },
    );
  }
}

class _PulseRingPainter extends CustomPainter {
  final double ringProgress;
  final double rotateProgress;
  final Color color;

  _PulseRingPainter({
    required this.ringProgress,
    required this.rotateProgress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;

    // 旋转的弧线。
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotateProgress * math.pi * 2);

    final arcPaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: radius * 0.7),
      0,
      math.pi * 1.2,
      false,
      arcPaint,
    );

    canvas.restore();

    // 脉冲环。
    final pulseT = ringProgress;
    final pulseRadius = radius * 0.4 + radius * 0.6 * pulseT;
    final pulseOpacity = (1.0 - pulseT).clamp(0.0, 1.0) * 0.4;

    canvas.drawCircle(
      center,
      pulseRadius,
      Paint()
        ..color = color.withValues(alpha: pulseOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // 中心圆点。
    canvas.drawCircle(
      center,
      radius * 0.2,
      Paint()..color = color.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(covariant _PulseRingPainter oldDelegate) =>
      oldDelegate.ringProgress != ringProgress ||
      oldDelegate.rotateProgress != rotateProgress;
}
