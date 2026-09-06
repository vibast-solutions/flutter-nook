import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/design/theme.dart';
import 'package:nook/design/tokens.dart';
import 'package:nook/games/snake/snake_screen.dart';
import 'package:nook/games/snake/snake_speed.dart';
import 'package:nook/games/snake/snake_variant.dart';
import 'package:nook/l10n/app_localizations.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../support/duo_fixture.dart';

/// Pumps the speed picker straight onto its own page.
Future<void> _pumpPicker(WidgetTester tester) async {
  await setPhoneSurface(tester);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildNookTheme(NookColors.softClay),
      home: const SnakeSpeedPage(variant: SnakeVariant.standard),
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
  });
}
