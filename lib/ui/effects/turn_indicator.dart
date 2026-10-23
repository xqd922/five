/// 回合指示器动画：棋子旋转 + 颜色过渡 + 文案淡入。
///
/// 替代静态的黑白圆点 + 文字，让回合切换有视觉连续性。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 动画回合指示器。
///
/// [isBlack] 变化时自动播放过渡动画：
/// 棋子圆点旋转切换颜色，文字淡入淡出。
class AnimatedTurnIndicator extends StatefulWidget {
  final bool isBlack;
  final String text;
  final bool isThinking;
  final String? moveCountText;

  const AnimatedTurnIndicator({
    super.key,
    required this.isBlack,
    required this.text,
    this.isThinking = false,
    this.moveCountText,
  });

  @override
  State<AnimatedTurnIndicator> createState() => _AnimatedTurnIndicatorState();
}

class _AnimatedTurnIndicatorState extends State<AnimatedTurnIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _flipController;
  late final AnimationController _textController;
  late final AnimationController _thinkController;
  bool _prevIsBlack = true;

  @override
  void initState() {
    super.initState();
    _prevIsBlack = widget.isBlack;

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0, // 初始状态：完全可见
    );

    _thinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    if (widget.isThinking) {
      _thinkController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedTurnIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 回合切换：播放翻转动画。
    if (widget.isBlack != _prevIsBlack) {
      _prevIsBlack = widget.isBlack;
      _flipController.forward(from: 0);
      _textController.forward(from: 0);
    }

    // 思考状态变化。
    if (widget.isThinking != oldWidget.isThinking) {
      if (widget.isThinking) {
        _thinkController.repeat();
      } else {
        _thinkController.stop();
        _thinkController.reset();
      }
    }

    // 文案变化（非回合切换导致的，如"思考中"→"轮到你"）。
    if (widget.text != oldWidget.text && widget.isBlack == _prevIsBlack) {
      _textController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    _textController.dispose();
    _thinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 棋子指示器（带翻转动画）。
        AnimatedBuilder(
          animation: _flipController,
          builder: (context, child) {
            final angle = _flipController.value * math.pi;
            // 前半段：旧棋子翻转消失；后半段：新棋子翻转出现。
            final showNew = _flipController.value >= 0.5;
            final displayBlack = showNew ? widget.isBlack : _prevIsBlack;
            final scaleX = math.cos(angle).abs().clamp(0.01, 1.0);

            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..scaleByDouble(scaleX, 1.0, 1.0, 1.0),
              child: _StoneIndicator(
                isBlack: displayBlack,
                isThinking: widget.isThinking,
                thinkProgress: _thinkController.value,
              ),
            );
          },
        ),
        const SizedBox(width: 10),

        // 文案（淡入动画）。
        FadeTransition(
          opacity: CurvedAnimation(
            parent: _textController,
            curve: Curves.easeOut,
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.2),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: _textController,
              curve: Curves.easeOutCubic,
            )),
            child: Text(widget.text, style: theme.textTheme.titleMedium),
          ),
        ),

        // 思考指示器。
        if (widget.isThinking) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 14,
            height: 14,
            child: AnimatedBuilder(
              animation: _thinkController,
              builder: (context, _) {
                return CircularProgressIndicator(
                  strokeWidth: 2,
                  value: widget.isThinking ? null : 0,
                );
              },
            ),
          ),
        ],

        // 手数。
        if (widget.moveCountText != null) ...[
          const SizedBox(width: 10),
          Text(
            widget.moveCountText!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// 棋子圆点指示器（带阴影和呼吸效果）。
class _StoneIndicator extends StatelessWidget {
  final bool isBlack;
  final bool isThinking;
  final double thinkProgress;

  const _StoneIndicator({
    required this.isBlack,
    this.isThinking = false,
    this.thinkProgress = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 思考时的呼吸缩放。
    final breathe =
        isThinking ? (math.sin(thinkProgress * math.pi * 2) + 1) / 2 : 0.0;
    final scale = 1.0 + breathe * 0.12;

    return Transform.scale(
      scale: scale,
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isBlack ? Colors.black : Colors.white,
          border: Border.all(
            color: theme.colorScheme.outline,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2 + breathe * 0.1),
              blurRadius: 3 + breathe * 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}
