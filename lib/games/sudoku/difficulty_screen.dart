import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../../chrome/continue_card.dart';
import '../../chrome/difficulty_naming.dart';
import '../../chrome/difficulty_page.dart';
import '../../chrome/discard_dialog.dart';
import '../../chrome/play_clock.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../home/home_screen.dart';
import '../../l10n/app_localizations.dart';
import '../../store/nook_database.dart';
import '../../store/saved_game.dart';
import 'sudoku_naming.dart';
import 'sudoku_save.dart';
import 'sudoku_screen.dart';
import 'sudoku_variant.dart';

/// The difficulty screen for a Sudoku, on the shared [DifficultyPage].
///
/// Sudoku's own part is what the generic page hands off: which tiers this grid
/// can produce, the unfinished puzzle it might have in progress (and the
/// discard-first dance before starting a new one), and the note that explains
/// why a small grid offers fewer than five tiers.
class SudokuDifficultyPage extends StatelessWidget {
  const SudokuDifficultyPage({required this.variant, super.key});

  /// The Sudoku whose difficulties are being offered.
  final SudokuVariant variant;

  /// Builds a route to this page.
  static Route<void> route(SudokuVariant variant) {
    return MaterialPageRoute<void>(
      builder: (BuildContext context) => SudokuDifficultyPage(variant: variant),
    );
  }

  /// This game's unfinished puzzle, if it has one this build can open.
  SudokuSave? _saved(List<SavedGame>? saves) {
    for (final SavedGame save in saves ?? const <SavedGame>[]) {
      if (save.gameId == variant.id) {
        return SudokuSave.read(save);
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
    final SudokuSave? saved = _saved(ref.read(savedGamesProvider).value);
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
    await navigator.push(SudokuGamePage.route(variant, tier));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<PuzzleDifficulty> tiers = variant.tiers;
    return DifficultyPage(
      title: variant.title(l10n),
      gameId: variant.id,
      tiers: tiers,
      onStart: _start,
      inProgress: (BuildContext context, WidgetRef ref) {
        final SudokuSave? saved = _saved(ref.watch(savedGamesProvider).value);
        return saved == null ? null : _InProgressRow(saved: saved);
      },
      shortLadderNote: tiers.length < PuzzleDifficulty.values.length
          ? _ShortLadderNote(variant: variant)
          : null,
    );
  }
}

/// The puzzle already under way in this game.
///
/// Named by its tier rather than by the game, which the header has just said.
class _InProgressRow extends StatelessWidget {
  const _InProgressRow({required this.saved});

  final SudokuSave saved;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String tier = saved.difficulty.label(l10n);
    final String time = clockReading(saved.elapsed);
    final int percent = (saved.progress * 100).round();

    return ContinueCard(
      icon: sudokuIcon(saved.variant),
      title: tier,
      details: l10n.continueProgress(time, percent),
      semanticLabel: l10n.continueLabel(
        saved.variant.title(l10n),
        tier,
        time,
        percent,
      ),
      onTap: () =>
          Navigator.of(context).push(SudokuGamePage.resumeRoute(saved)),
    );
  }
}

/// Why a grid offers fewer than five tiers.
///
/// A player who knows Classic has five and finds three on Light deserves the
/// reason rather than a shrug — and the reason is a property of the grid, not a
/// feature Nook is holding back.
class _ShortLadderNote extends StatelessWidget {
  const _ShortLadderNote({required this.variant});

  final SudokuVariant variant;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String size = variant.sizeLabel(l10n);
    final bool single = variant.tiers.length == 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        single
            ? l10n.difficultyOnlyOneTier(size)
            : l10n.difficultyMissingMiddleTiers(size),
        style: NookType.footnote(colors.inkGhost),
      ),
    );
  }
}
