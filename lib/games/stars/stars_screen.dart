import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../../board/stars_board.dart';
import '../../chrome/action_row.dart';
import '../../chrome/completion_view.dart';
import '../../chrome/difficulty_naming.dart';
import '../../chrome/game_header.dart';
import '../../chrome/game_providers.dart';
import '../../chrome/game_session.dart';
import '../../chrome/play_clock.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../store/nook_database.dart';
import 'stars_controller.dart';
import 'stars_naming.dart';
import 'stars_save.dart';
import 'stars_state.dart';
import 'stars_variant.dart';

/// The screen a player lands on after choosing Stars.
///
/// It owns the scope the game lives in: the variant and the tier are injected
/// here, so the controller below never has to ask which board it is playing.
/// The session it opens keeps the clock, records a solve, and — since VIB-89 —
/// keeps the board written to disk as it is played, exactly as Sudoku's does.
class StarsGamePage extends StatelessWidget {
  const StarsGamePage({
    required this.variant,
    required this.difficulty,
    this.resume,
    super.key,
  });

  /// Which Stars board to play.
  final StarsVariant variant;

  /// How hard the player asked for it to be.
  final PuzzleDifficulty difficulty;

  /// The puzzle to carry on with, or `null` to generate a new one.
  final StarsSave? resume;

  /// Builds a route to a new puzzle.
  static Route<void> route(StarsVariant variant, PuzzleDifficulty difficulty) {
    return MaterialPageRoute<void>(
      builder: (BuildContext context) =>
          StarsGamePage(variant: variant, difficulty: difficulty),
    );
  }

