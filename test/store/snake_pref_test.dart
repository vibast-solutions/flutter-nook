import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/store/nook_database.dart';

/// A database in memory that goes away with the test.
NookDatabase memoryDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final NookDatabase database = NookDatabase.memory();
  addTearDown(database.close);
  return database;
}

void main() {
  group('SnakeSpeedPrefStore', () {
    test('nothing is stored before a run has started', () async {
      final SnakeSpeedPrefStore store = SnakeSpeedPrefStore(memoryDatabase());
      // Null is the picker's cue to fall back to the standard speed.
      expect(await store.lastLevel(), isNull);
      expect(await store.watchLastLevel().first, isNull);
    });

    test('the last level is remembered and read back', () async {
      final SnakeSpeedPrefStore store = SnakeSpeedPrefStore(memoryDatabase());

      await store.setLastLevel(4);

      expect(await store.lastLevel(), 4);
    });

    test('a later run replaces the last level rather than adding a row', () async {
      final NookDatabase database = memoryDatabase();
      final SnakeSpeedPrefStore store = SnakeSpeedPrefStore(database);

      await store.setLastLevel(2);
      await store.setLastLevel(5);

      // The value the picker reads is the most recent one...
      expect(await store.lastLevel(), 5);
      // ...and there is exactly one row, because it is one durable preference,
      // not a history. `getSingleOrNull` would throw if a second row had grown.
      expect(await store.watchLastLevel().first, 5);
    });

    test(
      'the stream follows a change made while it is being watched',
      () async {
        final SnakeSpeedPrefStore store = SnakeSpeedPrefStore(memoryDatabase());

        final Stream<int?> levels = store.watchLastLevel();
        expect(await levels.first, isNull);

        await store.setLastLevel(3);
        // The picker, watching this, moves to the newly-run speed.
        expect(await store.watchLastLevel().first, 3);
      },
    );
  });
}
