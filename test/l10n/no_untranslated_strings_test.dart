import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'dart_strings.dart';

/// Every string literal in `lib/` that is not a word a player reads.
///
/// The guard below is deliberately total: **any** string in `lib/` containing
/// a letter has to be on this list, or the build fails. There is no cleverness
/// deciding what looks like copy, because the cleverness is what rots — a
/// caption and an identifier are the same shape (`'done'`, `'undo'`), and no
/// heuristic tells them apart.
///
/// So the cost of the rule is this list, and the list is the point: it is the
/// complete inventory of strings in Nook that are not translated, it is short,
/// and adding to it shows up in a diff next to the reason why. If a word
/// belongs on a screen it belongs in `lib/l10n/app_en.arb` instead.
const Set<String> allowedLiterals = <String>{
  // ---- Widget keys ---------------------------------------------------------
  // Prefixes; the trailing part is interpolated and so not seen here. A key
  // has to be stable across languages or a test would pass by locale.
  'pad-key-',
  'sudoku-cell-',
  'sudoku-value-',
  'sudoku-notes-',
  'sudoku-conflict-',
  'sudoku-pulse-',
  'sudoku-removal-',
  'stars-cell-',
  'stars-mark-',
  'stars-breach-',
  'stars-removal-',
  'board-action-',
  'board-pace-',
  'difficulty-',
  'continue-card',
  // The finished-puzzle screen, whose parts are named one at a time because
  // there are seven of them and no two are built from the same loop.
  'completion-time',
  'completion-previous',
  'completion-solved',
  'completion-personal-best',
  'completion-another',
  'completion-home',
  'completion-close',
  'discard-confirm',
  'discard-keep',

  // ---- Identifiers that outlive a language ---------------------------------
  // Variant ids reach saved games and statistics: a save written on an English
  // phone must still be readable after the player switches language.
  'sudoku-mini',
  'sudoku-light',
  'sudoku-classic',
  'stars',
  // Board-control ids, which key their tiles.
  'undo',
  'erase',
  'notes',
  'hint',
  'clear-marks',
  // Field names a move is written out under when a game is saved.
  'index',
  'before',
  'after',
  'notesBefore',
  'notesAfter',
  'clearedNotes',
  'clearedMarks',
  // The database file, and the name the generated row class is given so that
  // it does not collide with the type the app passes around.
  'nook.sqlite',
  'SavedGameRow',
  'GameStatsRow',

  // ---- Typography ----------------------------------------------------------
  // Font families, matching the `family:` keys in pubspec.yaml. Translating
  // one would unbundle the font.
  'Nunito',
  'Fredoka',
  // The OpenType weight axis tag. Four bytes defined by the font format.
  'wght',

  // ---- Riverpod provider names ---------------------------------------------
  // Debug names, shown in the inspector and in provider errors.
  'sudokuVariant',
  'sudokuDifficulty',
  'sudokuPuzzleSource',
  'sudokuSeedSource',
  'sudokuController',
  'sudokuResume',
  'starsVariant',
  'starsDifficulty',
  'starsPuzzleSource',
  'starsSeedSource',
  'starsController',
  'starsResume',
  'gameId',
  'gameDifficulty',
  'now',
  'resumedElapsed',
  'playClock',
  'nookDatabase',
  'savedGameStore',
  'savedGames',
  'gameStatsStore',
  'gameStats',
  'solveOutcome',

  // ---- Messages for whoever is holding the debugger ------------------------
  // `toString` output.
  'BoardMove(index: , before: , after: , ',
  'notesBefore: , notesAfter: , ',
  'clearedNotes: , clearedMarks: )',
  'HintRemoval( at )',
  'StarRemoval(star at )',
  'NoteMarks()',
  'SudokuVariant()',
  'StarsVariant()',
  // Assertions. These fire during development and never reach a player.
  'sudokuVariantProvider must be overridden by the game screen.',
  'sudokuDifficultyProvider must be overridden by the game screen.',
  'starsVariantProvider must be overridden by the game screen.',
  'starsDifficultyProvider must be overridden by the game screen.',
  'gameIdProvider must be overridden by the game screen.',
  'gameDifficultyProvider must be overridden by the game screen.',
  'A history has to be able to hold a move.',
  // How a failed save is filed when one is reported.
  'nook',
  'saving a puzzle in progress',
};

/// Files under `lib/` the guard does not read.
///
/// The localisations, because the `.arb` and the class generated from it are
/// where the words are supposed to be; and generated code, because nobody
/// writes it — its strings are column names and SQL, and the way to change one
/// is to change the table it came from.
bool isExempt(String path) =>
    path.startsWith('lib/l10n/') || path.endsWith('.g.dart');

