import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/design/theme.dart';
import 'package:nook/design/tokens.dart';
import 'package:nook/games/snake/snake_screen.dart';
import 'package:nook/games/snake/snake_speed.dart';
import 'package:nook/games/snake/snake_variant.dart';
import 'package:nook/l10n/app_localizations.dart';
import 'package:nook/store/nook_database.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../support/duo_fixture.dart';

/// Pumps the speed picker straight onto its own page.
///
/// Wired to a database in memory, because the picker reads each level's best
/// score out of one; a test that wants a row to show a best passes its own with
/// a score already recorded.
Future<void> _pumpPicker(WidgetTester tester, {NookDatabase? database}) async {
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
        home: const SnakeSpeedPage(variant: SnakeVariant.standard),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The speed the [SnakeGamePage] that was pushed carries, or `null` if none was.
SnakeSpeed? _openedSpeed(WidgetTester tester) {
  final Finder game = find.byType(SnakeGamePage);
  if (game.evaluate().isEmpty) {
    return null;
  }
  return tester.widget<SnakeGamePage>(game).speed;
}

void main() {
  group('choosing a Snake speed', () {
    testWidgets('the home screen opens the speed picker', (
      WidgetTester tester,
    ) async {
      await pumpDuoHome(tester);
      await tester.tap(find.text(en.snakeTitle));
      await tester.pumpAndSettle();

      expect(find.byType(SnakeSpeedPage), findsOneWidget);
      // Every level has a row, found by its stable key rather than its label.
      for (final SnakeSpeed speed in SnakeSpeed.values) {
        expect(
          find.byKey(SnakeSpeedPage.speedKey(speed)),
          findsOneWidget,
          reason: 'the picker should offer ${speed.name}',
        );
      }
      expect(find.text(en.snakeSpeedBrisk), findsOneWidget);
      expect(find.text(en.snakeSpeedFrantic), findsOneWidget);
    });

    testWidgets('tapping a level starts a run at that speed', (
      WidgetTester tester,
    ) async {
      await _pumpPicker(tester);

      // No game yet — the picker is up.
      expect(_openedSpeed(tester), isNull);

      await tester.tap(find.byKey(SnakeSpeedPage.speedKey(SnakeSpeed.frantic)));
      await tester.pumpAndSettle();

      // The run opened, and it opened at the level that was tapped.
      expect(find.byType(SnakeGamePage), findsOneWidget);
      expect(_openedSpeed(tester), SnakeSpeed.frantic);
    });

    testWidgets('a different level opens a run at its own pace', (
      WidgetTester tester,
    ) async {
      await _pumpPicker(tester);

      await tester.tap(find.byKey(SnakeSpeedPage.speedKey(SnakeSpeed.relaxed)));
      await tester.pumpAndSettle();

      final SnakeSpeed? opened = _openedSpeed(tester);
      expect(opened, SnakeSpeed.relaxed);
      // The pace the loop will run at is the slower one — the mapping the engine
      // test proves monotonic, tied here to the row that was tapped.
      expect(opened!.tick, greaterThan(SnakeSpeed.frantic.tick));
    });

    testWidgets('a played speed shows its best score on the row', (
      WidgetTester tester,
    ) async {
      // A best already recorded at the swift level; the other levels have none.
      final NookDatabase database = memoryDatabase();
      await tester.runAsync(
        () => SnakeScoreStore(database).record(
          level: SnakeSpeed.swift.level,
          score: 14,
          at: DateTime.utc(2026, 9, 6),
        ),
      );

      await _pumpPicker(tester, database: database);

      // The swift row shows its best...
      final Finder swiftRow = find.byKey(
        SnakeSpeedPage.speedKey(SnakeSpeed.swift),
      );
      expect(
        find.descendant(of: swiftRow, matching: find.text(en.snakeBest(14))),
        findsOneWidget,
      );
      // ...and only one row does, because only one speed has been played.
      expect(find.text(en.snakeBest(14)), findsOneWidget);
      // A never-played level shows no best line at all.
      expect(find.textContaining('Best'), findsOneWidget);
    });
  });

  group('the last-used speed', () {
    testWidgets(
      'with nothing stored the picker pre-selects the standard speed',
      (WidgetTester tester) async {
        await _pumpPicker(tester);

        // The "Last played" marker sits on exactly one row...
        expect(find.text(en.snakeSpeedLastPlayed), findsOneWidget);
        // ...and it is the standard (brisk) middle rung, the fallback when the
        // player has run nothing yet.
        expect(
          find.descendant(
            of: find.byKey(SnakeSpeedPage.speedKey(SnakeSpeed.standard)),
            matching: find.text(en.snakeSpeedLastPlayed),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('the picker opens on the speed last run at', (
      WidgetTester tester,
    ) async {
      // The player last ran the relaxed speed.
      final NookDatabase database = memoryDatabase();
      await tester.runAsync(
        () =>
            SnakeSpeedPrefStore(database)
                .setLastLevel(SnakeSpeed.relaxed.level),
      );

      await _pumpPicker(tester, database: database);

      // The marker moved to the relaxed row, not the middle.
      expect(find.text(en.snakeSpeedLastPlayed), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(SnakeSpeedPage.speedKey(SnakeSpeed.relaxed)),
          matching: find.text(en.snakeSpeedLastPlayed),
        ),
        findsOneWidget,
      );
    });

    testWidgets('starting a run records its speed as the last used', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      await _pumpPicker(tester, database: database);

      // Nothing run yet.
      expect(
        await tester.runAsync(() => SnakeSpeedPrefStore(database).lastLevel()),
        isNull,
      );

      await tester.tap(find.byKey(SnakeSpeedPage.speedKey(SnakeSpeed.frantic)));
      await tester.pumpAndSettle();

      // The speed the run started at is remembered — written on run start, so a
      // player who quits mid-run keeps the preference — and it survives to seed
      // the next open of the picker.
      expect(
        await tester.runAsync(() => SnakeSpeedPrefStore(database).lastLevel()),
        SnakeSpeed.frantic.level,
      );
    });
  });
}
