import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/chrome/solved_reveal.dart';

/// A [SolvedReveal] with two tell-apart children, optionally with motion turned
/// down, built so a rebuild with a new [solved] keeps the same [State] and so
/// runs the real solved→finished transition.
Widget harness({required bool solved, bool reducedMotion = false}) {
  return MaterialApp(
    home: Builder(
      builder: (BuildContext context) {
        final Widget reveal = SolvedReveal(
          solved: solved,
          playing: const SizedBox(key: Key('playing')),
          completion: const SizedBox(key: Key('finished')),
        );
        if (!reducedMotion) {
          return reveal;
        }
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: reveal,
        );
      },
    ),
  );
}

void main() {
  final Finder playing = find.byKey(const Key('playing'));
  final Finder finished = find.byKey(const Key('finished'));

  testWidgets('shows the board while the puzzle is unsolved', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(harness(solved: false));

    expect(playing, findsOneWidget);
    expect(finished, findsNothing);
  });

  testWidgets('holds on the board, then flies the finished screen in', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(harness(solved: false));
    await tester.pumpWidget(harness(solved: true));

    // The hold: the board is still up the frame after solving, glowing, before
    // the summary starts to arrive.
    expect(playing, findsOneWidget);
    expect(finished, findsNothing);

    // Part-way through, the summary is on its way in over the fading board.
    await tester.pump(const Duration(milliseconds: 650));
    expect(finished, findsOneWidget);

    // Settled: the finished screen alone, the board gone.
    await tester.pumpAndSettle();
    expect(finished, findsOneWidget);
    expect(playing, findsNothing);
  });

  testWidgets('with motion turned down, lands on the finished screen at once', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(harness(solved: false, reducedMotion: true));
    await tester.pumpWidget(harness(solved: true, reducedMotion: true));

    // No hold and no flight: the finished screen is there on the first frame
    // and the board is gone.
    expect(finished, findsOneWidget);
    expect(playing, findsNothing);
  });

  testWidgets('a fresh puzzle after a solve shows the board again', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(harness(solved: false));
    await tester.pumpWidget(harness(solved: true));
    await tester.pumpAndSettle();
    expect(finished, findsOneWidget);

    // Starting another puzzle takes the reveal back to the board, ready to run
    // its ceremony again when that one is finished too.
    await tester.pumpWidget(harness(solved: false));
    expect(playing, findsOneWidget);
    expect(finished, findsNothing);
  });
}
