/// 玩法偏好设置：手数标记等开关，全部持久化到本地。
///
/// 与 theme_provider 分开的原因：主题是「外观」，这里是「棋盘信息密度」。
/// 未来加入的音效、动画速度等玩法相关开关统一放本文件，
/// 避免单文件无限膨胀——每个 provider 一个清晰的职责边界。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:five/state/theme_provider.dart'; // 复用 sharedPreferencesProvider

const String _moveNumbersKey = 'five.show_move_numbers';

/// 是否在棋子上显示落子顺序数字（复盘利器，默认关闭保持棋面干净）。
final showMoveNumbersProvider =
    NotifierProvider<ShowMoveNumbersController, bool>(
        ShowMoveNumbersController.new);

class ShowMoveNumbersController extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(_moveNumbersKey) ?? false;

  Future<void> set(bool value) async {
    state = value;
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_moveNumbersKey, value);
  }
}
