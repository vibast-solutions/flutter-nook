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
  String get starsSubtitle =>
      'One star per row, column and region · coming soon';

  @override
  String get duoTitle => 'Duo';

  @override
  String get duoSubtitle =>
      'Circles and squares, never three in a row · coming soon';

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
  String get difficultyStartNew => 'START A NEW ONE';

  @override
  String get difficultyNeedsNotes => 'needs notes';

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
  String get gameNewPuzzle => 'New puzzle';

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
  String get listSeparator => ', ';

  @override
  String get actionUndo => 'Undo';

  @override
  String get actionErase => 'Erase';

  @override
  String get actionNotes => 'Notes';

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