/// Whether [text] may stay in the source as it is.
bool isAllowed(String text) =>
    !RegExp(r'[A-Za-z]').hasMatch(text) || allowedLiterals.contains(text);

/// Every string in `lib/` that ought to have been a translated message.
List<String> untranslatedLiterals(Directory lib) {
  final List<String> offenders = <String>[];
  final List<File> files =
      lib
          .listSync(recursive: true)
          .whereType<File>()
          .where((File f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));

  for (final File file in files) {
    final String path = file.path.replaceAll(r'\', '/');
    if (isExempt(path)) {
      continue;
    }
    for (final DartStringLiteral literal in findStringLiterals(
      file.readAsStringSync(),
    )) {
      if (!isAllowed(literal.text)) {
        offenders.add('$path:${literal.line}  "${literal.text}"');
      }
    }
  }
  return offenders;
}

void main() {
  test('no player-facing string is written into a widget', () {
    final Directory lib = Directory('lib');
    expect(
      lib.existsSync(),
      isTrue,
      reason: 'run this from the package root, where lib/ is',
    );

    expect(
      untranslatedLiterals(lib),
      isEmpty,
      reason:
          'Each of these is a string in lib/ that is neither a translated '
          'message nor on the allowedLiterals list above. If a player can '
          'read it, put it in lib/l10n/app_en.arb, run `flutter gen-l10n`, '
          'and read it back through AppLocalizations.of(context). If nobody '
          'can, add it to the list with a line saying why.',
    );
  });

  group('the guard itself', () {
    test('would still catch the strings this app used to contain', () {
      // If these ever stopped being caught the guard would be decorative, so
      // the words that were literals before this change are asserted rather
      // than assumed. Every one of them is now a message in app_en.arb.
      for (final String copy in <String>[
        'Solved',
        'Tap a cell, then a number',
        'done',
        'Nook',
        'Stars',
        'ALL GAMES',
        'the puzzle is done',
        'Row , column , empty',
        ' left',
      ]) {
        expect(
          isAllowed(copy),
          isFalse,
          reason: '"$copy" would slip past the guard',
        );
      }
    });

    test('lets keys, ids and punctuation through', () {
      for (final String kept in <String>[
        'sudoku-mini',
        'board-action-',
        'undo',
        '',
        '()',
        ' · ',
      ]) {
        expect(isAllowed(kept), isTrue, reason: '"$kept" should be allowed');
      }
    });

    test('reads through comments and interpolation', () {
      final List<DartStringLiteral> found = findStringLiterals('''
// 'not a string, a comment'
/* 'nor this' */
const String key = 'pad-key-\$digit';
const String label = 'Row \${row + 1}, column \${column + 1}';
''');
      expect(found.map((DartStringLiteral l) => l.text), <String>[
        'pad-key-',
        'Row , column ',
      ]);
    });

    test('skips import directives but not ordinary strings', () {
      final List<DartStringLiteral> found = findStringLiterals('''
import 'package:flutter/material.dart';
export 'src/thing.dart';
const String a = 'package:not/a/directive.dart';
''');
      expect(found.map((DartStringLiteral l) => l.text), <String>[
        'package:not/a/directive.dart',
      ]);
    });

    test('handles raw and triple-quoted strings', () {
      final List<DartStringLiteral> found = findStringLiterals(r"""
const String a = r'raw $notInterpolated';
const String b = '''triple quoted''';
const String c = 'an \' escaped quote';
""");
      expect(found.map((DartStringLiteral l) => l.text), <String>[
        r'raw $notInterpolated',
        'triple quoted',
        'an _ escaped quote',
      ]);
    });

    test('the allowlist has nothing stale on it', () {
      // A list nobody prunes is a list that stops meaning anything. Every
      // entry has to correspond to a string that is actually in lib/.
      final Set<String> present = <String>{};
      for (final File file
          in Directory('lib')
              .listSync(recursive: true)
              .whereType<File>()
              .where((File f) => f.path.endsWith('.dart'))) {
        if (isExempt(file.path.replaceAll(r'\', '/'))) {
          continue;
        }
        present.addAll(
          findStringLiterals(file.readAsStringSync())
              .map((DartStringLiteral l) => l.text),
        );
      }
      expect(
        allowedLiterals.difference(present),
        isEmpty,
        reason: 'these are allowed but no longer appear in lib/ — delete them',
      );
    });
  });
}
