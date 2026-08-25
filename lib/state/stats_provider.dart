/// 人机对战战绩统计（纯本地持久化）。
///
/// 只统计「人机模式」——双人对战的黑白胜负没有"我的战绩"语义；
/// 联机胜负属于对手的战绩，同样不进这份账本。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:five/state/theme_provider.dart'; // 复用 prefs 注入

/// 一份战绩快照。
class StatsData {
  final int wins;
  final int losses;
  final int draws;

  const StatsData({this.wins = 0, this.losses = 0, this.draws = 0});

  int get total => wins + losses + draws;
}

const String _winsKey = 'five.stats.ai.wins';
const String _lossesKey = 'five.stats.ai.losses';
const String _drawsKey = 'five.stats.ai.draws';

final statsProvider =
    NotifierProvider<StatsController, StatsData>(StatsController.new);

class StatsController extends Notifier<StatsData> {
  @override
  StatsData build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return StatsData(
      wins: prefs.getInt(_winsKey) ?? 0,
      losses: prefs.getInt(_lossesKey) ?? 0,
      draws: prefs.getInt(_drawsKey) ?? 0,
    );
  }

  /// 记录一局结果（human 视角）。终局时由 GameController 调用。
  Future<void> record({required bool? humanWon}) async {
    // humanWon: true=人赢 false=AI赢 null=平局
    final prefs = ref.read(sharedPreferencesProvider);
    if (humanWon == true) {
      await prefs.setInt(_winsKey, (prefs.getInt(_winsKey) ?? 0) + 1);
    } else if (humanWon == false) {
      await prefs.setInt(_lossesKey, (prefs.getInt(_lossesKey) ?? 0) + 1);
    } else {
      await prefs.setInt(_drawsKey, (prefs.getInt(_drawsKey) ?? 0) + 1);
    }
    state = build(); // 从存储重读，保证与磁盘一致
  }

  /// 清零战绩（设置里的隐藏操作，暂不暴露 UI）。
  Future<void> reset() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(_winsKey, 0);
    await prefs.setInt(_lossesKey, 0);
    await prefs.setInt(_drawsKey, 0);
    state = build();
  }
}
