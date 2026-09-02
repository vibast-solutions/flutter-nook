import 'package:puzzle_engine/puzzle_engine.dart';

import '../../l10n/app_localizations.dart';
import 'sudoku_variant.dart';

/// The words for the things the engine only knows as enum values.
///
/// `puzzle_engine` is pure Dart and cannot import Flutter, so nothing in it
/// can carry a name a player reads — a name has to be translated, and
/// translation lives here. Keeping all three mappings in one file means the
/// answer to "where does this word come from?" is one place rather than three.
extension SudokuVariantNaming on SudokuVariant {
  /// The name of this Sudoku, as it appears in the game list and headers.
  String title(AppLocalizations l10n) => switch (id) {
    SudokuVariant.miniId => l10n.sudokuMiniTitle,
    SudokuVariant.lightId => l10n.sudokuLightTitle,
    _ => l10n.sudokuClassicTitle,
  };

  /// One phrase saying what this grid is like to sit down with.
  String blurb(AppLocalizations l10n) => switch (id) {
    SudokuVariant.miniId => l10n.sudokuMiniBlurb,
    SudokuVariant.lightId => l10n.sudokuLightBlurb,
    _ => l10n.sudokuClassicBlurb,
  };

  /// `4x4`, `6x6`, `9x9` — the grid size as a player reads it aloud.
  String sizeLabel(AppLocalizations l10n) => l10n.gridSize(spec.size);
}

/// The name of a difficulty tier.
extension SudokuDifficultyNaming on SudokuDifficulty {
  /// The tier's name, as it appears on the difficulty screen and in headers.
  String label(AppLocalizations l10n) => switch (this) {
    SudokuDifficulty.gentle => l10n.difficultyGentle,
    SudokuDifficulty.easy => l10n.difficultyEasy,
    SudokuDifficulty.medium => l10n.difficultyMedium,
    SudokuDifficulty.hard => l10n.difficultyHard,
    SudokuDifficulty.fiendish => l10n.difficultyFiendish,
  };

  /// What solving a puzzle of this tier feels like — the line under the name.
  ///
  /// Describes the thinking rather than the clue count, because clue count is
  /// not what makes a Sudoku hard and saying otherwise would be a lie the
  /// player can check.
  String blurb(AppLocalizations l10n) => switch (this) {
    SudokuDifficulty.gentle => l10n.difficultyGentleBlurb,
    SudokuDifficulty.easy => l10n.difficultyEasyBlurb,
    SudokuDifficulty.medium => l10n.difficultyMediumBlurb,
    SudokuDifficulty.hard => l10n.difficultyHardBlurb,
    SudokuDifficulty.fiendish => l10n.difficultyFiendishBlurb,
  };
}

/// The name of a solving technique.
///
/// Nothing shows these yet. They are here because hints (VIB-76) will name the
/// technique a hint used, and the shape that naming takes is a localisation
/// decision rather than a hint decision — what the sentence around the name
/// says is VIB-76's to choose.
extension SudokuTechniqueNaming on SudokuTechnique {
  /// The name a player would recognise this deduction by.
  String label(AppLocalizations l10n) => switch (this) {
    SudokuTechnique.nakedSingle => l10n.techniqueNakedSingle,
    SudokuTechnique.hiddenSingle => l10n.techniqueHiddenSingle,
    SudokuTechnique.nakedPair => l10n.techniqueNakedPair,
    SudokuTechnique.hiddenPair => l10n.techniqueHiddenPair,
    SudokuTechnique.pointingPair => l10n.techniquePointingPair,
    SudokuTechnique.boxLineReduction => l10n.techniqueBoxLineReduction,
    SudokuTechnique.nakedTriple => l10n.techniqueNakedTriple,
    SudokuTechnique.hiddenTriple => l10n.techniqueHiddenTriple,
    SudokuTechnique.xWing => l10n.techniqueXWing,
    SudokuTechnique.swordfish => l10n.techniqueSwordfish,
    SudokuTechnique.xyWing => l10n.techniqueXyWing,
    SudokuTechnique.simpleColouring => l10n.techniqueSimpleColouring,
  };
}
