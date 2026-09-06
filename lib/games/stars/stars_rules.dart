import '../../board/stars_board.dart';
import '../../chrome/how_to_play.dart';
import '../../l10n/app_localizations.dart';
import 'stars_naming.dart';
import 'stars_variant.dart';

/// Stars' rules, for the "How it's played" sheet.
///
/// The key is the board's own [StarsLegend], built for however many regions the
/// variant has, so the sheet and the board name the colours the same way.
RulesSheetContent starsRules(AppLocalizations l10n, StarsVariant variant) {
  return RulesSheetContent(
    title: variant.title(l10n),
    objective: l10n.starsRulesObjective,
    interaction: l10n.starsRulesInteraction,
    legend: StarsLegend(regionCount: variant.spec.regionCount),
  );
}
