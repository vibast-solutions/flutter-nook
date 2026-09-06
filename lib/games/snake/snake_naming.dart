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
