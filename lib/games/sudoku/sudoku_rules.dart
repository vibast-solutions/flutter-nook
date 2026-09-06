import '../../chrome/how_to_play.dart';
import '../../l10n/app_localizations.dart';
import 'sudoku_naming.dart';
import 'sudoku_variant.dart';

/// Sudoku's rules, for the "How it's played" sheet.
///
/// The three sizes share one aim and one set of controls — only the biggest
/// number differs — so the copy is written once and the grid's size fills the
/// blank. Sudoku has no legend widget: its only symbols are the numbers the aim
/// already names, so the sheet carries no key.
RulesSheetContent sudokuRules(AppLocalizations l10n, SudokuVariant variant) {
  return RulesSheetContent(
    title: variant.title(l10n),
    objective: l10n.sudokuRulesObjective(variant.spec.size),
    interaction: l10n.sudokuRulesInteraction,
  );
}
