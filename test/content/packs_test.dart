import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

/// The packs Nook ships, and the tiers each one holds. The list is the contract:
/// a pack that appears in the bundle but not here, or here but not in the bundle,
/// fails the test — so what ships is never a surprise.
const Map<String, List<PuzzleDifficulty>> _shipped =
    <String, List<PuzzleDifficulty>>{
      'sudoku-classic': <PuzzleDifficulty>[
        PuzzleDifficulty.medium,
        PuzzleDifficulty.hard,
        PuzzleDifficulty.fiendish,
      ],
      'stars': <PuzzleDifficulty>[
        PuzzleDifficulty.easy,
        PuzzleDifficulty.medium,
        PuzzleDifficulty.hard,
        PuzzleDifficulty.fiendish,
      ],
    };

Future<Uint8List> _load(String assetKey) async {
  final ByteData data = await rootBundle.load(assetKey);
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

String _assetKey(String game, PuzzleDifficulty tier) =>
    'assets/packs/$game-${tier.name}.pack.gz';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'every shipped puzzle is unique and wears the tier it was rated',
    () async {
      for (final MapEntry<String, List<PuzzleDifficulty>> game
          in _shipped.entries) {
        for (final PuzzleDifficulty tier in game.value) {
          final Uint8List bytes = await _load(_assetKey(game.key, tier));
          final PuzzlePack pack = PackCodec.decode(
            utf8.decode(gzip.decode(bytes)),
          );

          expect(pack.header.game, game.key);
          expect(pack.header.tier, tier.name);
          expect(pack.records.length, pack.header.count);
          expect(
            pack.records.length,
            greaterThanOrEqualTo(20),
            reason:
                'a pack thin enough to run out on the first sitting is not '
                'worth its cost',
          );

          for (final PackRecord record in pack.records) {
            if (game.key == 'stars') {
              const StarsSpec spec = StarsSpec.standard;
              final StarsPuzzle puzzle = StarsPack.puzzle(record, spec, tier);
              expect(
                StarsSolver(spec).countPlacements(puzzle.regions, limit: 2),
                1,
                reason:
                    '${game.key} ${tier.name} seed ${record.seed} '
                    'is not unique',
              );
              expect(
                StarsRater(spec)
                    .rate(StarsLogicSolver(spec).solve(puzzle.regions)),
                tier,
                reason:
                    '${game.key} ${tier.name} seed ${record.seed} '
                    'rates as something else',
              );
            } else {
              const SudokuSpec spec = SudokuSpec.classic;
              final SudokuPuzzle puzzle = SudokuPack.puzzle(record, spec, tier);
              expect(
                SudokuSolver(spec).countSolutions(puzzle.givens, limit: 2),
                1,
                reason:
                    '${game.key} ${tier.name} seed ${record.seed} '
                    'is not unique',
              );
              expect(
                SudokuRater(spec)
                    .rate(SudokuLogicSolver(spec).solve(puzzle.givens)),
                tier,
                reason:
                    '${game.key} ${tier.name} seed ${record.seed} '
                    'rates as something else',
              );
            }
          }
        }
      }
    },
  );

  test(
    'a shipped pack is exactly what regenerating its records produces',
    () async {
      // Byte-identity end to end: rebuild each record from its puzzle — re-running
      // the same solver the CLI ran — re-encode and re-gzip, and the bytes must
      // match what is committed. A pack that has rotted against the engine, or been
      // hand-edited, fails here.
      for (final MapEntry<String, List<PuzzleDifficulty>> game
          in _shipped.entries) {
        for (final PuzzleDifficulty tier in game.value) {
          final Uint8List original = await _load(_assetKey(game.key, tier));
          final PuzzlePack pack = PackCodec.decode(
            utf8.decode(gzip.decode(original)),
          );

          final List<PackRecord> rebuilt = <PackRecord>[
            for (final PackRecord record in pack.records)
              if (game.key == 'stars')
                StarsPack.record(
                  StarsPack.puzzle(record, StarsSpec.standard, tier),
                )
              else
                SudokuPack.record(
                  SudokuPack.puzzle(record, SudokuSpec.classic, tier),
                ),
          ];
          final String text = PackCodec.encode(
            game: pack.header.game,
            tier: pack.header.tier,
            size: pack.header.size,
            records: rebuilt,
          );
          final List<int> reBytes = gzip.encode(utf8.encode(text));
          expect(
            reBytes,
            original,
            reason:
                '${_assetKey(game.key, tier)} is not what regeneration '
                'produces — regenerate it with the CLI',
          );
        }
      }
    },
  );

  test('the bundle ships exactly the packs the contract names', () async {
    final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(
      rootBundle,
    );
    final Set<String> inBundle = manifest
        .listAssets()
        .where((String a) => a.startsWith('assets/packs/'))
        .toSet();
    final Set<String> expected = <String>{
      for (final MapEntry<String, List<PuzzleDifficulty>> game
          in _shipped.entries)
        for (final PuzzleDifficulty tier in game.value)
          _assetKey(game.key, tier),
    };
    expect(inBundle, expected);
  });
}
