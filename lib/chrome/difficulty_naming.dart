import 'package:puzzle_engine/puzzle_engine.dart';

import '../l10n/app_localizations.dart';

/// The words for a difficulty tier.
///
/// [PuzzleDifficulty] is a `puzzle_engine` enum — pure Dart, so it carries no
/// name a player reads. Naming is the app's job, and it lives here rather than
/// in any one game because every Nook game grades on the same five tiers: the
/// name of Gentle is the same word whether a Sudoku or a Stars puzzle earned
/// it, so the mapping is written once and both games read it.
extension PuzzleDifficultyNaming on PuzzleDifficulty {
  /// The tier's name, as it appears on the difficulty screen and in headers.
  String label(AppLocalizations l10n) => switch (this) {
    PuzzleDifficulty.gentle => l10n.difficultyGentle,
    PuzzleDifficulty.easy => l10n.difficultyEasy,
    PuzzleDifficulty.medium => l10n.difficultyMedium,
    PuzzleDifficulty.hard => l10n.difficultyHard,
    PuzzleDifficulty.fiendish => l10n.difficultyFiendish,
  };

  /// What solving a puzzle of this tier feels like — the line under the name.
  ///
  /// Describes the thinking rather than how sparse the board looks, because
  /// sparseness is not what makes a puzzle hard and saying otherwise would be a
  /// lie the player can check.
  String blurb(AppLocalizations l10n) => switch (this) {
    PuzzleDifficulty.gentle => l10n.difficultyGentleBlurb,
    PuzzleDifficulty.easy => l10n.difficultyEasyBlurb,
    PuzzleDifficulty.medium => l10n.difficultyMediumBlurb,
    PuzzleDifficulty.hard => l10n.difficultyHardBlurb,
    PuzzleDifficulty.fiendish => l10n.difficultyFiendishBlurb,
  };
}
