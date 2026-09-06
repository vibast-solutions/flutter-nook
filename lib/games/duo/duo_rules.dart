import '../../board/duo_board.dart';
import '../../chrome/how_to_play.dart';
import '../../l10n/app_localizations.dart';
import 'duo_naming.dart';
import 'duo_variant.dart';

/// Duo's rules, for the "How it's played" sheet.
///
/// The key is the board's own [DuoLegend], so the two symbols and the two
/// badges read in the sheet exactly as they do under the board.
RulesSheetContent duoRules(AppLocalizations l10n, DuoVariant variant) {
  return RulesSheetContent(
    title: variant.title(l10n),
    objective: l10n.duoRulesObjective,
    interaction: l10n.duoRulesInteraction,
    legend: const DuoLegend(),
  );
}
