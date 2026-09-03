import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../../board/duo_board.dart';
import '../../chrome/action_row.dart';
import '../../chrome/completion_view.dart';
import '../../chrome/difficulty_naming.dart';
import '../../chrome/game_header.dart';
import '../../chrome/game_providers.dart';
import '../../chrome/game_session.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../l10n/app_localizations.dart';
import 'duo_controller.dart';
import 'duo_naming.dart';
import 'duo_state.dart';
import 'duo_variant.dart';

/// The screen a player lands on after choosing Duo.
///
/// It owns the scope the game lives in: the variant and the tier are injected
/// here, so the controller below never has to ask which board it is playing. The
/// session it opens keeps the clock and records a solve. Duo does not save yet —
/// that is VIB-96 — so it passes the session no save callbacks and is a
/// clock-only session, exactly as Stars was before it saved.
class DuoGamePage extends StatelessWidget {
  const DuoGamePage({
    required this.variant,
    required this.difficulty,
    super.key,
  });

  /// Which Duo board to play.
  final DuoVariant variant;

  /// How hard the player asked for it to be.
  final PuzzleDifficulty difficulty;

  /// Builds a route to a new puzzle.
  static Route<void> route(DuoVariant variant, PuzzleDifficulty difficulty) {
    return MaterialPageRoute<void>(
      builder: (BuildContext context) =>
          DuoGamePage(variant: variant, difficulty: difficulty),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        duoVariantProvider.overrideWithValue(variant),
        duoDifficultyProvider.overrideWithValue(difficulty),
        gameIdProvider.overrideWithValue(variant.id),
        gameDifficultyProvider.overrideWithValue(difficulty),
      ],
      child: GameSession<DuoGameState>(
        gameProvider: duoControllerProvider,
        isSolved: (DuoGameState game) => game.isSolved,
        wasHinted: (DuoGameState game) => game.wasHinted,
        child: const _DuoScreen(),
      ),
    );
  }
}

class _DuoScreen extends ConsumerWidget {
  const _DuoScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NookColors colors = Theme.of(context).nook;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DuoVariant variant = ref.watch(duoVariantProvider);
    final PuzzleDifficulty difficulty = ref.watch(duoDifficultyProvider);
    final AsyncValue<DuoGameState> game = ref.watch(duoControllerProvider);

    if (game.value?.isSolved ?? false) {
      return Scaffold(
        backgroundColor: colors.sand,
        body: GameCompletionView(
          gameName: variant.title(l10n),
          tierLabel: difficulty.label(l10n),
          onAnother: () =>
              ref.read(duoControllerProvider.notifier).startNewPuzzle(),
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
                  onRetry: () =>
                      ref.read(duoControllerProvider.notifier).startNewPuzzle(),
                ),
                data: (DuoGameState state) => _Playing(game: state),
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

  final DuoGameState game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NookColors colors = Theme.of(context).nook;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DuoController controller = ref.read(duoControllerProvider.notifier);

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
          padding: EdgeInsets.fromLTRB(margin, 10, margin, 24),
          child: Column(
            children: <Widget>[
              DuoBoard(game: game, edge: edge, onTap: controller.cycle),
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
                ],
              ),
              const SizedBox(height: 18),
              const DuoLegend(),
              const SizedBox(height: 14),
              Text(
                l10n.duoInstruction,
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
