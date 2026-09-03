import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../../chrome/difficulty_page.dart';
import '../../l10n/app_localizations.dart';
import 'duo_naming.dart';
import 'duo_screen.dart';
import 'duo_variant.dart';

/// The difficulty screen for Duo, on the shared [DifficultyPage].
///
/// Duo offers the whole ladder, so there is no short-ladder note. It does not
/// save yet — that is VIB-96 — so it carries neither an in-progress card nor the
/// discard-first dance a saving game needs: picking a tier simply opens a board,
/// exactly as Stars's screen did before it learned to save.
class DuoDifficultyPage extends StatelessWidget {
  const DuoDifficultyPage({required this.variant, super.key});

  /// The Duo variant whose difficulties are being offered.
  final DuoVariant variant;

  /// Builds a route to this page.
  static Route<void> route(DuoVariant variant) {
    return MaterialPageRoute<void>(
      builder: (BuildContext context) => DuoDifficultyPage(variant: variant),
    );
  }

  /// Opens a new puzzle at [tier].
  Future<void> _start(
    BuildContext context,
    WidgetRef ref,
    PuzzleDifficulty tier,
  ) {
    return Navigator.of(context).push(DuoGamePage.route(variant, tier));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return DifficultyPage(
      title: variant.title(l10n),
      gameId: variant.id,
      tiers: variant.tiers,
      onStart: _start,
    );
  }
}
