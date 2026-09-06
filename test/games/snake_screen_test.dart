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

  group('pause and lifecycle', () {
    testWidgets('the pause control stops the loop, and resuming restarts it', (
      WidgetTester tester,
    ) async {
      await _pumpSnake(tester);
      await _start(tester);
      await tester.pump(testSpeed.tick);

      // Pause: the panel comes up and the pause control gives way.
      await tester.tap(find.bySemanticsLabel(en.snakePause));
      await tester.pump();
      expect(find.text(en.snakePaused), findsOneWidget);
      expect(find.bySemanticsLabel(en.snakePause), findsNothing);

      // The loop is verifiably stopped: many ticks pass and the head holds still.
      final Offset held = _head(tester);
      await tester.pump(testSpeed.tick * 10);
      expect(_head(tester), held, reason: 'a paused snake does not move');

      // Resume: a countdown runs, decorated on its way (motion is on here).
      await tester.tap(find.text(en.snakeResume));
      await tester.pump();
      expect(find.text('3'), findsOneWidget);
      expect(find.byType(AnimatedSwitcher), findsOneWidget);
      await _runCountdown(tester);

      // Live again: the next tick advances the snake.
      expect(find.text(en.snakePaused), findsNothing);
      final Offset before = _head(tester);
      await tester.pump(testSpeed.tick);
      expect(_head(tester).dx, greaterThan(before.dx));

      await _teardown(tester);
    });

    testWidgets('backgrounding pauses with no death, foreground resumes', (
      WidgetTester tester,
    ) async {
      await _pumpSnake(tester);
      await _start(tester);

      // Point the snake at the top wall and take one step toward it.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump(testSpeed.tick);

      // Send the app away before it could reach the wall.
      await _background(tester);
      expect(find.text(en.snakePaused), findsOneWidget);

      // Far longer than a run into the wall would take: still alive, still still.
      final Offset whileAway = _head(tester);
      await tester.pump(testSpeed.tick * 100);
      expect(
        find.byKey(gameOverKey),
        findsNothing,
        reason: 'the snake cannot die while the app is backgrounded',
      );
      expect(_head(tester), whileAway, reason: 'nothing moved while away');

      // Returning resumes via a countdown, not straight back into motion.
      await _foreground(tester);
      expect(find.text('3'), findsOneWidget);
      await _runCountdown(tester);

      final Offset before = _head(tester);
      await tester.pump(testSpeed.tick);
      expect(
        _head(tester).dy,
        lessThan(before.dy),
        reason: 'the run carries on where it left off, heading up',
      );

      await _teardown(tester);
    });

    testWidgets(
      'with reduced motion the countdown flourish is gone but play is not',
      (WidgetTester tester) async {
        await _pumpSnake(tester, reduceMotion: true);
        await _start(tester);
        await tester.pump(testSpeed.tick);

        await tester.tap(find.bySemanticsLabel(en.snakePause));
        await tester.pump();
        await tester.tap(find.text(en.snakeResume));
        await tester.pump();

        // The count is shown — it is the message — but it does not animate.
        expect(find.text('3'), findsOneWidget);
        expect(
          find.byType(AnimatedSwitcher),
          findsNothing,
          reason: 'the countdown pop is decoration and is dropped',
        );

        // And the game is fully playable: it counts down and then steers.
        await _runCountdown(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        final Offset before = _head(tester);
        await tester.pump(testSpeed.tick);
        expect(_head(tester).dy, lessThan(before.dy));

        await _teardown(tester);
      },
    );
  });

  group('accessibility', () {
    testWidgets('the board speaks its score and length, then the final score', (
      WidgetTester tester,
    ) async {
      await _pumpSnake(tester);
      await _start(tester);

      // The field is one live region (the board rule's documented exception): as
      // the run begins it speaks the score and the snake's length, in arb words.
      expect(
        find.bySemanticsLabel(en.snakeProgressAnnouncement(0, 3)),
        findsOneWidget,
      );

      await _crashIntoWall(tester);

      // On death the same region gives the run's final score in words — nothing
      // rides on the game-over card's colour or motion alone.
      expect(
        find.bySemanticsLabel(en.snakeGameOverAnnouncement(0)),
        findsOneWidget,
      );

      await _teardown(tester);
    });

    testWidgets('the d-pad plays a whole run, no swipe needed', (
      WidgetTester tester,
    ) async {
      await _pumpSnake(tester);

      // Starting the run by pressing the d-pad — no board tap, no swipe.
      await tester.tap(find.bySemanticsLabel(en.snakeSteerUp));
      await tester.pump();
      expect(
        find.text(en.snakeStartCta),
        findsNothing,
        reason: 'a d-pad press begins the run, like a key press',
      );

      // Steering up with the d-pad turns the snake up.
      await tester.tap(find.bySemanticsLabel(en.snakeSteerUp));
      final Offset before = _head(tester);
      await tester.pump(testSpeed.tick);
      expect(_head(tester).dy, lessThan(before.dy));

      // And the run plays out to its end under the d-pad alone: heading up, it
      // runs into the top wall and the game-over card appears.
      for (int i = 0; i < 40 && !tester.any(find.byKey(gameOverKey)); i++) {
        await tester.pump(testSpeed.tick);
      }
      expect(find.byKey(gameOverKey), findsOneWidget);
      await tester.pumpAndSettle();

      await _teardown(tester);
    });

    testWidgets('every d-pad button clears the minimum tap target', (
      WidgetTester tester,
    ) async {
      await _pumpSnake(tester);

      for (final String direction in <String>['up', 'down', 'left', 'right']) {
        final Size size = tester.getSize(
          find.byKey(ValueKey<String>('snake-dpad-$direction')),
        );
        expect(
          size.width,
          greaterThanOrEqualTo(kMinTapTarget),
          reason: 'the $direction button is too narrow to hit',
        );
        expect(
          size.height,
          greaterThanOrEqualTo(kMinTapTarget),
          reason: 'the $direction button is too short to hit',
        );
      }

      await _teardown(tester);
    });

    testWidgets('with reduced motion the d-pad still plays', (
      WidgetTester tester,
    ) async {
      await _pumpSnake(tester, reduceMotion: true);

      // Start and steer with the d-pad — the game is fully playable with motion
      // stripped; the buttons just give up their ripple.
      await tester.tap(find.bySemanticsLabel(en.snakeSteerUp));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel(en.snakeSteerUp));
      final Offset before = _head(tester);
      await tester.pump(testSpeed.tick);
      expect(_head(tester).dy, lessThan(before.dy));

      await _teardown(tester);
    });
  });

  group('the best score', () {
    testWidgets(
      'a first run sets the best and is announced in words and a haptic',
      (WidgetTester tester) async {
        final List<MethodCall> haptics = _captureHaptics(tester);
        final NookDatabase database = memoryDatabase();
        await _pumpSnake(tester, database: database);
        await _start(tester);

        await _crashIntoWall(tester);

        // The card is up, and the run's own score is on it.
        final Finder card = find.byKey(gameOverKey);
        expect(card, findsOneWidget);
        expect(
          find.descendant(of: card, matching: find.textContaining('Score')),
          findsOneWidget,
        );
        // First run at this speed, so any score is a new best — said in words...
        expect(
          find.descendant(of: card, matching: find.text(en.snakeNewBest)),
          findsOneWidget,
        );
        // ...and felt as a single tap.
        expect(haptics, isNotEmpty, reason: 'a new best should buzz');

        // And it is on disk: the level's best is this run's score.
        final int? stored = await tester.runAsync<int?>(
          () => SnakeScoreStore(database).bestFor(testSpeed.level),
        );
        expect(
          stored,
          0,
          reason: 'a run into the wall scores nothing, but it is a best',
        );

        await _teardown(tester);
      },
    );

    testWidgets(
      'a run that falls short shows the standing best, and no new best',
      (WidgetTester tester) async {
        // A best already stands at this speed, higher than a run into the wall.
        final NookDatabase database = memoryDatabase();
        await tester.runAsync(
          () => SnakeScoreStore(database).record(
            level: testSpeed.level,
            score: 6,
            at: DateTime.utc(2026, 9, 6),
          ),
        );
        final List<MethodCall> haptics = _captureHaptics(tester);
        await _pumpSnake(tester, database: database);
        await _start(tester);

        await _crashIntoWall(tester);

        final Finder card = find.byKey(gameOverKey);
        expect(card, findsOneWidget);
        // The best it was chasing is shown; no "New best!" and no buzz.
        expect(
          find.descendant(of: card, matching: find.text(en.snakeBest(6))),
          findsOneWidget,
        );
        expect(
          find.descendant(of: card, matching: find.text(en.snakeNewBest)),
          findsNothing,
        );
        expect(
          haptics,
          isEmpty,
          reason: 'a run that fell short should not buzz',
        );

        // The stored best is untouched.
        final int? stored = await tester.runAsync<int?>(
          () => SnakeScoreStore(database).bestFor(testSpeed.level),
        );
        expect(stored, 6);

        await _teardown(tester);
      },
    );
  });
}

