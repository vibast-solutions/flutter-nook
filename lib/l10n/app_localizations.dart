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

  /// The caption under the legend below the Stars board, saying that colour is not the only thing telling the regions apart.
  ///
  /// In en, this message translates to:
  /// **'Each region has its own colour and pattern'**
  String get starsLegend;

  /// Screen-reader label for the legend of region swatches below the Stars board.
  ///
  /// In en, this message translates to:
  /// **'The regions, each with its own colour and pattern'**
  String get starsLegendLabel;

  /// Name of the Duo puzzle, listed on the home screen before it is playable.
  ///
  /// In en, this message translates to:
  /// **'Duo'**
  String get duoTitle;

  /// What Duo is, plus a note that it is not playable yet.
  ///
  /// In en, this message translates to:
  /// **'Circles and squares, never three in a row · coming soon'**
  String get duoSubtitle;

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

  /// Heading on the card showing how many puzzles the player has finished at this game and difficulty.
  ///
  /// In en, this message translates to:
  /// **'SOLVED'**
  String get completionSolvedCount;

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

  /// Screen-reader label for the card counting finished puzzles.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 puzzle solved at this difficulty} other{{count} puzzles solved at this difficulty}}'**
  String completionSolvedLabel(int count);

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
