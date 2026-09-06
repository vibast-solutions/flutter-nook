import 'package:puzzle_engine/puzzle_engine.dart';

import '../../l10n/app_localizations.dart';
import 'snake_variant.dart';

/// The words for the things Snake only knows as values.
///
/// `puzzle_engine` and the variant carry no name a player reads — a name has to
/// be translated — so translation lives here, the one place the answer to "where
/// does this word come from?" is.
extension SnakeVariantNaming on SnakeVariant {
  /// The name of the game, as it appears in the list and the header.
  String title(AppLocalizations l10n) => l10n.snakeTitle;

  /// The one-line description under the name in the game list.
  String subtitle(AppLocalizations l10n) => l10n.snakeSubtitle;
}

/// The words for the Snake speed levels, which the engine only knows as an
/// ordered enum.
extension SnakeSpeedNaming on SnakeSpeed {
  /// The name of this speed, as it appears on the picker row.
  String label(AppLocalizations l10n) => switch (this) {
    SnakeSpeed.relaxed => l10n.snakeSpeedRelaxed,
    SnakeSpeed.steady => l10n.snakeSpeedSteady,
    SnakeSpeed.brisk => l10n.snakeSpeedBrisk,
    SnakeSpeed.swift => l10n.snakeSpeedSwift,
    SnakeSpeed.frantic => l10n.snakeSpeedFrantic,
  };

  /// The line under the name, saying what the pace feels like to play.
  String blurb(AppLocalizations l10n) => switch (this) {
    SnakeSpeed.relaxed => l10n.snakeSpeedRelaxedBlurb,
    SnakeSpeed.steady => l10n.snakeSpeedSteadyBlurb,
    SnakeSpeed.brisk => l10n.snakeSpeedBriskBlurb,
    SnakeSpeed.swift => l10n.snakeSpeedSwiftBlurb,
    SnakeSpeed.frantic => l10n.snakeSpeedFranticBlurb,
  };
}
