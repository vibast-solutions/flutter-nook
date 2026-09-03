/// Batch-produces the bundled starter packs from the same engine the app runs.
///
/// A pack is a set of pre-generated puzzles shipped inside the app so the first
/// tap after a cold launch is instant. This tool is the *only* way a pack is
/// made: packs are regenerated, never hand-edited, and CI runs this and fails if
/// the committed packs are not exactly what it produces.
///
/// Determinism is the whole contract. Every puzzle is generated with the same
/// `generateAt` the app calls, from a seed derived from a fixed base seed and the
/// pack's identity, and the records are sorted by seed before they are written —
/// so the same base seed always produces byte-identical files.
///
/// Usage:
///
///   dart run puzzle_engine:generate [options]
///   dart compile exe bin/generate.dart -o generate && ./generate [options]
///
///   --out DIR     where to write the .pack.gz files
///                 (default: ../../assets/packs, the app's asset directory when
///                 this is run from the package that owns it)
///   --count N     puzzles per pack (default: 24)
///   --seed N      base seed everything is derived from (default: 20260901)
///   --only IDS    comma-separated game:tier list to limit to,
///                 e.g. --only stars:fiendish,sudoku-classic:hard
///   --list        print the packs that would be produced, and exit
///   --help        print this and exit
library;

import 'dart:convert';
import 'dart:io';

import 'package:puzzle_engine/puzzle_engine.dart';

/// One pack to produce: a game, a tier, and how to make a puzzle for it.
///
/// Both games reach the same [PackCodec] through this one shape, so adding a
/// game — or promoting a tier that is currently generated on the device — is an
/// entry here and nothing else.
class _Target {
  const _Target({
    required this.game,
    required this.tier,
    required this.size,
    required this.generate,
    required this.toRecord,
  });

  final String game;
  final PuzzleDifficulty tier;
  final int size;

  /// Generates the puzzle for a seed, measured at [tier].
  final Object Function(int seed) generate;

  /// Turns that puzzle into a record.
  final PackRecord Function(Object puzzle) toRecord;

  String get id => '$game:${tier.name}';
  String get fileName => '$game-${tier.name}.pack.gz';
}

/// The packs Nook ships, chosen from measured generation time (see VIB-78):
/// only the grids and tiers a player would actually wait for. The instant ones
/// — 4×4, 6×6, the easy end of 9×9, gentle Stars — are generated on the device,
/// where they are imperceptible and a pack would be pure cost.
List<_Target> _shippedTargets() {
  final SudokuGenerator classic = SudokuGenerator(SudokuSpec.classic);
  final StarsGenerator stars = StarsGenerator(StarsSpec.standard);

  _Target sudoku(PuzzleDifficulty tier) => _Target(
    game: 'sudoku-classic',
    tier: tier,
    size: SudokuSpec.classic.size,
    generate: (int seed) => classic.generateAt(tier, seed),
    toRecord: (Object puzzle) => SudokuPack.record(puzzle as SudokuPuzzle),
  );

  _Target star(PuzzleDifficulty tier) => _Target(
    game: 'stars',
    tier: tier,
    size: StarsSpec.standard.size,
    generate: (int seed) => stars.generateAt(tier, seed),
    toRecord: (Object puzzle) => StarsPack.record(puzzle as StarsPuzzle),
  );

  return <_Target>[
    sudoku(PuzzleDifficulty.medium),
    sudoku(PuzzleDifficulty.hard),
    sudoku(PuzzleDifficulty.fiendish),
    star(PuzzleDifficulty.easy),
    star(PuzzleDifficulty.medium),
    star(PuzzleDifficulty.hard),
    star(PuzzleDifficulty.fiendish),
  ];
}

