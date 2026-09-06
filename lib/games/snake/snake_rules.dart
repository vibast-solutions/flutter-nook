import '../../chrome/how_to_play.dart';
import '../../l10n/app_localizations.dart';
import 'snake_naming.dart';
import 'snake_variant.dart';

/// Snake's rules, for the "How it's played" sheet.
///
/// No legend: Snake has nothing a Sudoku digit or a Duo badge needs a key for —
/// the snake is the snake and the food is the food — so the aim and how you
/// steer are the whole of it.
RulesSheetContent snakeRules(AppLocalizations l10n, SnakeVariant variant) {
  return RulesSheetContent(
    title: variant.title(l10n),
    objective: l10n.snakeRulesObjective,
    interaction: l10n.snakeRulesInteraction,
  );
}
