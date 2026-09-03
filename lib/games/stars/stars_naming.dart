import '../../l10n/app_localizations.dart';
import 'stars_variant.dart';

/// The words for the things Stars only knows as values.
///
/// `puzzle_engine` and the variant carry no name a player reads — a name has to
/// be translated — so translation lives here, the one place the answer to
/// "where does this word come from?" is.
extension StarsVariantNaming on StarsVariant {
  /// The name of the game, as it appears in the list and the header.
  String title(AppLocalizations l10n) => l10n.starsTitle;

  /// `8x8` — the grid size as a player reads it aloud.
  String sizeLabel(AppLocalizations l10n) => l10n.gridSize(spec.size);
}
