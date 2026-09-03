/// The bundled-pack format: a diffable text file of pre-generated puzzles.
///
/// A pack is one game and one tier's worth of ready puzzles, shipped inside the
/// app so the very first tap after a cold launch hands back a board instead of
/// a spinner. This file is the *format* — game-neutral, pure text — and it lives
/// in the engine on purpose: the command-line tool that writes packs and the app
/// that reads them share this one implementation, so a pack can never be written
/// one way and parsed another.
///
/// The text is deliberately line-oriented: a header line, then one puzzle per
/// line, sorted by seed. A pack changing in a pull request is then legible as
/// "these puzzles changed" rather than an opaque blob. The bytes that actually
/// ship are this text gzipped — gzipping is done at the edges (the CLI and the
/// app), because the engine stays free of `dart:io`.
library;

/// Thrown when a pack's text cannot be parsed, or does not describe what the
/// caller asked for.
///
/// The app treats this as "no pack here" and falls back to generating on the
/// device — a malformed asset must never be worse than a missing one.
class PackFormatException implements Exception {
  const PackFormatException(this.message);

  final String message;

  @override
  String toString() => 'PackFormatException: $message';
}

/// One puzzle in a pack, as it sits on disk.
///
/// [cells] is the game's board in one token, its meaning left to the game
/// adapter: a Sudoku writes its givens as digits (`.` for a blank), a Stars
/// puzzle writes its region map as one digit per cell. The solution is *not*
/// stored — every pack puzzle is guess-free by guarantee, so the app recovers it
/// with the same solver the generator used to prove it unique.
///
/// [techniques] records what the human-technique solver needed, hardest-last,
/// as `name:count`. The app does not read it — difficulty is already the tier —
/// but it is what makes a pack reviewable ("this one needs an x-wing") and what
/// the validity test re-derives to prove the stored tier is honest.
class PackRecord {
  const PackRecord({
    required this.seed,
    required this.cells,
    required this.techniques,
  });

  /// The seed the puzzle was generated from — its provenance, and what
  /// reproduces it exactly through the generator.
  final int seed;

  /// The board in one whitespace-free token; the game adapter reads it.
  final String cells;

  /// How many times each technique broke the deadlock, keyed by technique name.
  final Map<String, int> techniques;
}

/// A pack's header: what game and tier it is, and enough to sanity-check it.
class PackHeader {
  const PackHeader({
    required this.game,
    required this.tier,
    required this.size,
    required this.count,
  });

  /// The game's stable id, e.g. `sudoku-classic` or `stars`.
  final String game;

  /// The tier's identifier, e.g. `hard` — never a name a player reads.
  final String tier;

  /// The grid's side length, so a parser can reject a record of the wrong
  /// width before it ever reaches a solver.
  final int size;

  /// How many records the pack claims to hold.
  final int count;
}

/// A whole pack: its header and its puzzles.
class PuzzlePack {
  const PuzzlePack({required this.header, required this.records});

  final PackHeader header;
  final List<PackRecord> records;
}

/// Reads and writes the pack text format.
///
/// The format is one implementation, shared by the CLI and the app, so there is
/// nothing to keep in step. Encoding sorts records by seed, so the same puzzles
/// always produce the same file — which, gzipped deterministically, is what
/// makes regeneration byte-identical.
class PackCodec {
  const PackCodec._();

  /// The format version, written into the header and checked on read. Bumped
  /// only if the line grammar changes in a way an old parser could misread.
  static const int version = 1;

  static const String _magic = 'nook-pack';

  /// The text of a pack for [game]/[tier] on a [size]×[size] grid holding
  /// [records], sorted by seed.
  ///
  /// A copy of [records] is sorted rather than the caller's list, and the seed
  /// is the only sort key, so ordering is total and stable: two records can
  /// never share a seed within a pack, because they are the same puzzle.
  static String encode({
    required String game,
    required String tier,
    required int size,
    required List<PackRecord> records,
  }) {
    final List<PackRecord> ordered = List<PackRecord>.of(records)
      ..sort((PackRecord a, PackRecord b) => a.seed.compareTo(b.seed));
    final StringBuffer out = StringBuffer()
      ..write('$_magic $version $game $tier $size ${ordered.length}\n');
    for (final PackRecord record in ordered) {
      out
        ..write(record.seed)
        ..write(' ')
        ..write(record.cells)
        ..write(' ')
        ..write(_encodeTechniques(record.techniques))
        ..write('\n');
    }
    return out.toString();
  }

  /// Parses pack [text], throwing [PackFormatException] on anything malformed.
  ///
  /// Strict on purpose: a header that does not start with the magic, a record
  /// count that disagrees with the header, a cell token of the wrong width — any
  /// of these means the file is not a pack this build understands, and the app's
  /// answer to that is to generate on the device instead.
  static PuzzlePack decode(String text) {
    final List<String> lines = text.split('\n');
    if (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }
    if (lines.isEmpty) {
      throw const PackFormatException('empty pack');
    }
    final PackHeader header = _decodeHeader(lines.first);
    final List<PackRecord> records = <PackRecord>[];
    for (int i = 1; i < lines.length; i++) {
      records.add(_decodeRecord(lines[i], header.size, i));
    }
    if (records.length != header.count) {
      throw PackFormatException(
        'header claims ${header.count} records but ${records.length} follow',
      );
    }
    return PuzzlePack(header: header, records: records);
  }

  static PackHeader _decodeHeader(String line) {
    final List<String> parts = line.split(' ');
    if (parts.length != 6 || parts[0] != _magic) {
      throw PackFormatException('bad pack header: "$line"');
    }
    if (parts[1] != '$version') {
      throw PackFormatException('unsupported pack version ${parts[1]}');
    }
    final int? size = int.tryParse(parts[4]);
    final int? count = int.tryParse(parts[5]);
    if (size == null || size < 1 || count == null || count < 0) {
      throw PackFormatException('bad pack header numbers: "$line"');
    }
    return PackHeader(game: parts[2], tier: parts[3], size: size, count: count);
  }

  static PackRecord _decodeRecord(String line, int size, int lineNumber) {
    final List<String> parts = line.split(' ');
    if (parts.length != 3) {
      throw PackFormatException('bad record on line $lineNumber: "$line"');
    }
    final int? seed = int.tryParse(parts[0]);
    if (seed == null) {
      throw PackFormatException('bad seed on line $lineNumber: "${parts[0]}"');
    }
    if (parts[1].length != size * size) {
      throw PackFormatException(
        'record on line $lineNumber has ${parts[1].length} cells, '
        'expected ${size * size}',
      );
    }
    return PackRecord(
      seed: seed,
      cells: parts[1],
      techniques: _decodeTechniques(parts[2], lineNumber),
    );
  }

  static String _encodeTechniques(Map<String, int> techniques) {
    if (techniques.isEmpty) {
      return '-';
    }
    return techniques.entries
        .map((MapEntry<String, int> e) => '${e.key}:${e.value}')
        .join(',');
  }

  static Map<String, int> _decodeTechniques(String token, int lineNumber) {
    if (token == '-') {
      return const <String, int>{};
    }
    final Map<String, int> out = <String, int>{};
    for (final String pair in token.split(',')) {
      final int colon = pair.lastIndexOf(':');
      final int? count = colon < 0
          ? null
          : int.tryParse(pair.substring(colon + 1));
      if (colon < 0 || count == null) {
        throw PackFormatException('bad technique "$pair" on line $lineNumber');
      }
      out[pair.substring(0, colon)] = count;
    }
    return out;
  }
}
