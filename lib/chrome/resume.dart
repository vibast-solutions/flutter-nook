import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';
import '../store/saved_game.dart';

/// A saved row resolved to what the Continue card needs and how to reopen it.
///
/// The store hands back rows that are game-agnostic — a game id, a tier name and
/// lists of small integers. The home screen must not care which game any of them
/// is: it shows the most recent one it can open and taps back into it. This is
/// the shape it deals in instead, and a [ResumeReader] per game is what turns a
/// row into one. Adding a game is another reader in the list, never another
/// branch in the home screen.
@immutable
class ResumableGame {
  const ResumableGame({
    required this.icon,
    required this.title,
    required this.details,
    required this.semanticLabel,
    required this.openRoute,
  });

  /// The glyph on the card, matching the game's own row.
  final IconData icon;

  /// The first line: which game.
  final String title;

  /// The second line: how long it has been played and how far it has got, in
  /// the player's language.
  final String details;

  /// What a screen reader says in place of the two lines.
  final String semanticLabel;

  /// A route back into the puzzle, built when the card is tapped.
  final Route<void> Function() openRoute;
}

/// Reads a saved row as one game's resumable puzzle, or `null` if it is not that
/// game's — or is one this build cannot open.
typedef ResumeReader = ResumableGame? Function(
  SavedGame save,
  AppLocalizations l10n,
);

/// The most recently played puzzle [readers] can open out of [saves], or `null`.
///
/// [saves] arrive most-recent-first, so the first row any reader resolves is the
/// newest resumable one; a row no reader can read — a game or a build this one
/// does not have — is skipped rather than stopping the search, so a puzzle
/// written by a newer build sits harmlessly in the database.
ResumableGame? mostRecentResumable(
  List<SavedGame>? saves,
  AppLocalizations l10n,
  List<ResumeReader> readers,
) {
  for (final SavedGame save in saves ?? const <SavedGame>[]) {
    for (final ResumeReader reader in readers) {
      final ResumableGame? resumable = reader(save, l10n);
      if (resumable != null) {
        return resumable;
      }
    }
  }
  return null;
}
