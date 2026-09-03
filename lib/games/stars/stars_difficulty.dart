import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../../chrome/continue_card.dart';
import '../../chrome/difficulty_naming.dart';
import '../../chrome/difficulty_page.dart';
import '../../chrome/discard_dialog.dart';
import '../../chrome/play_clock.dart';
import '../../home/home_screen.dart';
import '../../l10n/app_localizations.dart';
import '../../store/nook_database.dart';
import '../../store/saved_game.dart';
import 'stars_naming.dart';
import 'stars_save.dart';
import 'stars_screen.dart';
import 'stars_variant.dart';

/// The difficulty screen for Stars, on the shared [DifficultyPage].
///
/// Stars offers the whole ladder, so there is no short-ladder note. Since
/// VIB-89 it saves, so it carries the same two things Sudoku's does: an
/// in-progress card for the puzzle it has under way, and the discard-first dance
/// before starting a new one over it.
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

  /// This game's unfinished puzzle, if it has one this build can open.
  StarsSave? _saved(List<SavedGame>? saves) {
    for (final SavedGame save in saves ?? const <SavedGame>[]) {
      if (save.gameId == variant.id) {
        return StarsSave.read(save);
      }
    }
    return null;
  }

  /// Starts a new puzzle at [tier], asking first if that means losing one.
  ///
  /// The saved puzzle is deleted before the new one is opened rather than left
  /// to be overwritten: the player said to throw it away, and it should be gone
  /// whether or not the puzzle that replaces it is ever generated.
  Future<void> _start(
    BuildContext context,
    WidgetRef ref,
    PuzzleDifficulty tier,
  ) async {
    final NavigatorState navigator = Navigator.of(context);
    final StarsSave? saved = _saved(ref.read(savedGamesProvider).value);
    if (saved != null) {
      final bool discard = await DiscardDialog.ask(
        context,
        gameName: saved.variant.title(AppLocalizations.of(context)),
      );
      if (!discard) {
        return;
      }
      await ref.read(savedGameStoreProvider).discard(variant.id);
    }
    await navigator.push(StarsGamePage.route(variant, tier));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return DifficultyPage(
      title: variant.title(l10n),
      gameId: variant.id,
      tiers: variant.tiers,
      onStart: _start,
      inProgress: (BuildContext context, WidgetRef ref) {
        final StarsSave? saved = _saved(ref.watch(savedGamesProvider).value);
        return saved == null ? null : _InProgressRow(saved: saved);
      },
    );
  }
}

/// The puzzle already under way in Stars.
///
/// Named by its tier rather than by the game, which the header has just said.
class _InProgressRow extends StatelessWidget {
  const _InProgressRow({required this.saved});

  final StarsSave saved;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String tier = saved.difficulty.label(l10n);
    final String time = clockReading(saved.elapsed);
    final int percent = (saved.progress * 100).round();

    return ContinueCard(
      icon: starsIcon,
      title: tier,
      details: l10n.continueProgress(time, percent),
      semanticLabel: l10n.continueLabel(
        saved.variant.title(l10n),
        tier,
        time,
        percent,
      ),
      onTap: () => Navigator.of(context).push(StarsGamePage.resumeRoute(saved)),
    );
  }
}
