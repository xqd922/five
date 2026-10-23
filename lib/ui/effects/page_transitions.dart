/// 自定义页面过渡动画。
///
/// 提供三种现代风格的路由切换效果：
/// - [slideUp]：从底部滑入（适合进入对局页）；
/// - [fadeScale]：缩放淡入（适合弹出对话框级别的页面）；
/// - [sharedAxis]：共享轴横向滑动（适合同层级页面切换）。
library;

import 'package:flutter/material.dart';

/// 从底部滑入的页面过渡。
///
/// 新页面从屏幕下方滑入，同时旧页面微微上移并淡出。
/// 比默认的 MaterialPageRoute 更有层次感。
class SlideUpRoute<T> extends PageRouteBuilder<T> {
  SlideUpRoute({required WidgetBuilder builder, super.settings})
      : super(
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // 新页面：从下往上滑入 + 淡入。
            final slideAnimation = Tween<Offset>(
              begin: const Offset(0, 0.15),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));

            final fadeAnimation = Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
            ));

            // 旧页面：微微上移 + 淡出。
            final secondarySlide = Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(0, -0.05),
            ).animate(CurvedAnimation(
              parent: secondaryAnimation,
              curve: Curves.easeOutCubic,
            ));

            final secondaryFade = Tween<double>(
              begin: 1.0,
              end: 0.3,
            ).animate(CurvedAnimation(
              parent: secondaryAnimation,
              curve: Curves.easeOut,
            ));

            return SlideTransition(
              position: secondarySlide,
              child: FadeTransition(
                opacity: secondaryFade,
                child: SlideTransition(
                  position: slideAnimation,
                  child: FadeTransition(
                    opacity: fadeAnimation,
                    child: child,
                  ),
                ),
              ),
            );
          },
        );
}

/// 缩放淡入的页面过渡。
///
/// 新页面从 90% 缩放 + 全透明渐变到 100% + 不透明。
/// 适合轻量级的详情页或对话。
class FadeScaleRoute<T> extends PageRouteBuilder<T> {
  FadeScaleRoute({required WidgetBuilder builder, super.settings})
      : super(
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final scaleAnimation = Tween<double>(
              begin: 0.92,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));

            final fadeAnimation = Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ));

            return FadeTransition(
              opacity: fadeAnimation,
              child: ScaleTransition(
                scale: scaleAnimation,
                child: child,
              ),
            );
          },
        );
}

/// 共享轴横向滑动过渡。
///
/// 新页面从右侧滑入，旧页面向左滑出。
/// 适合同层级的页面切换（如大厅 → 设置）。
class SharedAxisRoute<T> extends PageRouteBuilder<T> {
  final bool forward;

  SharedAxisRoute({
    required WidgetBuilder builder,
    this.forward = true,
    super.settings,
  }) : super(
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final begin = forward ? const Offset(0.3, 0) : const Offset(-0.3, 0);
            final end = Offset.zero;
            final reverseBegin = Offset.zero;
            final reverseEnd =
                forward ? const Offset(-0.15, 0) : const Offset(0.15, 0);

            final slideAnimation = Tween<Offset>(
              begin: begin,
              end: end,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));

            final secondarySlide = Tween<Offset>(
              begin: reverseBegin,
              end: reverseEnd,
            ).animate(CurvedAnimation(
              parent: secondaryAnimation,
              curve: Curves.easeOutCubic,
            ));

            final fadeAnimation = Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
            ));

            final secondaryFade = Tween<double>(
              begin: 1.0,
              end: 0.0,
            ).animate(CurvedAnimation(
              parent: secondaryAnimation,
              curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
            ));

            return SlideTransition(
              position: secondarySlide,
              child: FadeTransition(
                opacity: secondaryFade,
                child: SlideTransition(
                  position: slideAnimation,
                  child: FadeTransition(
                    opacity: fadeAnimation,
                    child: child,
                  ),
                ),
              ),
            );
          },
        );
}
