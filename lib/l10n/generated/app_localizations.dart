import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// App name shown on the home screen and window title
  ///
  /// In en, this message translates to:
  /// **'Five'**
  String get appTitle;

  /// Tagline under the app title on the home screen
  ///
  /// In en, this message translates to:
  /// **'Gomoku · Five in a Row'**
  String get homeSubtitle;

  /// Local two-player (hot-seat) mode entry
  ///
  /// In en, this message translates to:
  /// **'Two Player'**
  String get localTwoPlayer;

  /// No description provided for @localTwoPlayerDesc.
  ///
  /// In en, this message translates to:
  /// **'Take turns on one device'**
  String get localTwoPlayerDesc;

  /// AI opponent mode entry
  ///
  /// In en, this message translates to:
  /// **'Play vs AI'**
  String get vsAi;

  /// No description provided for @chooseDifficulty.
  ///
  /// In en, this message translates to:
  /// **'Choose AI difficulty'**
  String get chooseDifficulty;

  /// No description provided for @aiEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get aiEasy;

  /// No description provided for @aiMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get aiMedium;

  /// No description provided for @aiHard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get aiHard;

  /// No description provided for @aiThinking.
  ///
  /// In en, this message translates to:
  /// **'AI is thinking…'**
  String get aiThinking;

  /// No description provided for @youPlayFirst.
  ///
  /// In en, this message translates to:
  /// **'You play black and move first'**
  String get youPlayFirst;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Section label for light/dark theme selection
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeModeTitle;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// Status line during a game
  ///
  /// In en, this message translates to:
  /// **'Black to move'**
  String get blackToMove;

  /// No description provided for @whiteToMove.
  ///
  /// In en, this message translates to:
  /// **'White to move'**
  String get whiteToMove;

  /// No description provided for @moveCount.
  ///
  /// In en, this message translates to:
  /// **'{count} moves'**
  String moveCount(int count);

  /// No description provided for @blackWins.
  ///
  /// In en, this message translates to:
  /// **'Black wins!'**
  String get blackWins;

  /// No description provided for @whiteWins.
  ///
  /// In en, this message translates to:
  /// **'White wins!'**
  String get whiteWins;

  /// No description provided for @drawGame.
  ///
  /// In en, this message translates to:
  /// **'Draw — board is full'**
  String get drawGame;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @restart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get restart;

  /// No description provided for @backHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get backHome;

  /// No description provided for @restartConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Restart game?'**
  String get restartConfirmTitle;

  /// No description provided for @restartConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The current game will be discarded.'**
  String get restartConfirmBody;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
