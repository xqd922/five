/// AI 对外服务门面：难度定义 + Isolate 异步调度。
///
/// 【为什么要有这一层】搜索引擎本身是同步阻塞的纯计算；
/// UI 需要的是「给我一个 Future，别卡我的帧」。
/// 这一层负责翻译两件事：
/// 1. 把难度档位翻译成搜索参数；
/// 2. 把计算丢进 Isolate，主线程零负担。
library;

import 'dart:isolate';

import 'package:five/core/board.dart';
import 'package:five/core/rules.dart';

import 'package:five/engine/search.dart';

/// AI 难度档位。
///
/// 强度由「搜索深度 × 时间预算」共同决定：
/// 深度是上限，时间是保险丝——迭代加深会在两者中先到的那个停下。
enum AiLevel {
  /// 入门：浅搜索，反应快，适合完全新手。
  easy,

  /// 进阶：完整棋型评估 + 中等深度。
  medium,

  /// 大师：深搜索 + 宽时间预算，当前引擎的全力形态。
  hard,
}

extension AiLevelConfig on AiLevel {
  /// 迭代加深的最大深度。
  int get maxDepth => switch (this) {
        AiLevel.easy => 2,
        AiLevel.medium => 4,
        AiLevel.hard => 6,
      };

  /// 单次思考的时间预算（超时立即返回已得最好结果）。
  Duration get timeBudget => switch (this) {
        AiLevel.easy => const Duration(milliseconds: 400),
        AiLevel.medium => const Duration(seconds: 2),
        AiLevel.hard => const Duration(seconds: 5),
      };
}

class AiService {
  AiService._();

  /// 在后台 Isolate 中为 [stone] 计算最佳着法。
  ///
  /// 传入前先 [Board.copy] 一份快照——虽然 Isolate.run 发送消息时
  /// 本身就会深拷贝闭包捕获的对象，显式拷贝让所有权语义一目了然，
  /// 也避免未来实现变化时的隐式共享风险。
  ///
  /// 主线程在整个计算期间完全自由，可以继续渲染、响应输入。
  static Future<Point> findBestMove(
    Board board,
    int stone,
    AiLevel level,
  ) async {
    final snapshot = board.copy();
    return Isolate.run(() {
      final result = SearchEngine().findBestMove(
        snapshot,
        stone,
        maxDepth: level.maxDepth,
        timeBudget: level.timeBudget,
      );
      return result.move;
    });
  }
}
