import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/board/stars_board.dart';
import 'package:nook/chrome/play_clock.dart';
import 'package:nook/daily/daily_card.dart';
import 'package:nook/daily/daily_launch.dart';
import 'package:nook/design/theme.dart';
import 'package:nook/design/tokens.dart';
import 'package:nook/games/stars/stars_controller.dart';
import 'package:nook/games/stars/stars_naming.dart';
import 'package:nook/games/stars/stars_variant.dart';
import 'package:nook/home/home_screen.dart';
import 'package:nook/l10n/app_localizations.dart';
import 'package:nook/store/nook_database.dart';
import 'package:nook/store/saved_game.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../support/stars_fixture.dart';

/// The daily on a Stars day — Wednesday 2026-09-02, an easy Stars.
///
/// The rules the games share are exercised on Duo in `daily_card_test.dart`;
/// this checks what is Stars' own: the wiring that opens *this* game from the
/// card, from the daily source and never the ordinary one, saving into the
/// daily slot.
void main() {
  testWidgets('a Stars day opens Stars from the daily source', (
    WidgetTester tester,
  ) async {
    final NookDatabase database = memoryDatabase();
    final StarsPuzzle puzzle = fixedStarsPuzzle();
    await setPhoneSurface(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyStarsSourceProvider.overrideWithValue(
            (StarsSpec spec, PuzzleDifficulty tier, int seed) async => puzzle,
          ),
          // The ordinary source — the pack-first one in the real app — must
          // never be asked for the daily, so asking it is the test failing.
          starsPuzzleSourceProvider.overrideWithValue(
            (StarsSpec spec, PuzzleDifficulty tier, int seed) =>
                throw StateError('the daily must not use the ordinary source'),
          ),
          nookDatabaseProvider.overrideWithValue(database),
          nowProvider.overrideWithValue(
            TestClock(DateTime.utc(2026, 9, 2, 9)).call,
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildNookTheme(NookColors.softClay),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The card names the day's game and the ramp's tier for a Wednesday.
    expect(
      find.text(en.dailyDetails(DateTime.utc(2026, 9, 2), en.difficultyEasy)),
      findsOneWidget,
    );

    await tester.tap(find.byKey(dailyCardKey));
    await tester.pumpAndSettle();

    expect(find.byType(StarsBoard), findsOneWidget);
    expect(
      find.text(
        en.gameSubtitle(StarsVariant.standard.sizeLabel(en), en.difficultyEasy),
      ),
      findsOneWidget,
    );

    // Opening it writes the in-progress board to the daily slot, and Stars'
    // own slot stays untouched.
    final SavedGame? daily = await storedSave(tester, database, dailySlotId);
    expect(daily, isNotNull);
    expect(
      await storedSave(tester, database, StarsVariant.standard.id),
      isNull,
    );
  });
}
