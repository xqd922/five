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
  String get onlineMode => 'Online';

  @override
  String get createRoom => 'Create Room';

  @override
  String get joinRoom => 'Join Room';

  @override
  String get roomCodeLabel => 'Room code';

  @override
  String get waitingOpponent => 'Waiting for opponent…';

  @override
  String get youPlayBlack => 'You play black (first)';

  @override
  String get youPlayWhite => 'You play white';

  @override
  String get opponentLeft => 'Opponent disconnected, waiting…';

  @override
  String get opponentBack => 'Opponent reconnected';

  @override
  String get resign => 'Resign';

  @override
  String get rematch => 'Rematch';

  @override
  String get waitingRematchReply => 'Rematch invited, waiting…';

  @override
  String get opponentWantsRematch => 'Opponent wants a rematch!';

  @override
  String get serverAddress => 'Game server';

  @override
  String get connectionLost => 'Disconnected';

  @override
  String get reconnectBtn => 'Reconnect';

  @override
  String get copyRoomCode => 'Copy room code';

  @override
  String get roomCodeCopied => 'Room code copied';

  @override
  String get backToLobby => 'Back to lobby';

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
  String get statsTitle => 'Record vs AI';

  @override
  String get statsWins => 'W';

  @override
  String get statsLosses => 'L';

  @override
  String get statsDraws => 'D';

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
  String get hint => 'Hint';

  @override
  String get exportSgf => 'Export SGF';

  @override
  String get sgfSaved => 'Game record saved';

  @override
  String get exportFailed => 'Failed to save file';

  @override
  String get showMoveNumbers => 'Move numbers';

  @override
  String replayPosition(int index, int total) {
    return '$index/$total';
  }

  @override
  String get restartConfirmTitle => 'Restart game?';

  @override
  String get restartConfirmBody => 'The current game will be discarded.';

  @override
  String get confirm => 'Confirm';

  @override
  String get cancel => 'Cancel';
}
