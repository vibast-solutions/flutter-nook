import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../../chrome/difficulty_page.dart';
import '../../l10n/app_localizations.dart';
import 'stars_naming.dart';
import 'stars_screen.dart';
import 'stars_variant.dart';

/// The difficulty screen for Stars, on the shared [DifficultyPage].
///
/// Stars offers the whole ladder, so there is no short-ladder note; and it does
/// not save until VIB-89, so there is no in-progress card. All Stars adds is
/// which tiers it has and how to open one — the rest is the generic page.
class StarsDifficultyPage extends StatelessWidget {
  const StarsDifficultyPage({required this.variant, super.key});

  /// The Stars variant whose difficulties are being offered.
  final StarsVariant variant;

  /// Builds a route to this page.
  static Route<void> route(StarsVariant variant) {
    return MaterialPageRoute<void>(
      builder: (BuildContext context) => StarsDifficultyPage(variant: variant),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return DifficultyPage(
      title: variant.title(l10n),
      gameId: variant.id,
      tiers: variant.tiers,
      onStart: (BuildContext context, WidgetRef ref, PuzzleDifficulty tier) =>
          Navigator.of(context).push(StarsGamePage.route(variant, tier)),
    );
  }
}
