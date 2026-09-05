import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// The name of the app, shown in the task switcher and as the wordmark on the home screen. A brand name: leave it untranslated.
  ///
  /// In en, this message translates to:
  /// **'Nook'**
  String get appTitle;

  /// Heading above the list of games on the home screen. Upper case in English by design; use whatever the language's convention for a small section heading is.
  ///
  /// In en, this message translates to:
  /// **'ALL GAMES'**
  String get homeAllGames;

  /// Heading above the card offering the puzzle the player last left unfinished, at the top of the home screen. Upper case in English by design; use whatever the language's convention for a small section heading is.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE'**
  String get homeContinue;

  /// The second line of a card offering an unfinished puzzle: how hard it is, how long it has been played for, and how much of the grid has something written in it.
  ///
  /// In en, this message translates to:
  /// **'{difficulty} · {time} · {percent}% filled in'**
  String continueDetails(String difficulty, String time, int percent);

  /// The line on the in-progress card on a game's own screen, where the game is already named above: how long the puzzle has been played for, and how much of the grid has something written in it.
  ///
  /// In en, this message translates to:
  /// **'{time} · {percent}% filled in'**
  String continueProgress(String time, int percent);

  /// Screen-reader label for the card offering an unfinished puzzle.
  ///
  /// In en, this message translates to:
  /// **'Continue {game}, {difficulty}, {time} played, {percent}% filled in'**
  String continueLabel(
    String game,
    String difficulty,
    String time,
    int percent,
  );

  /// The footer of the home screen. Nook's central promise, so keep it short and flat rather than enthusiastic.
  ///
  /// In en, this message translates to:
  /// **'No ads. No tracking. No account. Ever.'**
  String get homePromise;

  /// Heading above the daily-puzzle card on the home screen — the one puzzle that is the same for every player on a given day. Upper case in English by design; use whatever the language's convention for a small section heading is.
  ///
  /// In en, this message translates to:
  /// **'TODAY\'S PUZZLE'**
  String get homeDaily;

  /// The second line of the daily-puzzle card before it has been started: which day this is the puzzle of, and how hard the day makes it.
  ///
  /// In en, this message translates to:
  /// **'{date} · {difficulty}'**
  String dailyDetails(DateTime date, String difficulty);

  /// The second line of the daily-puzzle card while today's puzzle is under way: the day, how long it has been played for, and how far along it is.
  ///
  /// In en, this message translates to:
  /// **'{date} · {time} · {percent}% filled in'**
  String dailyDetailsProgress(DateTime date, String time, int percent);

  /// Screen-reader label for the daily-puzzle card before it has been started. One sentence, ending with the daily streak the card also shows.
  ///
  /// In en, this message translates to:
  /// **'Today\'s puzzle: {game}, {date}, {difficulty}. Not started yet. {streak, plural, =0{No daily streak yet} =1{Daily streak, 1 day} other{Daily streak, {streak} days}}'**
  String dailyLabel(String game, DateTime date, String difficulty, int streak);

  /// Screen-reader label for the daily-puzzle card while today's puzzle is under way. One sentence, ending with the daily streak the card also shows.
  ///
  /// In en, this message translates to:
  /// **'Continue today\'s puzzle: {game}, {date}, {time} played, {percent}% filled in. {streak, plural, =0{No daily streak yet} =1{Daily streak, 1 day} other{Daily streak, {streak} days}}'**
  String dailyLabelProgress(
    String game,
    DateTime date,
    String time,
    int percent,
    int streak,
  );

  /// The second line of the daily-puzzle card once today's puzzle has been solved: the day, and that it is done. The card is no longer tappable in this state.
  ///
  /// In en, this message translates to:
  /// **'{date} · Solved'**
  String dailySolvedDetails(DateTime date);

  /// Screen-reader label for the daily-puzzle card once today's puzzle is solved. One sentence, ending with the daily streak the card also shows.
  ///
  /// In en, this message translates to:
  /// **'Today\'s puzzle solved: {game}, {date}. {streak, plural, =0{No daily streak yet} =1{Daily streak, 1 day} other{Daily streak, {streak} days}}'**
  String dailyLabelSolved(String game, DateTime date, int streak);

  /// Screen-reader label for a playable game in the home list.
  ///
  /// In en, this message translates to:
  /// **'{title}. {subtitle}'**
  String gameRowLabel(String title, String subtitle);

  /// Screen-reader label for a game in the home list that is listed but cannot be played yet.
  ///
  /// In en, this message translates to:
  /// **'{title}. Not available yet'**
  String gameRowUnavailableLabel(String title);

  /// The second line of a Sudoku row on the home screen: the grid size, then what the grid feels like.
  ///
  /// In en, this message translates to:
  /// **'{size} · {description}'**
  String gameRowSubtitle(String size, String description);

  /// Name of the 9x9 Sudoku.
  ///
  /// In en, this message translates to:
  /// **'Sudoku Classic'**
  String get sudokuClassicTitle;

  /// Name of the 6x6 Sudoku.
  ///
  /// In en, this message translates to:
  /// **'Sudoku Light'**
  String get sudokuLightTitle;

  /// Name of the 4x4 Sudoku.
  ///
  /// In en, this message translates to:
  /// **'Sudoku Mini'**
  String get sudokuMiniTitle;

  /// One phrase saying what the 9x9 is like. Lower case: it follows the grid size in the middle of a line.
  ///
  /// In en, this message translates to:
  /// **'the full grid'**
  String get sudokuClassicBlurb;

  /// One phrase saying what the 6x6 is like. Lower case: it follows the grid size in the middle of a line.
  ///
  /// In en, this message translates to:
  /// **'a gentler grid'**
  String get sudokuLightBlurb;

  /// One phrase saying what the 4x4 is like. Lower case: it follows the grid size in the middle of a line.
  ///
  /// In en, this message translates to:
  /// **'a few quiet minutes'**
  String get sudokuMiniBlurb;

  /// Name of the Stars puzzle, in the game list and its header.
  ///
  /// In en, this message translates to:
  /// **'Stars'**
  String get starsTitle;

  /// The one-line description of Stars in the home game list.
  ///
  /// In en, this message translates to:
  /// **'One star in every row, column and region'**
  String get starsSubtitle;

  /// The single line of instruction under the Stars board: a tap cycles a cell from empty, to a ruled-out dot, to a star, and back.
  ///
  /// In en, this message translates to:
  /// **'Tap once to rule out, twice for a star'**
  String get starsInstruction;

  /// The running count above the Stars board: how many stars are placed out of how many a finished board holds. A star icon sits before it.
  ///
  /// In en, this message translates to:
  /// **'{placed} of {target}'**
  String starsCounter(int placed, int target);

  /// Screen-reader label for the star counter above the board.
  ///
  /// In en, this message translates to:
  /// **'{placed} of {target} stars placed'**
  String starsCounterLabel(int placed, int target);

  /// The caption under the legend below the Stars board, naming what the eight colour swatches are.
  ///
  /// In en, this message translates to:
  /// **'Each region has its own colour'**
  String get starsLegend;

  /// Screen-reader label for the legend of region swatches below the Stars board.
  ///
  /// In en, this message translates to:
  /// **'The regions, each in its own colour'**
  String get starsLegendLabel;

  /// Name of the Duo puzzle, in the game list and its header.
  ///
  /// In en, this message translates to:
  /// **'Duo'**
  String get duoTitle;

  /// The one-line description of Duo in the home game list.
  ///
  /// In en, this message translates to:
  /// **'Circles and squares, never three in a row'**
  String get duoSubtitle;

  /// The single line of instruction under the Duo board: a tap cycles a cell from empty, to a circle, to a square, and back.
  ///
  /// In en, this message translates to:
  /// **'Tap a cell for a circle, again for a square'**
  String get duoInstruction;

  /// Screen-reader label for the legend below the Duo board, which explains the two symbols and the two badges.
  ///
  /// In en, this message translates to:
  /// **'The board\'s key: what each symbol and badge means'**
  String get duoLegendLabel;

  /// The word for the round symbol, beside a circle glyph in the Duo legend.
  ///
  /// In en, this message translates to:
  /// **'Circle'**
  String get duoLegendCircle;

  /// The word for the square symbol, beside a square glyph in the Duo legend.
  ///
  /// In en, this message translates to:
  /// **'Square'**
  String get duoLegendSquare;

  /// What an '=' badge means in Duo: the two cells it sits between hold the same symbol. Shown beside the '=' glyph in the legend.
  ///
  /// In en, this message translates to:
  /// **'Same'**
  String get duoLegendEqual;

  /// What an 'x' badge means in Duo: the two cells it sits between hold different symbols. Shown beside the 'x' glyph in the legend.
  ///
  /// In en, this message translates to:
  /// **'Different'**
  String get duoLegendUnequal;

  /// Screen-reader label for an '=' badge on the Duo board: the two cells it joins must hold the same symbol.
  ///
  /// In en, this message translates to:
  /// **'Same-symbol badge'**
  String get duoBadgeEqual;

  /// Screen-reader label for an 'x' badge on the Duo board: the two cells it joins must hold different symbols.
  ///
  /// In en, this message translates to:
  /// **'Different-symbol badge'**
  String get duoBadgeUnequal;

  /// Screen-reader label for an empty Duo cell. Rows and columns are counted from one.
  ///
  /// In en, this message translates to:
  /// **'Row {row}, column {column}, empty'**
  String cellDuoEmpty(int row, int column);

  /// Screen-reader label for a Duo cell holding a circle the player placed.
  ///
  /// In en, this message translates to:
  /// **'Row {row}, column {column}, circle'**
  String cellDuoCircle(int row, int column);

  /// Screen-reader label for a Duo cell holding a square the player placed.
  ///
  /// In en, this message translates to:
  /// **'Row {row}, column {column}, square'**
  String cellDuoSquare(int row, int column);

  /// Screen-reader label for a Duo cell whose circle came with the puzzle and cannot be changed.
  ///
  /// In en, this message translates to:
  /// **'Row {row}, column {column}, circle, given'**
  String cellDuoGivenCircle(int row, int column);

  /// Screen-reader label for a Duo cell whose square came with the puzzle and cannot be changed.
  ///
  /// In en, this message translates to:
  /// **'Row {row}, column {column}, square, given'**
  String cellDuoGivenSquare(int row, int column);

  /// Screen-reader label for a Duo cell a hint has just emptied because the circle in it was wrong — one the solution does not have there. Said for a moment after the hint, then the cell goes back to reading as empty. The symbol is a mistake the hint takes away, not a reveal.
  ///
  /// In en, this message translates to:
  /// **'Row {row}, column {column}, circle taken away, it was wrong'**
  String cellDuoClearedCircle(int row, int column);

  /// Screen-reader label for a Duo cell a hint has just emptied because the square in it was wrong — one the solution does not have there. Said for a moment after the hint, then the cell goes back to reading as empty. The symbol is a mistake the hint takes away, not a reveal.
  ///
  /// In en, this message translates to:
  /// **'Row {row}, column {column}, square taken away, it was wrong'**
  String cellDuoClearedSquare(int row, int column);

  /// Screen-reader label for a Duo cell holding a circle that is part of a run of three or more identical symbols in a row or column — a broken rule.
  ///
  /// In en, this message translates to:
  /// **'Row {row}, column {column}, circle, three in a row'**
  String cellDuoCircleBreachTriple(int row, int column);

  /// Screen-reader label for a Duo cell holding a square that is part of a run of three or more identical symbols in a row or column — a broken rule.
  ///
  /// In en, this message translates to:
  /// **'Row {row}, column {column}, square, three in a row'**
  String cellDuoSquareBreachTriple(int row, int column);

  /// Screen-reader label for a Duo cell holding a circle in a row or column that already has more circles than a balanced line allows — a broken rule.
  ///
  /// In en, this message translates to:
  /// **'Row {row}, column {column}, circle, too many circles in this line'**
  String cellDuoCircleBreachBalance(int row, int column);

  /// Screen-reader label for a Duo cell holding a square in a row or column that already has more squares than a balanced line allows — a broken rule.
  ///
  /// In en, this message translates to:
  /// **'Row {row}, column {column}, square, too many squares in this line'**
  String cellDuoSquareBreachBalance(int row, int column);

  /// Screen-reader label for a Duo cell holding a circle that contradicts a badge on one of its edges — an equals badge whose two cells differ, or a not-equals badge whose two cells match. A broken rule.
  ///
  /// In en, this message translates to:
  /// **'Row {row}, column {column}, circle, breaks a badge'**
  String cellDuoCircleBreachBadge(int row, int column);

  /// Screen-reader label for a Duo cell holding a square that contradicts a badge on one of its edges — an equals badge whose two cells differ, or a not-equals badge whose two cells match. A broken rule.
  ///
  /// In en, this message translates to:
  /// **'Row {row}, column {column}, square, breaks a badge'**
  String cellDuoSquareBreachBadge(int row, int column);

  /// A square grid's size, as a player reads it aloud: 4x4, 6x6, 9x9.
  ///
  /// In en, this message translates to:
  /// **'{size}x{size}'**
  String gridSize(int size);

  /// Name of the easiest difficulty tier.
  ///
  /// In en, this message translates to:
  /// **'Gentle'**
  String get difficultyGentle;

  /// Name of the second-easiest difficulty tier.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get difficultyEasy;

  /// Name of the middle difficulty tier.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get difficultyMedium;

  /// Name of the second-hardest difficulty tier.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get difficultyHard;

  /// Name of the hardest difficulty tier.
  ///
  /// In en, this message translates to:
  /// **'Fiendish'**
  String get difficultyFiendish;

  /// What solving a Gentle puzzle feels like. Describes the thinking, never the clue count.
  ///
  /// In en, this message translates to:
  /// **'One cell at a time'**
  String get difficultyGentleBlurb;

  /// What solving an Easy puzzle feels like.
  ///
  /// In en, this message translates to:
  /// **'A little more looking'**
  String get difficultyEasyBlurb;

  /// What solving a Medium puzzle feels like. 'Ruling out' means eliminating candidates before placing a digit.
  ///
  /// In en, this message translates to:
  /// **'Some ruling out'**
  String get difficultyMediumBlurb;

  /// What solving a Hard puzzle feels like.
  ///
  /// In en, this message translates to:
  /// **'A lot of ruling out'**
  String get difficultyHardBlurb;

  /// What solving a Fiendish puzzle feels like. A 'chain' is a line of reasoning linking cells across the whole board.
  ///
  /// In en, this message translates to:
  /// **'Chains across the grid'**
  String get difficultyFiendishBlurb;

  /// Heading above the card offering this game's unfinished puzzle, on the screen where a difficulty is picked. Upper case in English by design.
  ///
  /// In en, this message translates to:
  /// **'IN PROGRESS'**
  String get difficultyInProgress;

  /// Heading above the list of difficulties. Upper case in English by design.
  ///
  /// In en, this message translates to:
  /// **'START A NEW ONE'**
  String get difficultyStartNew;

  /// Shown beside the hardest tier instead of a difficulty meter, warning that pencil marks are effectively required.
  ///
  /// In en, this message translates to:
  /// **'needs notes'**
  String get difficultyNeedsNotes;

  /// The line under a difficulty's name once the player has finished puzzles there: their fastest time at this tier, and how many they have solved. The time is a digital clock reading, minutes and seconds separated by a colon.
  ///
  /// In en, this message translates to:
  /// **'best {time} · {count, plural, =1{1 solved} other{{count} solved}}'**
  String difficultyTierBest(String time, int count);

  /// The same line for a tier the player has only ever finished with a hint, so it has a count but no best time. A hinted puzzle counts as solved and never sets a best.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 solved} other{{count} solved}}'**
  String difficultyTierSolved(int count);

  /// Screen-reader label for a difficulty row.
  ///
  /// In en, this message translates to:
  /// **'{name}. {description}'**
  String difficultyTierLabel(String name, String description);

  /// Screen-reader label for the hardest difficulty row, which additionally warns that pencil marks are needed.
  ///
  /// In en, this message translates to:
  /// **'{name}. {description}. Needs notes'**
  String difficultyTierLabelNeedsNotes(String name, String description);

  /// Explains why a grid offers a single difficulty: it is too small to ever be hard.
  ///
  /// In en, this message translates to:
  /// **'A {size} grid always leaves a cell you can read on its own, so it only comes one way.'**
  String difficultyOnlyOneTier(String size);

  /// Explains why a grid offers the easiest and hardest tiers but nothing in between.
  ///
  /// In en, this message translates to:
  /// **'A {size} grid is too small for the middle of the ladder — it either falls out or it needs a chain.'**
  String difficultyMissingMiddleTiers(String size);

  /// Nook's promise about its puzzles, stated on the way into a game.
  ///
  /// In en, this message translates to:
  /// **'Every puzzle has exactly one solution — you will never need to guess.'**
  String get difficultyGuarantee;

  /// Screen-reader label for the back button in a screen header.
  ///
  /// In en, this message translates to:
  /// **'Back to the game list'**
  String get backToGameList;

  /// The second line of the game screen header: which grid, and how hard the player asked for it to be.
  ///
  /// In en, this message translates to:
  /// **'{size} · {difficulty}'**
  String gameSubtitle(String size, String difficulty);

  /// Shown while a puzzle is being generated.
  ///
  /// In en, this message translates to:
  /// **'Making you a puzzle'**
  String get gameGenerating;

  /// Shown when generating a puzzle failed. Plain and blameless: it is not the player's doing.
  ///
  /// In en, this message translates to:
  /// **'That puzzle did not come out right.'**
  String get gameGenerationFailed;

  /// Button that asks for another puzzle after generation failed.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get gameTryAgain;

  /// The one line of instruction under the number pad, shown until the puzzle is solved.
  ///
  /// In en, this message translates to:
  /// **'Tap a cell, then a number'**
  String get gameInstruction;

  /// Announced and shown when the player finishes a puzzle.
  ///
  /// In en, this message translates to:
  /// **'Solved'**
  String get gameSolved;

  /// Screen-reader label for the clock in the game screen header. The placeholder is a digital clock reading, minutes and seconds separated by a colon, with an hours part in front of it once a puzzle passes an hour.
  ///
  /// In en, this message translates to:
  /// **'Time so far {time}'**
  String gameElapsedLabel(String time);

  /// The line under 'Solved' on the finished-puzzle screen: which game was finished, and at which difficulty.
  ///
  /// In en, this message translates to:
  /// **'{game} · {tier}'**
  String completionSubtitle(String game, String tier);

  /// Shown on the finished-puzzle screen when the player has just beaten their own fastest time at this game and difficulty. The only thing in Nook a player is ever measured against is themselves, so there is nobody else in this sentence.
  ///
  /// In en, this message translates to:
  /// **'A new personal best'**
  String get completionPersonalBest;

  /// Heading on the card showing how long the puzzle just finished took. Upper case in English by design; use whatever the language's convention for a small caption is.
  ///
  /// In en, this message translates to:
  /// **'TIME'**
  String get completionTime;

  /// Heading on the card showing the player's best time before this puzzle. Short because it sits in a narrow card between two others.
  ///
  /// In en, this message translates to:
  /// **'PREVIOUS'**
  String get completionPrevious;

  /// Heading on the card showing the player's current daily-puzzle streak — how many days in a row they have solved the daily. Upper case in English by design; use whatever the language's convention for a small caption is.
  ///
  /// In en, this message translates to:
  /// **'STREAK'**
  String get completionStreak;

  /// Stands in for a best time that does not exist yet, on the finished-puzzle screen. An em dash in English; use whatever a language writes for 'no figure'. Never a zero, which would read as a time.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get completionNoTime;

  /// Screen-reader label for the card showing how long this puzzle took.
  ///
  /// In en, this message translates to:
  /// **'Your time, {time}'**
  String completionTimeLabel(String time);

  /// Screen-reader label for the card showing the time the player had to beat.
  ///
  /// In en, this message translates to:
  /// **'Previous best, {time}'**
  String completionPreviousLabel(String time);

  /// Screen-reader label for the previous-best card when there is no best time yet — either the first solve here, or every one of them was helped by a hint.
  ///
  /// In en, this message translates to:
  /// **'No previous best time'**
  String get completionNoPreviousLabel;

  /// Screen-reader label for the daily-streak figure, shown both on the home screen's daily card and on the finished-puzzle screen's third card. Reads as one phrase. Zero is a real value here — a player who has not started, or who let a day pass, has no streak.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No daily streak yet} =1{Daily streak, 1 day} other{Daily streak, {count} days}}'**
  String dailyStreakLabel(int count);

  /// The main button on the finished-puzzle screen, which generates a new puzzle at the same difficulty. Names the tier so the player knows what they are getting.
  ///
  /// In en, this message translates to:
  /// **'Another {tier} puzzle'**
  String completionAnother(String tier);

  /// The second button on the finished-puzzle screen, which returns to the game list. 'Nook' is the app's name: leave it untranslated.
  ///
  /// In en, this message translates to:
  /// **'Back to Nook'**
  String get completionBackHome;

  /// Screen-reader label for the button that leaves the finished-puzzle screen and goes back to the list of difficulties.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get completionClose;

  /// Title of the question asked when the player starts a new puzzle in a game that already has an unfinished one.
  ///
  /// In en, this message translates to:
  /// **'Start a new puzzle?'**
  String get discardTitle;

  /// The body of that question. Plain about the consequence: this is the only thing in Nook that destroys the player's work.
  ///
  /// In en, this message translates to:
  /// **'Your unfinished {game} puzzle will be thrown away. There is no way to get it back.'**
  String discardBody(String game);

  /// The button that throws the unfinished puzzle away and starts a new one. Says what it does rather than 'OK'.
  ///
  /// In en, this message translates to:
  /// **'Discard and start'**
  String get discardConfirm;

  /// The button that cancels, leaving the unfinished puzzle exactly as it was.
  ///
  /// In en, this message translates to:
  /// **'Keep playing'**
  String get discardKeep;

  /// Screen-reader label announcing the board as a whole.
  ///
  /// In en, this message translates to:
  /// **'{name} board, {size} by {size}'**
  String boardLabel(String name, int size);

  /// Screen-reader label for a cell holding nothing. Rows and columns are counted from one.
  ///
  /// In en, this message translates to:
  /// **'Row {row}, column {column}, empty'**
  String cellEmpty(int row, int column);

  /// Screen-reader label for a cell holding pencil marks rather than an answer.
  ///
  /// In en, this message translates to:
  /// **'Row {row}, column {column}, notes {notes}'**
  String cellNotes(int row, int column, String notes);

  /// Screen-reader label for a cell whose digit came with the puzzle and cannot be changed.
  ///
  /// In en, this message translates to:
  /// **'Row {row}, column {column}, {value}, given'**
  String cellGiven(int row, int column, int value);

  /// Screen-reader label for a cell the player filled in themselves.
  ///
  /// In en, this message translates to:
  /// **'Row {row}, column {column}, {value}, your answer'**
  String cellAnswer(int row, int column, int value);

  /// Screen-reader label for a cell that a hint filled in. Distinguishes it from the player's own answer, which is what its colour does on screen.
  ///
  /// In en, this message translates to:
  /// **'Row {row}, column {column}, {value}, from a hint'**
  String cellHint(int row, int column, int value);

  /// Screen-reader label for a given cell whose digit appears again in the same row, column or box. Marking a repeat is a rule being broken, not an answer being judged — a digit that merely disagrees with the solution is never marked.
  ///
  /// In en, this message translates to:
  /// **'Row {row}, column {column}, {value}, given, repeated in its row, column or box'**
  String cellGivenConflict(int row, int column, int value);

  /// Screen-reader label for a cell the player filled in whose digit appears again in the same row, column or box.
  ///
  /// In en, this message translates to:
  /// **'Row {row}, column {column}, {value}, your answer, repeated in its row, column or box'**
  String cellAnswerConflict(int row, int column, int value);

  /// Screen-reader label for a hinted cell whose digit appears again in the same row, column or box — which can happen when the player has entered the same digit wrongly somewhere it can see.
  ///
  /// In en, this message translates to:
  /// **'Row {row}, column {column}, {value}, from a hint, repeated in its row, column or box'**
  String cellHintConflict(int row, int column, int value);

  /// Screen-reader label for a cell a hint has just emptied because the digit in it was wrong. Said for a moment after the hint, then the cell goes back to reading as empty.
  ///
  /// In en, this message translates to:
  /// **'Row {row}, column {column}, {value} taken away, it was wrong'**
  String cellCleared(int row, int column, int value);

  /// What goes between items when a screen reader lists several digits, as in the pencil marks of one cell. Includes its trailing space.
  ///
  /// In en, this message translates to:
  /// **', '**
  String get listSeparator;

  /// Screen-reader label for an empty Stars cell. Rows, columns and regions are counted from one; the region is which of the coloured, textured shapes the cell belongs to.
  ///
  /// In en, this message translates to:
  /// **'Row {row}, column {column}, region {region}, empty'**
  String cellStarsEmpty(int row, int column, int region);

  /// Screen-reader label for a Stars cell the player has marked as holding no star. The mark is an annotation only — never placed for the player, never checked.
  ///
  /// In en, this message translates to:
  /// **'Row {row}, column {column}, region {region}, ruled out'**
  String cellStarsRuledOut(int row, int column, int region);

  /// Screen-reader label for a Stars cell holding a star the player placed.
  ///
  /// In en, this message translates to:
  /// **'Row {row}, column {column}, region {region}, star'**
  String cellStarsStar(int row, int column, int region);

  /// Screen-reader label for a star that breaks the rule that a row holds one star: another star sits in the same row. Both stars of the pair are marked this way, because which of the two is the intruder is a question only the answer could settle.
  ///
  /// In en, this message translates to:
  /// **'Row {row}, column {column}, region {region}, star, another star in its row'**
  String cellStarsStarBreachRow(int row, int column, int region);

  /// Screen-reader label for a star that breaks the rule that a column holds one star: another star sits in the same column.
  ///
  /// In en, this message translates to:
  /// **'Row {row}, column {column}, region {region}, star, another star in its column'**
  String cellStarsStarBreachColumn(int row, int column, int region);

  /// Screen-reader label for a star that breaks the rule that a region holds one star: another star sits in the same coloured, textured region.
  ///
  /// In en, this message translates to:
  /// **'Row {row}, column {column}, region {region}, star, another star in its region'**
  String cellStarsStarBreachRegion(int row, int column, int region);

  /// Screen-reader label for a star that breaks the rule that no two stars touch: another star is in one of the eight neighbouring cells, diagonals included.
  ///
  /// In en, this message translates to:
  /// **'Row {row}, column {column}, region {region}, star, touching another star'**
  String cellStarsStarBreachAdjacent(int row, int column, int region);

  /// Screen-reader label for a Stars cell a hint has just emptied because the star in it was wrong — one the solution does not have. Said for a moment after the hint, then the cell goes back to reading as empty. The star is a mistake the hint takes away, not a reveal.
  ///
  /// In en, this message translates to:
  /// **'Row {row}, column {column}, region {region}, star taken away, it was wrong'**
  String cellStarsCleared(int row, int column, int region);

  /// Control that takes back the last move.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get actionUndo;

  /// Control that clears the selected cell.
  ///
  /// In en, this message translates to:
  /// **'Erase'**
  String get actionErase;

  /// Stars control that wipes every ruled-out dot off the board at once, leaving the stars where they are. A 'mark' is the small dot a player pencils into a cell to say a star cannot go there.
  ///
  /// In en, this message translates to:
  /// **'Clear marks'**
  String get actionClearMarks;

  /// Control that switches between writing answers and writing pencil marks.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get actionNotes;

  /// Control that shows the player their next move: it takes away a wrong digit if there is one, and otherwise fills in one cell they could have worked out. Hints are unlimited and free, so the word carries no count and no cost.
  ///
  /// In en, this message translates to:
  /// **'Hint'**
  String get actionHint;

  /// The caption under a control that is a switch and is currently on. It spells the state out in words because a player who cannot see the fill would otherwise write pencil marks they meant as answers.
  ///
  /// In en, this message translates to:
  /// **'{label} on'**
  String actionToggleOn(String label);

  /// The caption under a control that is a switch and is currently off.
  ///
  /// In en, this message translates to:
  /// **'{label} off'**
  String actionToggleOff(String label);

  /// Screen-reader label for a control that cannot be used, giving the reason a sighted player reads from it being greyed out.
  ///
  /// In en, this message translates to:
  /// **'{label}, {reason}'**
  String actionUnavailableLabel(String label, String reason);

  /// Why a control is unavailable: the puzzle is already solved. Reads as the end of a sentence, so lower case.
  ///
  /// In en, this message translates to:
  /// **'the puzzle is done'**
  String get reasonPuzzleDone;

  /// Why undo is unavailable: no moves have been made. Reads as the end of a sentence, so lower case.
  ///
  /// In en, this message translates to:
  /// **'nothing to take back'**
  String get reasonNothingToUndo;

  /// Why erase is unavailable: no cell is selected, or the selected cell is already empty. Reads as the end of a sentence, so lower case.
  ///
  /// In en, this message translates to:
  /// **'nothing to erase'**
  String get reasonNothingToErase;

  /// Why the Stars 'clear marks' control is unavailable: there are no ruled-out dots on the board to wipe. Reads as the end of a sentence, so lower case.
  ///
  /// In en, this message translates to:
  /// **'no marks to clear'**
  String get reasonNoMarks;

  /// Why the hint control is unavailable: one was given a few seconds ago and the control waits before offering another. This is pacing, not rationing — hints are unlimited and free, and nothing is being counted or spent. Reads as the end of a sentence, so lower case.
  ///
  /// In en, this message translates to:
  /// **'just given, back in a moment'**
  String get reasonHintJustGiven;

  /// The small caption under a digit on the number pad, saying how many of that digit are still to be placed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{done} =1{1 left} other{{count} left}}'**
  String padCaption(int count);

  /// Screen-reader label for a digit on the number pad. A digit with none left is still tappable, because a wrong one is taken back by tapping it again.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{{digit}, all placed} =1{{digit}, 1 left to place} other{{digit}, {count} left to place}}'**
  String padKeyLabel(int digit, int count);

  /// Sudoku technique: a cell with one candidate left.
  ///
  /// In en, this message translates to:
  /// **'Naked single'**
  String get techniqueNakedSingle;

  /// Sudoku technique: a digit with one possible cell left in a row, column or box.
  ///
  /// In en, this message translates to:
  /// **'Hidden single'**
  String get techniqueHiddenSingle;

  /// Sudoku technique: two cells in a unit holding the same two candidates.
  ///
  /// In en, this message translates to:
  /// **'Naked pair'**
  String get techniqueNakedPair;

  /// Sudoku technique: two digits in a unit confined to the same two cells.
  ///
  /// In en, this message translates to:
  /// **'Hidden pair'**
  String get techniqueHiddenPair;

  /// Sudoku technique: a digit whose candidates in a box all share one line.
  ///
  /// In en, this message translates to:
  /// **'Pointing pair'**
  String get techniquePointingPair;

  /// Sudoku technique: a digit whose candidates on a line all share one box.
  ///
  /// In en, this message translates to:
  /// **'Box/line reduction'**
  String get techniqueBoxLineReduction;

  /// Sudoku technique: a naked pair with three cells and three digits.
  ///
  /// In en, this message translates to:
  /// **'Naked triple'**
  String get techniqueNakedTriple;

  /// Sudoku technique: a hidden pair with three digits and three cells.
  ///
  /// In en, this message translates to:
  /// **'Hidden triple'**
  String get techniqueHiddenTriple;

  /// Sudoku technique: a digit confined to the same two columns in two rows, or the transpose.
  ///
  /// In en, this message translates to:
  /// **'X-wing'**
  String get techniqueXWing;

  /// Sudoku technique: an X-wing across three lines instead of two.
  ///
  /// In en, this message translates to:
  /// **'Swordfish'**
  String get techniqueSwordfish;

  /// Sudoku technique: a two-candidate cell whose candidates each pair with a third digit in a cell it can see.
  ///
  /// In en, this message translates to:
  /// **'XY-wing'**
  String get techniqueXyWing;

  /// Sudoku technique: following a chain of either-or links for one digit until it contradicts itself.
  ///
  /// In en, this message translates to:
  /// **'Simple colouring'**
  String get techniqueSimpleColouring;
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
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
