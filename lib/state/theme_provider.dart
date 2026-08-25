/// 主题模式偏好：跟随系统 / 浅色 / 深色，并持久化到本地。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences 的注入点。
///
/// 【为什么用 Provider 而不是直接在控制器里 await】
/// SharedPreferences 实例需要在 main() 里异步获取，
/// 通过 provider 覆写（overrideWithValue）注入进来，
/// 控制器代码就能同步地拿到它，也不用在测试里摸真实磁盘。
/// main() 之前没人读它，所以默认实现直接抛错兜底。
final sharedPreferencesProvider = Provider<SharedPreferences>(
    (ref) => throw UnimplementedError('必须在 main() 中 override'));

/// 偏好存储的 key。加前缀避免未来与其他设置项撞名。
const String _themeKey = 'five.theme_mode';

final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    // 读不到或值非法时回退到「跟随系统」——首次启动的正常路径。
    final saved = ref.watch(sharedPreferencesProvider).getString(_themeKey);
    return switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  /// 切换主题并立刻写入本地，下次启动自动恢复。
  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref
        .read(sharedPreferencesProvider)
        .setString(_themeKey, mode.name); // 'system' / 'light' / 'dark'
  }
}
