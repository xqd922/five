/// 玩法偏好设置：手数标记等开关，全部持久化到本地。
///
/// 与 theme_provider 分开的原因：主题是「外观」，这里是「棋盘信息密度」。
/// 未来加入的音效、动画速度等玩法相关开关统一放本文件，
/// 避免单文件无限膨胀——每个 provider 一个清晰的职责边界。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:five/state/theme_provider.dart'; // 复用 sharedPreferencesProvider

const String _moveNumbersKey = 'five.show_move_numbers';

/// 棋盘风格：经典榧木 / 水墨玄石 / 苍青碧玉。
enum BoardStyle {
  wood, // 经典榧木 (暖金榧木纹理与棋盘)
  zen,  // 水墨玄石 (静谧雅致的玄武岩 / 墨玉盘)
  jade, // 苍青碧玉 (现代青瓷翡翠风，呼应主色)
}

const String _boardStyleKey = 'five.board_style';

final boardStyleProvider =
    NotifierProvider<BoardStyleController, BoardStyle>(BoardStyleController.new);

class BoardStyleController extends Notifier<BoardStyle> {
  @override
  BoardStyle build() {
    final saved = ref.watch(sharedPreferencesProvider).getString(_boardStyleKey);
    return switch (saved) {
      'zen' => BoardStyle.zen,
      'jade' => BoardStyle.jade,
      _ => BoardStyle.wood,
    };
  }

  Future<void> set(BoardStyle style) async {
    state = style;
    await ref.read(sharedPreferencesProvider).setString(_boardStyleKey, style.name);
  }
}

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

const String _serverUrlKey = 'five.server_url';

/// 在线对战服务器地址。默认指向本机开发环境；
/// 部署后用户可改成自己的服务器。
final serverUrlProvider =
    NotifierProvider<ServerUrlController, String>(ServerUrlController.new);

class ServerUrlController extends Notifier<String> {
  /// 默认地址：本机调试端口。
  static const String defaultUrl = 'ws://localhost:8080';

  @override
  String build() =>
      ref.watch(sharedPreferencesProvider).getString(_serverUrlKey) ??
      defaultUrl;

  Future<void> set(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    state = trimmed;
    await ref.read(sharedPreferencesProvider).setString(_serverUrlKey, trimmed);
  }
}