Future<void> main(List<String> args) async {
  final Map<String, String> options = <String, String>{};
  final Set<String> flags = <String>{};
  for (int i = 0; i < args.length; i++) {
    final String arg = args[i];
    if (arg == '--help' || arg == '--list') {
      flags.add(arg);
    } else if (arg.startsWith('--')) {
      if (i + 1 >= args.length) {
        stderr.writeln('Missing value for $arg');
        exitCode = 64;
        return;
      }
      options[arg] = args[++i];
    } else {
      stderr.writeln('Unexpected argument: $arg');
      exitCode = 64;
      return;
    }
  }

  if (flags.contains('--help')) {
    stdout.writeln(_usage);
    return;
  }

  final String outDir = options['--out'] ?? '../../assets/packs';
  final int count = int.tryParse(options['--count'] ?? '24') ?? 24;
  final int baseSeed =
      int.tryParse(options['--seed'] ?? '20260901') ?? 20260901;
  final Set<String>? only = options['--only']
      ?.split(',')
      .map((String s) => s.trim())
      .where((String s) => s.isNotEmpty)
      .toSet();

  final List<_Target> targets = _shippedTargets()
      .where((_Target t) => only == null || only.contains(t.id))
      .toList();

  if (targets.isEmpty) {
    stderr.writeln('No packs match --only "${options['--only']}".');
    exitCode = 64;
    return;
  }

  if (flags.contains('--list')) {
    for (final _Target target in targets) {
      stdout.writeln('${target.id}  ->  ${target.fileName}');
    }
    return;
  }

  final Directory dir = Directory(outDir);
  await dir.create(recursive: true);

  int totalGz = 0;
  for (final _Target target in targets) {
    final List<PackRecord> records = _generatePack(target, count, baseSeed);
    final String text = PackCodec.encode(
      game: target.game,
      tier: target.tier.name,
      size: target.size,
      records: records,
    );
    final List<int> bytes = gzip.encode(utf8.encode(text));
    final File file = File('${dir.path}/${target.fileName}');
    await file.writeAsBytes(bytes, flush: true);
    totalGz += bytes.length;
    stdout.writeln(
      '${target.fileName.padRight(34)} '
      '${records.length.toString().padLeft(3)} puzzles  '
      '${text.length.toString().padLeft(6)} B text  '
      '${bytes.length.toString().padLeft(6)} B gz',
    );
  }
  stdout.writeln(
    'Wrote ${targets.length} packs to ${dir.path} '
    '($totalGz B total gzipped).',
  );
}

/// Generates [count] distinct puzzles for [target], deterministically.
///
/// Seeds come from a generator keyed by the base seed and the pack's identity,
/// so two packs never draw the same stream and the same base seed always
/// reproduces the same puzzles. Duplicates — the same givens from two seeds —
/// are dropped so a pack is [count] *different* puzzles, and a generous cap on
/// draws turns "this tier is unreachable" into an error rather than a hang.
List<PackRecord> _generatePack(_Target target, int count, int baseSeed) {
  final PuzzleRandom seeds = PuzzleRandom(baseSeed ^ _fnv1a(target.id));
  final Map<String, PackRecord> byCells = <String, PackRecord>{};
  final int maxDraws = count * 200 + 200;
  int draws = 0;
  while (byCells.length < count) {
    if (draws++ >= maxDraws) {
      throw StateError(
        'Only produced ${byCells.length} of $count for ${target.id} '
        'in $maxDraws draws.',
      );
    }
    final int seed = seeds.nextUint32();
    final PackRecord record = target.toRecord(target.generate(seed));
    byCells.putIfAbsent(record.cells, () => record);
  }
  return byCells.values.toList();
}

/// A stable 32-bit FNV-1a hash of [text].
///
/// The engine's own [PuzzleRandom] mixes seeds, but the seed for a pack has to
/// come from its name, and `String.hashCode` is randomised per run — so it
/// could never anchor a byte-identical build. This is small, fixed and enough.
int _fnv1a(String text) {
  int hash = 0x811C9DC5;
  for (final int unit in utf8.encode(text)) {
    hash = (hash ^ unit) & 0xFFFFFFFF;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

const String _usage = '''
Batch-produce Nook's bundled starter packs.

  dart run puzzle_engine:generate [options]

  --out DIR     where to write the .pack.gz files (default: ../../assets/packs)
  --count N     puzzles per pack (default: 24)
  --seed N      base seed everything is derived from (default: 20260901)
  --only IDS    comma-separated game:tier list, e.g. stars:fiendish
  --list        print the packs that would be produced, and exit
  --help        print this and exit
''';
