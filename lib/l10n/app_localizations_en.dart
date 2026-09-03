// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Nook';

  @override
  String get homeAllGames => 'ALL GAMES';

  @override
  String get homeContinue => 'CONTINUE';

  @override
  String continueDetails(String difficulty, String time, int percent) {
    return '$difficulty · $time · $percent% filled in';
  }

  @override
  String continueProgress(String time, int percent) {
    return '$time · $percent% filled in';
  }

  @override
  String continueLabel(
    String game,
    String difficulty,
    String time,
    int percent,
  ) {
    return 'Continue $game, $difficulty, $time played, $percent% filled in';
  }

  @override
  String get homePromise => 'No ads. No tracking. No account. Ever.';

  @override
  String gameRowLabel(String title, String subtitle) {
    return '$title. $subtitle';
  }

  @override
  String gameRowUnavailableLabel(String title) {
    return '$title. Not available yet';
  }

  @override
  String gameRowSubtitle(String size, String description) {
    return '$size · $description';
  }

  @override
  String get sudokuClassicTitle => 'Sudoku Classic';

  @override
  String get sudokuLightTitle => 'Sudoku Light';

  @override
  String get sudokuMiniTitle => 'Sudoku Mini';

  @override
  String get sudokuClassicBlurb => 'the full grid';

  @override
  String get sudokuLightBlurb => 'a gentler grid';

  @override
  String get sudokuMiniBlurb => 'a few quiet minutes';

  @override
  String get starsTitle => 'Stars';

  @override
  String get starsSubtitle => 'One star in every row, column and region';

  @override
  String get starsInstruction => 'Tap once to rule out, twice for a star';

  @override
  String starsCounter(int placed, int target) {
    return '$placed of $target';
  }

  @override
  String starsCounterLabel(int placed, int target) {
    return '$placed of $target stars placed';
  }

  @override
  String get starsLegend => 'Each region has its own colour and pattern';

  @override
  String get starsLegendLabel =>
      'The regions, each with its own colour and pattern';

  @override
  String get duoTitle => 'Duo';

  @override
  String get duoSubtitle => 'Circles and squares, never three in a row';

  @override
  String get duoInstruction => 'Tap a cell for a circle, again for a square';

  @override
  String get duoLegendLabel =>
      'The board\'s key: what each symbol and badge means';

  @override
  String get duoLegendCircle => 'Circle';

  @override
  String get duoLegendSquare => 'Square';

  @override
  String get duoLegendEqual => 'Same';

  @override
  String get duoLegendUnequal => 'Different';

  @override
  String get duoBadgeEqual => 'Same-symbol badge';

  @override
  String get duoBadgeUnequal => 'Different-symbol badge';

  @override
  String cellDuoEmpty(int row, int column) {
    return 'Row $row, column $column, empty';
  }

  @override
  String cellDuoCircle(int row, int column) {
    return 'Row $row, column $column, circle';
  }

  @override
  String cellDuoSquare(int row, int column) {
    return 'Row $row, column $column, square';
  }

  @override
  String cellDuoGivenCircle(int row, int column) {
    return 'Row $row, column $column, circle, given';
  }

  @override
  String cellDuoGivenSquare(int row, int column) {
    return 'Row $row, column $column, square, given';
  }

  @override
  String gridSize(int size) {
    return '${size}x$size';
  }

  @override
  String get difficultyGentle => 'Gentle';

  @override
  String get difficultyEasy => 'Easy';

  @override
  String get difficultyMedium => 'Medium';

  @override
  String get difficultyHard => 'Hard';

  @override
  String get difficultyFiendish => 'Fiendish';

  @override
  String get difficultyGentleBlurb => 'One cell at a time';

  @override
  String get difficultyEasyBlurb => 'A little more looking';

  @override
  String get difficultyMediumBlurb => 'Some ruling out';

  @override
  String get difficultyHardBlurb => 'A lot of ruling out';

  @override
  String get difficultyFiendishBlurb => 'Chains across the grid';

  @override
  String get difficultyInProgress => 'IN PROGRESS';

  @override
  String get difficultyStartNew => 'START A NEW ONE';

  @override
  String get difficultyNeedsNotes => 'needs notes';

  @override
  String difficultyTierBest(String time, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count solved',
      one: '1 solved',
    );
    return 'best $time · $_temp0';
  }

  @override
  String difficultyTierSolved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count solved',
      one: '1 solved',
    );
    return '$_temp0';
  }

  @override
  String difficultyTierLabel(String name, String description) {
    return '$name. $description';
  }

  @override
  String difficultyTierLabelNeedsNotes(String name, String description) {
    return '$name. $description. Needs notes';
  }

  @override
  String difficultyOnlyOneTier(String size) {
    return 'A $size grid always leaves a cell you can read on its own, so it only comes one way.';
  }

  @override
  String difficultyMissingMiddleTiers(String size) {
    return 'A $size grid is too small for the middle of the ladder — it either falls out or it needs a chain.';
  }

  @override
  String get difficultyGuarantee =>
      'Every puzzle has exactly one solution — you will never need to guess.';

  @override
  String get backToGameList => 'Back to the game list';

  @override
  String gameSubtitle(String size, String difficulty) {
    return '$size · $difficulty';
  }

  @override
  String get gameGenerating => 'Making you a puzzle';

  @override
  String get gameGenerationFailed => 'That puzzle did not come out right.';

  @override
  String get gameTryAgain => 'Try again';

  @override
  String get gameInstruction => 'Tap a cell, then a number';

  @override
  String get gameSolved => 'Solved';

  @override
  String gameElapsedLabel(String time) {
    return 'Time so far $time';
  }

  @override
  String completionSubtitle(String game, String tier) {
    return '$game · $tier';
  }

  @override
  String get completionPersonalBest => 'A new personal best';

  @override
  String get completionTime => 'TIME';

  @override
  String get completionPrevious => 'PREVIOUS';

  @override
  String get completionSolvedCount => 'SOLVED';

  @override
  String get completionNoTime => '—';

  @override
  String completionTimeLabel(String time) {
    return 'Your time, $time';
  }

  @override
  String completionPreviousLabel(String time) {
    return 'Previous best, $time';
  }

  @override
  String get completionNoPreviousLabel => 'No previous best time';

  @override
  String completionSolvedLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count puzzles solved at this difficulty',
      one: '1 puzzle solved at this difficulty',
    );
    return '$_temp0';
  }

  @override
  String completionAnother(String tier) {
    return 'Another $tier puzzle';
  }

  @override
  String get completionBackHome => 'Back to Nook';

  @override
  String get completionClose => 'Close';

  @override
  String get discardTitle => 'Start a new puzzle?';

  @override
  String discardBody(String game) {
    return 'Your unfinished $game puzzle will be thrown away. There is no way to get it back.';
  }

  @override
  String get discardConfirm => 'Discard and start';

  @override
  String get discardKeep => 'Keep playing';

  @override
  String boardLabel(String name, int size) {
    return '$name board, $size by $size';
  }

  @override
  String cellEmpty(int row, int column) {
    return 'Row $row, column $column, empty';
  }

  @override
  String cellNotes(int row, int column, String notes) {
    return 'Row $row, column $column, notes $notes';
  }

  @override
  String cellGiven(int row, int column, int value) {
    return 'Row $row, column $column, $value, given';
  }

  @override
  String cellAnswer(int row, int column, int value) {
    return 'Row $row, column $column, $value, your answer';
  }

  @override
  String cellHint(int row, int column, int value) {
    return 'Row $row, column $column, $value, from a hint';
  }

  @override
  String cellGivenConflict(int row, int column, int value) {
    return 'Row $row, column $column, $value, given, repeated in its row, column or box';
  }

  @override
  String cellAnswerConflict(int row, int column, int value) {
    return 'Row $row, column $column, $value, your answer, repeated in its row, column or box';
  }

  @override
  String cellHintConflict(int row, int column, int value) {
    return 'Row $row, column $column, $value, from a hint, repeated in its row, column or box';
  }

  @override
  String cellCleared(int row, int column, int value) {
    return 'Row $row, column $column, $value taken away, it was wrong';
  }

  @override
  String get listSeparator => ', ';

  @override
  String cellStarsEmpty(int row, int column, int region) {
    return 'Row $row, column $column, region $region, empty';
  }

  @override
  String cellStarsRuledOut(int row, int column, int region) {
    return 'Row $row, column $column, region $region, ruled out';
  }

  @override
  String cellStarsStar(int row, int column, int region) {
    return 'Row $row, column $column, region $region, star';
  }

  @override
  String cellStarsStarBreachRow(int row, int column, int region) {
    return 'Row $row, column $column, region $region, star, another star in its row';
  }

  @override
  String cellStarsStarBreachColumn(int row, int column, int region) {
    return 'Row $row, column $column, region $region, star, another star in its column';
  }

  @override
  String cellStarsStarBreachRegion(int row, int column, int region) {
    return 'Row $row, column $column, region $region, star, another star in its region';
  }

  @override
  String cellStarsStarBreachAdjacent(int row, int column, int region) {
    return 'Row $row, column $column, region $region, star, touching another star';
  }

  @override
  String cellStarsCleared(int row, int column, int region) {
    return 'Row $row, column $column, region $region, star taken away, it was wrong';
  }

  @override
  String get actionUndo => 'Undo';

  @override
  String get actionErase => 'Erase';

  @override
  String get actionClearMarks => 'Clear marks';

  @override
  String get actionNotes => 'Notes';

  @override
  String get actionHint => 'Hint';

  @override
  String actionToggleOn(String label) {
    return '$label on';
  }

  @override
  String actionToggleOff(String label) {
    return '$label off';
  }

  @override
  String actionUnavailableLabel(String label, String reason) {
    return '$label, $reason';
  }

  @override
  String get reasonPuzzleDone => 'the puzzle is done';

  @override
  String get reasonNothingToUndo => 'nothing to take back';

  @override
  String get reasonNothingToErase => 'nothing to erase';

  @override
  String get reasonNoMarks => 'no marks to clear';

  @override
  String get reasonHintJustGiven => 'just given, back in a moment';

  @override
  String padCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count left',
      one: '1 left',
      zero: 'done',
    );
    return '$_temp0';
  }

  @override
  String padKeyLabel(int digit, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$digit, $count left to place',
      one: '$digit, 1 left to place',
      zero: '$digit, all placed',
    );
    return '$_temp0';
  }

  @override
  String get techniqueNakedSingle => 'Naked single';

  @override
  String get techniqueHiddenSingle => 'Hidden single';

  @override
  String get techniqueNakedPair => 'Naked pair';

  @override
  String get techniqueHiddenPair => 'Hidden pair';

  @override
  String get techniquePointingPair => 'Pointing pair';

  @override
  String get techniqueBoxLineReduction => 'Box/line reduction';

  @override
  String get techniqueNakedTriple => 'Naked triple';

  @override
  String get techniqueHiddenTriple => 'Hidden triple';

  @override
  String get techniqueXWing => 'X-wing';

  @override
  String get techniqueSwordfish => 'Swordfish';

  @override
  String get techniqueXyWing => 'XY-wing';

  @override
  String get techniqueSimpleColouring => 'Simple colouring';
}
