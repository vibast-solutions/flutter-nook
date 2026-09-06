import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../l10n/app_localizations.dart';

/// One game's rules, as the "How it's played" sheet shows them.
///
/// The whole of what makes the sheet game-agnostic: a game hands over its aim,
/// how a player works the board, and the very same legend widget the board
/// draws beneath itself — and the sheet renders those three the same way for
/// every game. Adding a game is another of these, built in the game's own
/// `*_rules.dart` beside its naming, never a branch grown in the sheet. It is
/// the [ResumeReader] idea again: a game describes itself, the shared chrome
/// draws it.
@immutable
class RulesSheetContent {
  const RulesSheetContent({
    required this.title,
    required this.objective,
    required this.interaction,
    this.legend,
  });

  /// The game's name, over the top of the sheet.
  final String title;

  /// What the player is trying to do, in a sentence or two.
  final String objective;

  /// How they interact with the board: what a tap does, and how to undo it.
  final String interaction;

  /// The game's own legend, the same widget it shows under the board, or `null`
  /// for a game whose only symbols are the numbers already in the aim (Sudoku).
  final Widget? legend;
}

/// Opens the "How it's played" sheet for [content].
///
/// A bottom-anchored panel rather than a centred dialog: it reads as something
/// pulled up over the game and pushed back down, and it can be as tall as the
/// rules need without fighting the board underneath. Dismissible every way a
/// sheet should be — the scrim, the back gesture, and its own close button.
///
/// Motion is optional: the slide up is skipped when the player has asked for
/// reduced motion, and the panel simply appears. What a screen reader is told
/// does not depend on that — the route is named either way.
Future<void> showHowToPlay(
  BuildContext context, {
  required RulesSheetContent content,
}) {
  final NookColors colors = Theme.of(context).nook;
  final AppLocalizations l10n = AppLocalizations.of(context);
  final bool reduceMotion = MediaQuery.of(context).disableAnimations;

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: l10n.howToPlayClose,
    // The same warm scrim a dialog draws, taken from a token rather than a
    // literal so it moves with the theme.
    barrierColor: colors.ink.withValues(alpha: 0.45),
    transitionDuration: reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 240),
    pageBuilder: (BuildContext context, _, _) => Align(
      alignment: Alignment.bottomCenter,
      child: HowToPlaySheet(content: content),
    ),
    transitionBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondary,
          Widget child,
        ) {
          if (reduceMotion) {
            return child;
          }
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          );
        },
  );
}

/// The panel [showHowToPlay] slides up: the game's name, its aim, how you play
/// it, and — where the game has one — its key.
///
/// It scrolls inside a ceiling of most of the screen, so the longest set of
/// rules stays reachable on the shortest phone and the shortest set does not
/// stretch a panel to fill space it does not need.
class HowToPlaySheet extends StatelessWidget {
  const HowToPlaySheet({required this.content, super.key});

  final RulesSheetContent content;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final double maxHeight = MediaQuery.of(context).size.height * 0.82;

    return Semantics(
      // Named as a route so a screen reader announces the sheet as it opens and
      // returns focus to the game as it closes.
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: l10n.howToPlayHeading,
      child: Material(
        color: colors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: NookRadius.card),
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _Grabber(color: colors.line),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 2, 10, 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              l10n.howToPlayHeading,
                              style: NookType.sectionLabel(colors.inkFaint),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              content.title,
                              style: NookType.title(colors.ink),
                            ),
                          ],
                        ),
                      ),
                      _CloseButton(
                        semanticLabel: l10n.howToPlayClose,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 6, 22, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _Section(
                          label: l10n.howToPlayAimLabel,
                          body: content.objective,
                        ),
                        const SizedBox(height: 16),
                        _Section(
                          label: l10n.howToPlayHowLabel,
                          body: content.interaction,
                        ),
                        if (content.legend != null) ...<Widget>[
                          const SizedBox(height: 18),
                          Text(
                            l10n.howToPlayKeyLabel,
                            style: NookType.sectionLabel(colors.inkFaint),
                          ),
                          const SizedBox(height: 12),
                          // The legends centre themselves; a full-width box lets
                          // them sit the way they do under the board.
                          SizedBox(
                            width: double.infinity,
                            child: content.legend,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A short heading and the paragraph under it — the aim, or how to play.
class _Section extends StatelessWidget {
  const _Section({required this.label, required this.body});

  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: NookType.sectionLabel(colors.inkFaint)),
        const SizedBox(height: 6),
        Text(body, style: NookType.rowSubtitle(colors.inkMuted)),
      ],
    );
  }
}

/// The little bar at the top of the sheet that says it can be dragged down.
///
/// Purely decorative — nothing to read out or hit — so it is hidden from the
/// screen reader, which reaches the close button and the scrim instead.
class _Grabber extends StatelessWidget {
  const _Grabber({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.all(Radius.circular(2)),
        ),
      ),
    );
  }
}

/// The button that closes the sheet, matching the header's icon tiles.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.semanticLabel, required this.onTap});

  final String semanticLabel;
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
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: kMinTapTarget,
            height: kMinTapTarget,
            child: Icon(Icons.close_rounded, size: 20, color: colors.inkMuted),
          ),
        ),
      ),
    );
  }
}
