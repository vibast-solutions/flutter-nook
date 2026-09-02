import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../../board/number_pad.dart';
import '../../board/sudoku_board.dart';
import '../../chrome/action_row.dart';
import '../../chrome/play_clock.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../l10n/app_localizations.dart';
import 'sudoku_controller.dart';
import 'sudoku_naming.dart';
import 'sudoku_save.dart';
import 'sudoku_session.dart';
import 'sudoku_state.dart';
import 'sudoku_variant.dart';

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
  final SudokuDifficulty difficulty;

  /// The puzzle to carry on with, or `null` to generate a new one.
  final SudokuSave? resume;

  /// Builds a route to a new puzzle.
  static Route<void> route(SudokuVariant variant, SudokuDifficulty difficulty) {
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
        resumedElapsedProvider.overrideWithValue(
          saved?.elapsed ?? Duration.zero,
        ),
      ],
      child: SudokuSession(
        difficulty: difficulty,
        child: const _SudokuScreen(),
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
    final SudokuDifficulty difficulty = ref.watch(sudokuDifficultyProvider);
    final AsyncValue<SudokuGameState> game = ref.watch(
      sudokuControllerProvider,
    );

    return Scaffold(
      backgroundColor: colors.sand,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _Header(
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

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
      child: Row(
        children: <Widget>[
          _IconButtonTile(
            semanticLabel: AppLocalizations.of(context).backToGameList,
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Column(
              children: <Widget>[
                Text(title, style: NookType.title(colors.ink)),
                const SizedBox(height: 1),
                Text(subtitle, style: NookType.sectionLabel(colors.inkFaint)),
              ],
            ),
          ),
          const _Clock(),
        ],
      ),
    );
  }
}

/// How long this puzzle has been played for.
///
/// Sits where the designs put it, opposite the back button, and is wide enough
/// to keep the title centred as the digits change — a clock that shoved the
/// game's name sideways every time it ticked would be worse than no clock.
class _Clock extends ConsumerWidget {
  const _Clock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NookColors colors = Theme.of(context).nook;
    final Duration elapsed = ref.watch(playClockProvider);
    final String reading = clockReading(elapsed);

    return Semantics(
      label: AppLocalizations.of(context).gameElapsedLabel(reading),
      excludeSemantics: true,
      child: SizedBox(
        width: kMinTapTarget + 14,
        child: Text(
          reading,
          textAlign: TextAlign.end,
          style: NookType.sectionLabel(colors.inkMuted),
        ),
      ),
    );
  }
}

class _IconButtonTile extends StatelessWidget {
  const _IconButtonTile({
    required this.semanticLabel,
    required this.icon,
    required this.onTap,
  });

  final String semanticLabel;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    return Semantics(
      label: semanticLabel,
      button: true,
      excludeSemantics: true,
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(NookRadius.tile),
          side: BorderSide(color: colors.line),
        ),
        child: InkWell(
          borderRadius: const BorderRadius.all(NookRadius.tile),
          onTap: onTap,
          child: SizedBox(
            width: kMinTapTarget,
            height: kMinTapTarget,
            child: Icon(icon, size: 18, color: colors.inkMuted),
          ),
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
                  // The hint (VIB-76) joins this row.
                ],
              ),
              const SizedBox(height: 14),
              NumberPad(
                digits: game.size,
                remaining: game.remaining,
                onDigit: controller.enter,
              ),
              const SizedBox(height: 22),
              if (game.isSolved)
                _Solved(onNewPuzzle: controller.startNewPuzzle)
              else
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

/// What the player sees on finishing.
///
/// The medallion, the times and the streak in the designs need a clock and a
/// history to be honest about; both arrive with statistics (VIB-77). Until
/// then this says the true thing and nothing more.
class _Solved extends StatelessWidget {
  const _Solved({required this.onNewPuzzle});

  final VoidCallback onNewPuzzle;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.sageSoft,
          border: Border.all(color: colors.sageLine),
          borderRadius: const BorderRadius.all(NookRadius.card),
        ),
        child: Column(
          children: <Widget>[
            Icon(Icons.check_rounded, size: 34, color: colors.sage),
            const SizedBox(height: 8),
            Text(l10n.gameSolved, style: NookType.title(colors.sageInk)),
            const SizedBox(height: 16),
            _PrimaryButton(label: l10n.gameNewPuzzle, onTap: onNewPuzzle),
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
