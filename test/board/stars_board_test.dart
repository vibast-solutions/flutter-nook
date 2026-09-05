import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/board/stars_board.dart';
import 'package:nook/design/tokens.dart';
import 'package:nook/games/stars/stars_state.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../support/stars_fixture.dart';

/// The border of the cell at [index].
Border cellBorder(WidgetTester tester, int index) {
  final Container container = tester.widget<Container>(
    find
        .descendant(
          of: find.byKey(StarsBoard.cellKey(index)),
          matching: find.byType(Container),
        )
        .first,
  );
  return (container.decoration! as BoxDecoration).border! as Border;
}

void main() {
  group('region colour and texture', () {
    test('every region has a texture of its own', () {
      // The board reads apart with the colour taken away entirely, which only
      // holds if no two regions share a texture.
      const int regions = kRegionCount;
      final Set<RegionTexture> textures = <RegionTexture>{
        for (int region = 0; region < regions; region++)
          regionTextureFor(region),
      };
      expect(textures, hasLength(regions));
      expect(RegionTexture.values, hasLength(regions));
    });

    test('every region has a fill of its own', () {
      final List<Color> fills = NookColors.softClay.regionFills;
      expect(fills, hasLength(kRegionCount));
      expect(fills.toSet(), hasLength(kRegionCount));
    });
  });

  group('the board', () {
    testWidgets('draws a heavier rule between two regions than inside one', (
      WidgetTester tester,
    ) async {
      final StarsPuzzle puzzle = fixedStarsPuzzle();
      await pumpStarsGame(tester, puzzle: puzzle);

      // A boundary in row 0: two side-by-side cells in different regions.
      int? boundary;
      int? interior;
      for (int column = 0; column < puzzle.spec.size - 1; column++) {
        final int cell = puzzle.spec.indexOf(0, column);
        final bool different = puzzle.regions[cell] != puzzle.regions[cell + 1];
        if (different) {
          boundary ??= cell;
        } else {
          interior ??= cell;
        }
      }
      expect(boundary, isNotNull, reason: 'the fixture has region boundaries');

      expect(
        cellBorder(tester, boundary!).right.width,
        StarsBoard.ruleWidth,
        reason: 'a region boundary is the heavy rule',
      );
      if (interior != null) {
        expect(
          cellBorder(tester, interior).right.width,
          StarsBoard.hairlineWidth,
          reason: 'a join inside a region is the hairline',
        );
      }
    });

    testWidgets('reads out each cell by row, column, region and content', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        final StarsPuzzle puzzle = fixedStarsPuzzle();
        await pumpStarsGame(tester, puzzle: puzzle);

        final int region = puzzle.regions[0] + 1;
        expect(
          find.bySemanticsLabel(en.cellStarsEmpty(1, 1, region)),
          findsOneWidget,
        );

        // A tap rules it out, another places a star: the sentence keeps up.
        await tapStarsCell(tester, 0);
        expect(
          find.bySemanticsLabel(en.cellStarsRuledOut(1, 1, region)),
          findsOneWidget,
        );
        await tapStarsCell(tester, 0);
        expect(
          find.bySemanticsLabel(en.cellStarsStar(1, 1, region)),
          findsOneWidget,
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('a star where the solution has none is not marked wrong', (
      WidgetTester tester,
    ) async {
      // The board never grades unasked: placing a star in the wrong cell shows
      // a star, not an error, and marking rule breaches is a later story.
      final StarsPuzzle puzzle = fixedStarsPuzzle();
      await pumpStarsGame(tester, puzzle: puzzle);

      final int notAStar = <int>[
        for (int cell = 0; cell < puzzle.spec.cellCount; cell++)
          if (!puzzle.solution.contains(cell)) cell,
      ].first;
      await tapStarsCell(tester, notAStar);
      await tapStarsCell(tester, notAStar);

      expect(starMarkAt(tester, notAStar), StarsMark.star);
    });

    testWidgets('a ruled-out cell wears a small cross, a star wears a star', (
      WidgetTester tester,
    ) async {
      // The marks are told apart by their glyph, not their widget type: ruling a
      // cell out draws a cross where a dot used to be, and a star draws a star.
      final StarsPuzzle puzzle = fixedStarsPuzzle();
      await pumpStarsGame(tester, puzzle: puzzle);

      await tapStarsCell(tester, 0);
      final Icon ruledOut = tester.widget<Icon>(
        find.byKey(StarsBoard.markKey(0)),
      );
      expect(ruledOut.icon, Icons.close_rounded);

      await tapStarsCell(tester, 0);
      final Icon star = tester.widget<Icon>(find.byKey(StarsBoard.markKey(0)));
      expect(star.icon, Icons.star_rounded);
    });
  });
}