  /// Builds a route back into the puzzle in [save], exactly as it was left.
  static Route<void> resumeRoute(StarsSave save) {
    return MaterialPageRoute<void>(
      builder: (BuildContext context) => StarsGamePage(
        variant: save.variant,
        difficulty: save.difficulty,
        resume: save,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final StarsSave? saved = resume;
    return ProviderScope(
      overrides: [
        starsVariantProvider.overrideWithValue(variant),
        starsDifficultyProvider.overrideWithValue(difficulty),
        starsResumeProvider.overrideWithValue(saved?.game),
        gameIdProvider.overrideWithValue(variant.id),
        gameDifficultyProvider.overrideWithValue(difficulty),
        resumedElapsedProvider.overrideWithValue(
          saved?.elapsed ?? Duration.zero,
        ),
      ],
      // A Consumer so the save callbacks can reach the store from inside the
      // scope this page opened.
      child: Consumer(
        builder: (BuildContext context, WidgetRef ref, Widget? child) {
          final SavedGameStore store = ref.watch(savedGameStoreProvider);
          return GameSession<StarsGameState>(
            gameProvider: starsControllerProvider,
            isSolved: (StarsGameState game) => game.isSolved,
            wasHinted: (StarsGameState game) => game.wasHinted,
            writeSave: (StarsGameState game, Duration elapsed, DateTime at) =>
                store.save(
                  savedStarsGame(
                    game,
                    difficulty: difficulty,
                    elapsed: elapsed,
                    at: at,
                  ),
                ),
            discardSave: (StarsGameState game) =>
                store.discard(game.variant.id),
            child: const _StarsScreen(),
          );
        },
      ),
    );
  }
}

class _StarsScreen extends ConsumerWidget {
  const _StarsScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NookColors colors = Theme.of(context).nook;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final StarsVariant variant = ref.watch(starsVariantProvider);
    final PuzzleDifficulty difficulty = ref.watch(starsDifficultyProvider);
    final AsyncValue<StarsGameState> game = ref.watch(starsControllerProvider);

    if (game.value?.isSolved ?? false) {
      return Scaffold(
        backgroundColor: colors.sand,
        body: GameCompletionView(
          gameName: variant.title(l10n),
          tierLabel: difficulty.label(l10n),
          onAnother: () =>
              ref.read(starsControllerProvider.notifier).startNewPuzzle(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.sand,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            GameHeader(
              title: variant.title(l10n),
              subtitle: l10n.gameSubtitle(
                variant.sizeLabel(l10n),
                difficulty.label(l10n),
              ),
            ),
            Expanded(
              child: game.when(
                loading: () => const _Generating(),
                error: (Object error, StackTrace stack) => _GenerationFailed(
                  onRetry: () => ref
                      .read(starsControllerProvider.notifier)
                      .startNewPuzzle(),
                ),
                data: (StarsGameState state) => _Playing(game: state),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Playing extends ConsumerWidget {
  const _Playing({required this.game});

  final StarsGameState game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NookColors colors = Theme.of(context).nook;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final StarsController controller = ref.read(
      starsControllerProvider.notifier,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double margin = (constraints.maxWidth * 28 / 390).clamp(
          18.0,
          28.0,
        );
        final double edge = (constraints.maxWidth - margin * 2)
            .clamp(120.0, 420.0)
            .toDouble();

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(margin, 6, margin, 24),
          child: Column(
            children: <Widget>[
              _StarCounter(placed: game.starCount, target: game.starTarget),
              const SizedBox(height: 12),
              StarsBoard(game: game, edge: edge, onTap: controller.cycle),
              const SizedBox(height: 18),
              BoardActionRow(
                actions: <BoardAction>[
                  BoardAction(
                    id: 'undo',
                    label: l10n.actionUndo,
                    icon: Icons.undo_rounded,
                    onTap: game.canUndo ? controller.undo : null,
                    unavailableReason: game.isSolved
                        ? l10n.reasonPuzzleDone
                        : l10n.reasonNothingToUndo,
                  ),
                  BoardAction(
                    id: 'erase',
                    label: l10n.actionErase,
                    icon: Icons.backspace_rounded,
                    onTap: game.canErase ? controller.erase : null,
                    unavailableReason: game.isSolved
                        ? l10n.reasonPuzzleDone
                        : l10n.reasonNothingToErase,
                  ),
                  BoardAction(
                    id: 'clear-marks',
                    label: l10n.actionClearMarks,
                    icon: Icons.clear_all_rounded,
                    onTap: game.canClearMarks ? controller.clearMarks : null,
                    unavailableReason: game.isSolved
                        ? l10n.reasonPuzzleDone
                        : l10n.reasonNoMarks,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              StarsLegend(regionCount: game.spec.regionCount),
              const SizedBox(height: 14),
              Text(
                l10n.starsInstruction,
                textAlign: TextAlign.center,
                style: NookType.footnote(colors.inkGhost),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// How many stars are on the board, out of how many it wants.
///
/// The one running count Stars keeps in front of the player: there is no number
/// pad tallying what is left, so this is where they see how far along they are.
class _StarCounter extends StatelessWidget {
  const _StarCounter({required this.placed, required this.target});

  final int placed;
  final int target;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool full = placed == target;

    return Semantics(
      label: l10n.starsCounterLabel(placed, target),
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            Icons.star_rounded,
            size: 18,
            color: full ? colors.sage : colors.clay,
          ),
          const SizedBox(width: 7),
          Text(
            l10n.starsCounter(placed, target),
            style: NookType.rowTitle(full ? colors.sageInk : colors.ink),
          ),
        ],
      ),
    );
  }
}

class _Generating extends StatelessWidget {
  const _Generating();

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircularProgressIndicator(color: colors.clay, strokeWidth: 3),
          const SizedBox(height: 18),
          Text(
            AppLocalizations.of(context).gameGenerating,
            style: NookType.rowSubtitle(colors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _GenerationFailed extends StatelessWidget {
  const _GenerationFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              l10n.gameGenerationFailed,
              textAlign: TextAlign.center,
              style: NookType.title(colors.ink),
            ),
            const SizedBox(height: 18),
            _PrimaryButton(label: l10n.gameTryAgain, onTap: onRetry),
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    return Material(
      color: colors.clay,
      borderRadius: const BorderRadius.all(NookRadius.key),
      child: InkWell(
        borderRadius: const BorderRadius.all(NookRadius.key),
        onTap: onTap,
        child: Container(
          height: kMinTapTarget + 6,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: Text(label, style: NookType.rowTitle(colors.surface)),
        ),
      ),
    );
  }
}
