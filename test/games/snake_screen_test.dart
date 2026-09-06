import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/board/snake_board.dart';
import 'package:nook/chrome/play_clock.dart';
import 'package:nook/design/theme.dart';
import 'package:nook/design/tokens.dart';
import 'package:nook/games/snake/snake_screen.dart';
import 'package:nook/games/snake/snake_variant.dart';
import 'package:nook/home/home_screen.dart';
import 'package:nook/l10n/app_localizations.dart';
import 'package:nook/store/nook_database.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../support/duo_fixture.dart';

/// The key the game-over card carries, matched by value so the test does not
/// reach into a private widget.
const Key gameOverKey = ValueKey<String>('snake-game-over');

/// The speed a run is pumped at. The default pace; its `tick` is the interval a
/// test advances the clock by, so any level would do.
const SnakeSpeed testSpeed = SnakeSpeed.standard;

void main() {
  group('the home screen', () {
    testWidgets('lists Snake and opens its rules', (WidgetTester tester) async {
      await setPhoneSurface(tester);
      await tester.pumpWidget(_home(memoryDatabase(), TestClock()));
      await tester.pumpAndSettle();

      expect(find.text(en.snakeSubtitle), findsOneWidget);
      expect(
        find.bySemanticsLabel(en.gameRowUnavailableLabel(en.snakeTitle)),
        findsNothing,
      );

      // Holding the row opens "How it's played", which reads the aim back.
      await tester.longPress(find.text(en.snakeSubtitle));
      await tester.pumpAndSettle();
      expect(find.text(en.snakeRulesObjective), findsOneWidget);
    });
  });

  group('a run', () {
    testWidgets('starts on a tap and advances one cell per tick', (
      WidgetTester tester,
    ) async {
      await _pumpSnake(tester);

      // Before the first move the invitation is up.
      expect(find.text(en.snakeStartCta), findsWidgets);

      await _start(tester);
      final Offset before = _head(tester);
      await tester.pump(testSpeed.tick);
      final Offset after = _head(tester);

      // The snake starts heading right, so one tick moves the head one cell to
      // the right and not vertically.
      expect(after.dx, greaterThan(before.dx));
      expect(after.dy, moreOrLessEquals(before.dy, epsilon: 0.01));

      await _teardown(tester);
    });

    testWidgets('the arrow keys steer the snake', (WidgetTester tester) async {
      await _pumpSnake(tester);
      await _start(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      final Offset before = _head(tester);
      await tester.pump(testSpeed.tick);
      final Offset after = _head(tester);

      expect(after.dy, lessThan(before.dy));
      expect(after.dx, moreOrLessEquals(before.dx, epsilon: 0.01));

      await _teardown(tester);
    });

    testWidgets('a swipe steers the snake', (WidgetTester tester) async {
      await _pumpSnake(tester);
      await _start(tester);

      // A swipe up over the board.
      await tester.drag(find.byType(SnakeBoard), const Offset(0, -80));
      final Offset before = _head(tester);
      await tester.pump(testSpeed.tick);
      final Offset after = _head(tester);

      expect(after.dy, lessThan(before.dy));

      await _teardown(tester);
    });

    testWidgets('a reversal is ignored, never an instant death', (
      WidgetTester tester,
    ) async {
      await _pumpSnake(tester);
      await _start(tester);

      // Heading right; asking to go left is a straight reversal.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      final Offset before = _head(tester);
      await tester.pump(testSpeed.tick);
      final Offset after = _head(tester);

      // Still alive, still going right.
      expect(find.byKey(gameOverKey), findsNothing);
      expect(after.dx, greaterThan(before.dx));

      await _teardown(tester);
    });

    testWidgets('a crash shows the game-over card, and Play again resets', (
      WidgetTester tester,
    ) async {
      await _pumpSnake(tester);
      await _start(tester);
      final Offset startHead = _head(tester);

      // Turn into the top wall and run until the snake dies.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      for (int i = 0; i < 40 && !tester.any(find.byKey(gameOverKey)); i++) {
        await tester.pump(testSpeed.tick);
      }

      final Finder card = find.byKey(gameOverKey);
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text(en.snakeGameOver)),
        findsOneWidget,
      );
      // The card carries the score (its label, whatever the run reached).
      expect(
        find.descendant(of: card, matching: find.textContaining('Score')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text(en.snakeRestart)),
        findsOneWidget,
      );

      // Play again clears the card and puts the snake back where it began.
      await tester.tap(find.text(en.snakeRestart));
      await tester.pump();
      expect(find.byKey(gameOverKey), findsNothing);
      expect(_head(tester), startHead);

      // And it is a live run again: the next tick advances the snake.
      await tester.pump(testSpeed.tick);
      expect(_head(tester).dx, greaterThan(startHead.dx));

      await _teardown(tester);
    });
  });
}

/// Pumps the Snake screen with a fixed seed, so a run is reproducible.
Future<void> _pumpSnake(WidgetTester tester, {int seed = 123}) async {
  await setPhoneSurface(tester);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildNookTheme(NookColors.softClay),
      home: SnakeGamePage(
        variant: SnakeVariant.standard,
        speed: testSpeed,
        seed: seed,
      ),
    ),
  );
  // Let autofocus take, so the keyboard tests reach the Focus node.
  await tester.pump();
}

/// The home screen wired to an empty database and a clock the test owns.
Widget _home(NookDatabase database, TestClock clock) {
  return ProviderScope(
    overrides: [
      nookDatabaseProvider.overrideWithValue(database),
      nowProvider.overrideWithValue(clock.call),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildNookTheme(NookColors.softClay),
      home: const HomeScreen(),
    ),
  );
}

/// Starts the run by tapping the board away from the centred overlay panel.
Future<void> _start(WidgetTester tester) async {
  final Offset corner = tester.getTopLeft(find.byType(SnakeBoard));
  await tester.tapAt(corner + const Offset(6, 6));
  await tester.pump();
}

/// The head cell's top-left, for watching it move.
Offset _head(WidgetTester tester) =>
    tester.getTopLeft(find.byKey(SnakeBoard.headKey));

/// Tears the screen down so its loop timer is cancelled before the test ends.
Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
}
