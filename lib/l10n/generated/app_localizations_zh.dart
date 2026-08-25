// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Five';

  @override
  String get homeSubtitle => '五子棋 · 无禁手';

  @override
  String get localTwoPlayer => '双人对战';

  @override
  String get localTwoPlayerDesc => '同一台设备轮流执子';

  @override
  String get vsAi => '人机对战';

  @override
  String get chooseDifficulty => '选择 AI 难度';

  @override
  String get aiEasy => '入门';

  @override
  String get aiMedium => '进阶';

  @override
  String get aiHard => '大师';

  @override
  String get aiThinking => 'AI 思考中…';

  @override
  String get youPlayFirst => '你执黑先行';

  @override
  String get settingsTitle => '设置';

  @override
  String get themeModeTitle => '主题';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get blackToMove => '黑方行棋';

  @override
  String get whiteToMove => '白方行棋';

  @override
  String moveCount(int count) {
    return '第 $count 手';
  }

  @override
  String get blackWins => '黑方获胜！';

  @override
  String get whiteWins => '白方获胜！';

  @override
  String get drawGame => '平局 — 棋盘已满';

  @override
  String get undo => '悔棋';

  @override
  String get restart => '重新开始';

  @override
  String get backHome => '主页';

  @override
  String get restartConfirmTitle => '重新开始？';

  @override
  String get restartConfirmBody => '当前对局将被丢弃。';

  @override
  String get confirm => '确定';

  @override
  String get cancel => '取消';
}
