/// 终局庆祝特效：五彩纸屑粒子 + 光晕扩散。
///
/// 胜利时从棋盘中心爆发粒子，平局则显示温和的光晕涟漪。
/// 使用 CustomPainter + AnimationController 驱动，不依赖第三方库。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 纸屑粒子。
class _Particle {
  double x, y; // 当前位置（归一化坐标 0..1）
  double vx, vy; // 速度
  double rotation; // 当前旋转角
  double rotationSpeed; // 旋转速度
  double size; // 尺寸
  Color color; // 颜色
  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.rotation,
    required this.rotationSpeed,
    required this.size,
    required this.color,
  });
}

/// 庆祝特效控制器。
///
/// 用法：在终局时调用 [start]，组件会自动播放特效。
class VictoryCelebration extends StatefulWidget {
  final Widget child;

  /// 是否为胜利（true=纸屑爆发，false=平局涟漪）。
  final bool isWin;

  /// 胜利方颜色（纸屑主色调）。
  final Color? winnerColor;

  const VictoryCelebration({
    super.key,
    required this.child,
    required this.isWin,
    this.winnerColor,
  });

  @override
  State<VictoryCelebration> createState() => _VictoryCelebrationState();
}

class _VictoryCelebrationState extends State<VictoryCelebration>
    with TickerProviderStateMixin {
  late final AnimationController _particleController;
  late final AnimationController _rippleController;
  late final AnimationController _scaleController;
  final List<_Particle> _particles = [];
  final _random = math.Random();

  @override
  void initState() {
    super.initState();

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      upperBound: 1.0,
    );

    _generateParticles();
    _particleController.forward();
    _rippleController.forward();
    _scaleController.forward();
  }

  void _generateParticles() {
    _particles.clear();
    final count = widget.isWin ? 60 : 20;
    final baseColor = widget.winnerColor ?? const Color(0xFFFFD700);

    // 调色板：主色 + 邻近色 + 白色点缀。
    final palette = [
      baseColor,
      HSLColor.fromColor(baseColor)
          .withHue((HSLColor.fromColor(baseColor).hue + 30) % 360)
          .toColor(),
      HSLColor.fromColor(baseColor)
          .withHue((HSLColor.fromColor(baseColor).hue + 60) % 360)
          .toColor(),
      HSLColor.fromColor(baseColor)
          .withSaturation(
              (HSLColor.fromColor(baseColor).saturation - 0.3).clamp(0, 1))
          .toColor(),
      Colors.white,
    ];

    for (var i = 0; i < count; i++) {
      final angle = _random.nextDouble() * math.pi * 2;
      final speed = 0.3 + _random.nextDouble() * 0.7;

      _particles.add(_Particle(
        x: 0.5,
        y: 0.5,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed - 0.3, // 略微向上偏移
        rotation: _random.nextDouble() * math.pi * 2,
        rotationSpeed: (_random.nextDouble() - 0.5) * 8,
        size: 3 + _random.nextDouble() * 5,
        color: palette[_random.nextInt(palette.length)],
      ));
    }
  }

  @override
  void dispose() {
    _particleController.dispose();
    _rippleController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // 粒子层
        AnimatedBuilder(
          animation: _particleController,
          builder: (context, _) {
            return CustomPaint(
              size: Size.infinite,
              painter: _ParticlePainter(
                particles: _particles,
                progress: _particleController.value,
                isWin: widget.isWin,
              ),
            );
          },
        ),
        // 涟漪层（平局时更明显）
        if (!widget.isWin)
          AnimatedBuilder(
            animation: _rippleController,
            builder: (context, _) {
              return CustomPaint(
                size: Size.infinite,
                painter: _RipplePainter(
                  progress: _rippleController.value,
                  color: widget.winnerColor ?? Colors.blueGrey,
                ),
              );
            },
          ),
      ],
    );
  }
}

/// 纸屑粒子画笔。
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final bool isWin;

  _ParticlePainter({
    required this.particles,
    required this.progress,
    required this.isWin,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isWin) return; // 平局不画纸屑

    for (final p in particles) {
      final t = progress;
      // 抛物线运动 + 重力下坠。
      final gravity = 0.8 * t * t;
      final px = (p.x + p.vx * t) * size.width;
      final py = (p.y + p.vy * t + gravity) * size.height;
      final opacity = (1.0 - t).clamp(0.0, 1.0);
      final scale = (1.0 - t * 0.5).clamp(0.0, 1.0);

      if (opacity <= 0) continue;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(p.rotation + p.rotationSpeed * t);
      canvas.scale(scale);

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      // 不同形状：圆形 / 方形 / 三角形。
      final shapeType = p.hashCode % 3;
      switch (shapeType) {
        case 0:
          canvas.drawCircle(Offset.zero, p.size, paint);
          break;
        case 1:
          canvas.drawRect(
            Rect.fromCenter(
                center: Offset.zero, width: p.size * 1.5, height: p.size),
            paint,
          );
          break;
        case 2:
          final path = Path()
            ..moveTo(0, -p.size)
            ..lineTo(-p.size * 0.866, p.size * 0.5)
            ..lineTo(p.size * 0.866, p.size * 0.5)
            ..close();
          canvas.drawPath(path, paint);
          break;
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// 涟漪画笔。
class _RipplePainter extends CustomPainter {
  final double progress;
  final Color color;

  _RipplePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.shortestSide * 0.6;

    for (var i = 0; i < 3; i++) {
      final delay = i * 0.15;
      final t = (progress - delay).clamp(0.0, 1.0);
      if (t <= 0) continue;

      final radius = maxRadius * t;
      final opacity = (1.0 - t).clamp(0.0, 1.0) * 0.3;

      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
