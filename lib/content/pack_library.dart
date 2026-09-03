import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../store/nook_database.dart';

/// Loads the bytes of a pack asset, or `null` if there is no such asset.
///
/// A seam so a test can hand the library packs — or an empty shelf — without a
/// real asset bundle. The path is the full asset key, e.g.
/// `assets/packs/stars-hard.pack.gz`.
typedef PackAssetLoader = Future<Uint8List?> Function(String assetKey);

/// The default loader: the app's asset bundle.
///
/// A missing asset throws rather than returning null, so the miss is caught and
/// turned into "no pack here" — which is a normal state, not a failure. Every
/// tier that ships no pack (the instant ones) reaches this and simply generates
/// on the device instead.
Future<Uint8List?> rootBundlePackLoader(String assetKey) async {
  try {
    final ByteData data = await rootBundle.load(assetKey);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } on FlutterError {
    return null;
  }
}

/// The bundled starter packs, read lazily and handed out one puzzle at a time.
///
/// This is the app side of VIB-78: it turns a pack asset into ready puzzles so
/// the first tap after a cold launch is instant. It is a **cache, not content**
/// — every method returns `null` when there is no pack puzzle to give (the asset
/// is absent, spent or unreadable), and the caller's answer to `null` is to
/// generate on the device. The player can never tell which they got.
///
/// A pack is decoded at most once per run and its bytes are tiny (a few
/// kilobytes) and decode in well under a millisecond, so the work is done inline
/// rather than on an isolate — a `compute` hop would cost more to start than the
/// decode it saves.
class PackLibrary {
  PackLibrary({required this.loader, required this.progress});

  final PackAssetLoader loader;
  final PackProgressStore progress;

  /// One future per pack, so a pack is loaded and decoded once however many
  /// times it is asked for — including the misses, so an absent pack is not
  /// re-fetched on every game start.
  final Map<String, Future<PuzzlePack?>> _packs =
      <String, Future<PuzzlePack?>>{};

  /// The next unused Sudoku from the [gameId]/[tier] pack, or `null` if there
  /// is none to give.
  Future<SudokuPuzzle?> takeSudoku(
    String gameId,
    SudokuSpec spec,
    PuzzleDifficulty tier,
  ) {
    return _take<SudokuPuzzle>(
      _packId(gameId, tier),
      (PackRecord record) => SudokuPack.puzzle(record, spec, tier),
    );
  }

  /// The next unused Stars puzzle from the [gameId]/[tier] pack, or `null`.
  Future<StarsPuzzle?> takeStars(
    String gameId,
    StarsSpec spec,
    PuzzleDifficulty tier,
  ) {
    return _take<StarsPuzzle>(
      _packId(gameId, tier),
      (PackRecord record) => StarsPack.puzzle(record, spec, tier),
    );
  }

  Future<T?> _take<T>(String packId, T Function(PackRecord) build) async {
    final PuzzlePack? pack = await _load(packId);
    if (pack == null) {
      return null;
    }
    final int? index = await progress.claimNext(packId, pack.records.length);
    if (index == null) {
      return null;
    }
    try {
      return build(pack.records[index]);
    } on PackFormatException {
      // A record that will not become a puzzle is treated as no puzzle: the
      // player falls back to a generated one rather than seeing a broken board.
      // A shipped pack never reaches here — the validity test would have failed
      // CI — so this only guards a corrupt file on a real device.
      return null;
    }
  }

  Future<PuzzlePack?> _load(String packId) {
    return _packs.putIfAbsent(packId, () => _decode(packId));
  }

  Future<PuzzlePack?> _decode(String packId) async {
    final Uint8List? bytes = await loader('assets/packs/$packId.pack.gz');
    if (bytes == null) {
      return null;
    }
    try {
      final String text = utf8.decode(gzip.decode(bytes));
      return PackCodec.decode(text);
    } on Object {
      // Unreadable bytes are no better and no worse than a missing asset.
      return null;
    }
  }

  String _packId(String gameId, PuzzleDifficulty tier) =>
      '$gameId-${tier.name}';
}

/// The bundled packs, backed by the real asset bundle and the real store.
///
/// Overridden in tests with a library over a fake shelf and an in-memory store.
final Provider<PackLibrary> packLibraryProvider = Provider<PackLibrary>(
  (Ref ref) => PackLibrary(
    loader: rootBundlePackLoader,
    progress: ref.watch(packProgressStoreProvider),
  ),
  name: 'packLibrary',
);
