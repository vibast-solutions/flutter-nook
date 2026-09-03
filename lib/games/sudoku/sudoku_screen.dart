import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../../board/number_pad.dart';
import '../../board/sudoku_board.dart';
import '../../chrome/action_row.dart';
import '../../chrome/completion_view.dart';
import '../../chrome/difficulty_naming.dart';
import '../../chrome/game_providers.dart';
import '../../chrome/game_header.dart';
import '../../chrome/game_session.dart';
import '../../chrome/play_clock.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../store/nook_database.dart';
import 'sudoku_controller.dart';
import 'sudoku_naming.dart';
import 'sudoku_save.dart';
import 'sudoku_state.dart';
import 'sudoku_variant.dart';

/// How long the hint control waits before offering itself again.
///
/// One number in one place, because it will be retuned by feel rather than
/// calculated. It is not a budget and nothing is counted against it: hints
/// stay unlimited and free, and this is only the room a hint needs to land
/// before the next one is worth asking for.
const Duration kHintPacing = Duration(seconds: 4);

/// The screen a player lands on after picking a Sudoku and a difficulty.
///
/// It owns the scope the game lives in: the variant and the tier are injected
/// here, so the controller below never has to ask which grid it is playing or
/// how hard the player asked for it to be.
class SudokuGamePage extends StatelessWidget {
  const SudokuGamePage({
    required this.variant,
    required this.difficulty,
    this.resume,
    super.key,
  });

  /// Which Sudoku to play.
  final SudokuVariant variant;

  /// How hard the player asked for it to be.
  final PuzzleDifficulty difficulty;

  /// The puzzle to carry on with, or `null` to generate a new one.
  final SudokuSave? resume;

  /// Builds a route to a new puzzle.
  static Route<void> route(SudokuVariant variant, PuzzleDifficulty difficulty) {
    return MaterialPageRoute<void>(
      builder: (BuildContext context) =>
          SudokuGamePage(variant: variant, difficulty: difficulty),
    );
  }

  /// Builds a route back into the puzzle in [save], exactly as it was left.
  static Route<void> resumeRoute(SudokuSave save) {
    return MaterialPageRoute<void>(
      builder: (BuildContext context) => SudokuGamePage(
        variant: save.variant,
        difficulty: save.difficulty,
        resume: save,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final SudokuSave? saved = resume;
    return ProviderScope(
      overrides: [
        sudokuVariantProvider.overrideWithValue(variant),
        sudokuDifficultyProvider.overrideWithValue(difficulty),
        sudokuResumeProvider.overrideWithValue(saved?.game),
        // The game-agnostic identity the shared chrome records against. Sudoku
        // keeps its own variant/difficulty providers for the controller; these
        // are what the completion screen and the solve recorder read.
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
          return GameSession<SudokuGameState>(
            gameProvider: sudokuControllerProvider,
            isSolved: (SudokuGameState game) => game.isSolved,
            wasHinted: (SudokuGameState game) => game.wasHinted,
            writeSave: (SudokuGameState game, Duration elapsed, DateTime at) =>
                store.save(
                  savedGameFor(
                    game,
                    difficulty: difficulty,
                    elapsed: elapsed,
                    at: at,
                  ),
                ),
            discardSave: (SudokuGameState game) =>
                store.discard(game.variant.id),
            child: const _SudokuScreen(),
          );
        },
      ),
    );
  }
}

class _SudokuScreen extends ConsumerWidget {
  const _SudokuScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NookColors colors = Theme.of(context).nook;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final SudokuVariant variant = ref.watch(sudokuVariantProvider);
    final PuzzleDifficulty difficulty = ref.watch(sudokuDifficultyProvider);
    final AsyncValue<SudokuGameState> game = ref.watch(
      sudokuControllerProvider,
    );

    // A finished puzzle takes the whole screen. The board it was played on is
    // complete and has nothing left to do, and the clock in the header has
    // stopped — leaving them up would be leaving the furniture of a game that
    // is over around the one moment the app has to celebrate.
    if (game.value?.isSolved ?? false) {
      return Scaffold(
        backgroundColor: colors.sand,
        body: GameCompletionView(
          gameName: variant.title(l10n),
          tierLabel: difficulty.label(l10n),
          onAnother: () =>
              ref.read(sudokuControllerProvider.notifier).startNewPuzzle(),
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
                      .read(sudokuControllerProvider.notifier)
                      .startNewPuzzle(),
                ),
                data: (SudokuGameState state) => _Playing(game: state),
              ),
            ),
          ],
        ),
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

class _Playing extends ConsumerWidget {
  const _Playing({required this.game});

  final SudokuGameState game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NookColors colors = Theme.of(context).nook;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final SudokuController controller = ref.read(
      sudokuControllerProvider.notifier,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // The designs leave 28 logical pixels either side of the board on a
        // 390-wide phone. On a narrower one that margin is worth more to the
        // grid than to the page — a 9x9's cells are the tightest thing on the
        // screen — so it gives way in proportion rather than holding its
        // ground.
        final double margin = (constraints.maxWidth * 28 / 390).clamp(
          18.0,
          28.0,
        );
        // The board is square and never wider than the screen allows, with a
        // ceiling so a tablet does not turn it into a wall.
        final double edge = (constraints.maxWidth - margin * 2)
            .clamp(120.0, 420.0)
            .toDouble();

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(margin, 6, margin, 24),
          child: Column(
            children: <Widget>[
              SudokuBoard(game: game, edge: edge, onSelect: controller.select),
              const SizedBox(height: 20),
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
                    // The designs draw an eraser; the bundled icon set has no
                    // eraser, and this is the glyph every keyboard already
                    // uses for taking a character back out.
                    label: l10n.actionErase,
                    icon: Icons.backspace_rounded,
                    onTap: game.isSolved ? null : controller.erase,
                    unavailableReason: l10n.reasonPuzzleDone,
                  ),
                  BoardAction(
                    id: 'notes',
                    label: l10n.actionNotes,
                    icon: Icons.edit_rounded,
                    isOn: game.notesMode,
                    onTap: game.isSolved ? null : controller.toggleNotes,
                    unavailableReason: l10n.reasonPuzzleDone,
                  ),
                  BoardAction(
                    id: 'hint',
                    label: l10n.actionHint,
                    icon: Icons.lightbulb_outline_rounded,
                    onTap: game.isSolved ? null : controller.hint,
                    unavailableReason: l10n.reasonPuzzleDone,
                    pacing: kHintPacing,
                    pacedReason: l10n.reasonHintJustGiven,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              NumberPad(
                digits: game.size,
                remaining: game.remaining,
                onDigit: controller.enter,
              ),
              const SizedBox(height: 22),
              Text(
                l10n.gameInstruction,
                style: NookType.footnote(colors.inkGhost),
              ),
            ],
          ),
        );
      },
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