/// Sends the app to the background, through the states the platform would.
Future<void> _background(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  await tester.pump();
}

/// Brings the app back to the foreground, through the states the platform would.
Future<void> _foreground(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
}

/// Runs the resume countdown to its end, so play is live again afterwards.
Future<void> _runCountdown(WidgetTester tester) async {
  for (int i = 0; i < 3; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

/// Captures the platform haptic calls the screen makes, so a test can say
/// whether a new best buzzed.
List<MethodCall> _captureHaptics(WidgetTester tester) {
  final List<MethodCall> calls = <MethodCall>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add(call);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return calls;
}

/// Turns the snake into the top wall and runs the loop until it dies, so the
/// game-over card and the recorded score are there to inspect.
Future<void> _crashIntoWall(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
  for (int i = 0; i < 40 && !tester.any(find.byKey(gameOverKey)); i++) {
    await tester.pump(testSpeed.tick);
  }
  // Let the score write land, so the card's best line and the store are settled.
  await tester.pumpAndSettle();
}

/// Pumps the Snake screen with a fixed seed, so a run is reproducible.
///
/// Wired to a database in memory, because the screen records its score against
/// one when a run ends; a test that cares about the score passes its own so it
/// can read the best back.
Future<void> _pumpSnake(
  WidgetTester tester, {
  int seed = 123,
  NookDatabase? database,
  bool reduceMotion = false,
}) async {
  await setPhoneSurface(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        nookDatabaseProvider.overrideWithValue(database ?? memoryDatabase()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildNookTheme(NookColors.softClay),
        home: reduceMotion
            ? Builder(
                builder: (BuildContext context) => MediaQuery(
                  // The player has asked for reduced motion: decoration must go,
                  // the game must not.
                  data: MediaQuery.of(context)
                      .copyWith(disableAnimations: true),
                  child: SnakeGamePage(
                    variant: SnakeVariant.standard,
                    speed: testSpeed,
                    seed: seed,
                  ),
                ),
              )
            : SnakeGamePage(
                variant: SnakeVariant.standard,
                speed: testSpeed,
                seed: seed,
              ),
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
