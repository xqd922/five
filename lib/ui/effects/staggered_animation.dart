/// 交错入场动画：列表中的元素依次出现，形成"瀑布"效果。
///
/// 用于首页模式卡片、设置项等列表内容的首次展示。
library;

import 'package:flutter/material.dart';

/// 交错入场动画包装器。
///
/// 将子元素按 [index] 顺序依次淡入 + 上移。
/// 每个元素延迟 [delay] × [index] 开始动画。
class StaggeredEntry extends StatefulWidget {
  final int index;
  final Duration delay;
  final Duration duration;
  final Offset offset;
  final Widget child;

  const StaggeredEntry({
    super.key,
    this.index = 0,
    this.delay = const Duration(milliseconds: 80),
    this.duration = const Duration(milliseconds: 500),
    this.offset = const Offset(0, 20),
    required this.child,
  });

  @override
  State<StaggeredEntry> createState() => _StaggeredEntryState();
}

class _StaggeredEntryState extends State<StaggeredEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    // 按 index 延迟启动。
    Future.delayed(widget.delay * widget.index, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

/// 缩放入场动画（适合按钮、图标等独立元素）。
class ScaleEntry extends StatefulWidget {
  final Duration delay;
  final Duration duration;
  final Widget child;

  const ScaleEntry({
    super.key,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 400),
    required this.child,
  });

  @override
  State<ScaleEntry> createState() => _ScaleEntryState();
}

class _ScaleEntryState extends State<ScaleEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack, // 弹性效果
    ));

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
