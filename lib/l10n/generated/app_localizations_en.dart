// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Five';

  @override
  String get homeSubtitle => 'Gomoku · Five in a Row';

  @override
  String get localTwoPlayer => 'Two Player';

  @override
  String get localTwoPlayerDesc => 'Take turns on one device';

  @override
  String get vsAi => 'Play vs AI';

  @override
  String get chooseDifficulty => 'Choose AI difficulty';

  @override
  String get aiEasy => 'Easy';

  @override
  String get aiMedium => 'Medium';

  @override
  String get aiHard => 'Hard';

  @override
  String get aiThinking => 'AI is thinking…';

  @override
  String get youPlayFirst => 'You play black and move first';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get themeModeTitle => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get blackToMove => 'Black to move';

  @override
  String get whiteToMove => 'White to move';

  @override
  String moveCount(int count) {
    return '$count moves';
  }

  @override
  String get blackWins => 'Black wins!';

  @override
  String get whiteWins => 'White wins!';

  @override
  String get drawGame => 'Draw — board is full';

  @override
  String get undo => 'Undo';

  @override
  String get restart => 'Restart';

  @override
  String get backHome => 'Home';

  @override
  String get restartConfirmTitle => 'Restart game?';

  @override
  String get restartConfirmBody => 'The current game will be discarded.';

  @override
  String get confirm => 'Confirm';

  @override
  String get cancel => 'Cancel';
}
