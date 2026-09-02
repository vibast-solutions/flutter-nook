// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nook_database.dart';

// ignore_for_file: type=lint
class $SavedGamesTable extends SavedGames
    with TableInfo<$SavedGamesTable, SavedGameRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedGamesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _gameIdMeta = const VerificationMeta('gameId');
  @override
  late final GeneratedColumn<String> gameId = GeneratedColumn<String>(
    'game_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _difficultyMeta = const VerificationMeta(
    'difficulty',
  );
  @override
  late final GeneratedColumn<String> difficulty = GeneratedColumn<String>(
    'difficulty',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seedMeta = const VerificationMeta('seed');
  @override
  late final GeneratedColumn<int> seed = GeneratedColumn<int>(
    'seed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<int>, String> givens =
      GeneratedColumn<String>(
        'givens',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<List<int>>($SavedGamesTable.$convertergivens);
  @override
  late final GeneratedColumnWithTypeConverter<List<int>, String> solution =
      GeneratedColumn<String>(
        'solution',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<List<int>>($SavedGamesTable.$convertersolution);
  @override
  late final GeneratedColumnWithTypeConverter<List<int>, String> cells =
      GeneratedColumn<String>(
        'cells',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<List<int>>($SavedGamesTable.$convertercells);
  @override
  late final GeneratedColumnWithTypeConverter<List<int>, String> notes =
      GeneratedColumn<String>(
        'notes',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<List<int>>($SavedGamesTable.$converternotes);
  @override
  late final GeneratedColumnWithTypeConverter<MoveHistory, String> history =
      GeneratedColumn<String>(
        'history',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<MoveHistory>($SavedGamesTable.$converterhistory);
  @override
  late final GeneratedColumnWithTypeConverter<List<int>, String> hints =
      GeneratedColumn<String>(
        'hints',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<int>>($SavedGamesTable.$converterhints);
  static const VerificationMeta _wasHintedMeta = const VerificationMeta(
    'wasHinted',
  );
  @override
  late final GeneratedColumn<bool> wasHinted = GeneratedColumn<bool>(
    'was_hinted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("was_hinted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _notesModeMeta = const VerificationMeta(
    'notesMode',
  );
  @override
  late final GeneratedColumn<bool> notesMode = GeneratedColumn<bool>(
    'notes_mode',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("notes_mode" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  late final GeneratedColumnWithTypeConverter<Duration, int> elapsed =
      GeneratedColumn<int>(
        'elapsed',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<Duration>($SavedGamesTable.$converterelapsed);
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    gameId,
    difficulty,
    seed,
    givens,
    solution,
    cells,
    notes,
    history,
    hints,
    wasHinted,
    notesMode,
    elapsed,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_games';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedGameRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('game_id')) {
      context.handle(
        _gameIdMeta,
        gameId.isAcceptableOrUnknown(data['game_id']!, _gameIdMeta),
      );
    } else if (isInserting) {
      context.missing(_gameIdMeta);
    }
    if (data.containsKey('difficulty')) {
      context.handle(
        _difficultyMeta,
        difficulty.isAcceptableOrUnknown(data['difficulty']!, _difficultyMeta),
      );
    } else if (isInserting) {
      context.missing(_difficultyMeta);
    }
    if (data.containsKey('seed')) {
      context.handle(
        _seedMeta,
        seed.isAcceptableOrUnknown(data['seed']!, _seedMeta),
      );
    } else if (isInserting) {
      context.missing(_seedMeta);
    }
    if (data.containsKey('was_hinted')) {
      context.handle(
        _wasHintedMeta,
        wasHinted.isAcceptableOrUnknown(data['was_hinted']!, _wasHintedMeta),
      );
    }
    if (data.containsKey('notes_mode')) {
      context.handle(
        _notesModeMeta,
        notesMode.isAcceptableOrUnknown(data['notes_mode']!, _notesModeMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {gameId};
  @override
  SavedGameRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedGameRow(
      gameId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}game_id'],
      )!,
      difficulty: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}difficulty'],
      )!,
      seed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seed'],
      )!,
      givens: $SavedGamesTable.$convertergivens.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}givens'],
        )!,
      ),
      solution: $SavedGamesTable.$convertersolution.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}solution'],
        )!,
      ),
      cells: $SavedGamesTable.$convertercells.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}cells'],
        )!,
      ),
      notes: $SavedGamesTable.$converternotes.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}notes'],
        )!,
      ),
      history: $SavedGamesTable.$converterhistory.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}history'],
        )!,
      ),
      hints: $SavedGamesTable.$converterhints.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}hints'],
        )!,
      ),
      wasHinted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}was_hinted'],
      )!,
      notesMode: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}notes_mode'],
      )!,
      elapsed: $SavedGamesTable.$converterelapsed.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}elapsed'],
        )!,
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SavedGamesTable createAlias(String alias) {
    return $SavedGamesTable(attachedDatabase, alias);
  }

  static TypeConverter<List<int>, String> $convertergivens =
      const _DigitsConverter();
  static TypeConverter<List<int>, String> $convertersolution =
      const _DigitsConverter();
  static TypeConverter<List<int>, String> $convertercells =
      const _DigitsConverter();
  static TypeConverter<List<int>, String> $converternotes =
      const _DigitsConverter();
  static TypeConverter<MoveHistory, String> $converterhistory =
      const _HistoryConverter();
  static TypeConverter<List<int>, String> $converterhints =
      const _DigitsConverter();
  static TypeConverter<Duration, int> $converterelapsed =
      const _DurationConverter();
}

class SavedGameRow extends DataClass implements Insertable<SavedGameRow> {
  /// The game's stable identifier, which is also what makes the save unique.
  final String gameId;

  /// The tier, as its identifier rather than a name a player reads.
  final String difficulty;

  /// The seed the puzzle was generated from.
  final int seed;

  /// The starting grid.
  final List<int> givens;

  /// The one solution.
  final List<int> solution;

  /// The grid as the player left it.
  final List<int> cells;

  /// The pencil marks, one bitmask per cell.
  final List<int> notes;

  /// The moves still to take back.
  final MoveHistory history;

  /// The cells that were given away by a hint.
  final List<int> hints;

  /// Whether the puzzle was ever hinted, whatever is on the board now.
  final bool wasHinted;

  /// Whether the pad was left writing pencil marks.
  final bool notesMode;

  /// How long the puzzle has been played for.
  final Duration elapsed;

  /// When this save was last written; the newest is the one Continue offers.
  final DateTime updatedAt;
  const SavedGameRow({
    required this.gameId,
    required this.difficulty,
    required this.seed,
    required this.givens,
    required this.solution,
    required this.cells,
    required this.notes,
    required this.history,
    required this.hints,
    required this.wasHinted,
    required this.notesMode,
    required this.elapsed,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['game_id'] = Variable<String>(gameId);
    map['difficulty'] = Variable<String>(difficulty);
    map['seed'] = Variable<int>(seed);
    {
      map['givens'] = Variable<String>(
        $SavedGamesTable.$convertergivens.toSql(givens),
      );
    }
    {
      map['solution'] = Variable<String>(
        $SavedGamesTable.$convertersolution.toSql(solution),
      );
    }
    {
      map['cells'] = Variable<String>(
        $SavedGamesTable.$convertercells.toSql(cells),
      );
    }
    {
      map['notes'] = Variable<String>(
        $SavedGamesTable.$converternotes.toSql(notes),
      );
    }
    {
      map['history'] = Variable<String>(
        $SavedGamesTable.$converterhistory.toSql(history),
      );
    }
    {
      map['hints'] = Variable<String>(
        $SavedGamesTable.$converterhints.toSql(hints),
      );
    }
    map['was_hinted'] = Variable<bool>(wasHinted);
    map['notes_mode'] = Variable<bool>(notesMode);
    {
      map['elapsed'] = Variable<int>(
        $SavedGamesTable.$converterelapsed.toSql(elapsed),
      );
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SavedGamesCompanion toCompanion(bool nullToAbsent) {
    return SavedGamesCompanion(
      gameId: Value(gameId),
      difficulty: Value(difficulty),
      seed: Value(seed),
      givens: Value(givens),
      solution: Value(solution),
      cells: Value(cells),
      notes: Value(notes),
      history: Value(history),
      hints: Value(hints),
      wasHinted: Value(wasHinted),
      notesMode: Value(notesMode),
      elapsed: Value(elapsed),
      updatedAt: Value(updatedAt),
    );
  }

  factory SavedGameRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedGameRow(
      gameId: serializer.fromJson<String>(json['gameId']),
      difficulty: serializer.fromJson<String>(json['difficulty']),
      seed: serializer.fromJson<int>(json['seed']),
      givens: serializer.fromJson<List<int>>(json['givens']),
      solution: serializer.fromJson<List<int>>(json['solution']),
      cells: serializer.fromJson<List<int>>(json['cells']),
      notes: serializer.fromJson<List<int>>(json['notes']),
      history: serializer.fromJson<MoveHistory>(json['history']),
      hints: serializer.fromJson<List<int>>(json['hints']),
      wasHinted: serializer.fromJson<bool>(json['wasHinted']),
      notesMode: serializer.fromJson<bool>(json['notesMode']),
      elapsed: serializer.fromJson<Duration>(json['elapsed']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'gameId': serializer.toJson<String>(gameId),
      'difficulty': serializer.toJson<String>(difficulty),
      'seed': serializer.toJson<int>(seed),
      'givens': serializer.toJson<List<int>>(givens),
      'solution': serializer.toJson<List<int>>(solution),
      'cells': serializer.toJson<List<int>>(cells),
      'notes': serializer.toJson<List<int>>(notes),
      'history': serializer.toJson<MoveHistory>(history),
      'hints': serializer.toJson<List<int>>(hints),
      'wasHinted': serializer.toJson<bool>(wasHinted),
      'notesMode': serializer.toJson<bool>(notesMode),
      'elapsed': serializer.toJson<Duration>(elapsed),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SavedGameRow copyWith({
    String? gameId,
    String? difficulty,
    int? seed,
    List<int>? givens,
    List<int>? solution,
    List<int>? cells,
    List<int>? notes,
    MoveHistory? history,
    List<int>? hints,
    bool? wasHinted,
    bool? notesMode,
    Duration? elapsed,
    DateTime? updatedAt,
  }) => SavedGameRow(
    gameId: gameId ?? this.gameId,
    difficulty: difficulty ?? this.difficulty,
    seed: seed ?? this.seed,
    givens: givens ?? this.givens,
    solution: solution ?? this.solution,
    cells: cells ?? this.cells,
    notes: notes ?? this.notes,
    history: history ?? this.history,
    hints: hints ?? this.hints,
    wasHinted: wasHinted ?? this.wasHinted,
    notesMode: notesMode ?? this.notesMode,
    elapsed: elapsed ?? this.elapsed,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SavedGameRow copyWithCompanion(SavedGamesCompanion data) {
    return SavedGameRow(
      gameId: data.gameId.present ? data.gameId.value : this.gameId,
      difficulty: data.difficulty.present
          ? data.difficulty.value
          : this.difficulty,
      seed: data.seed.present ? data.seed.value : this.seed,
      givens: data.givens.present ? data.givens.value : this.givens,
      solution: data.solution.present ? data.solution.value : this.solution,
      cells: data.cells.present ? data.cells.value : this.cells,
      notes: data.notes.present ? data.notes.value : this.notes,
      history: data.history.present ? data.history.value : this.history,
      hints: data.hints.present ? data.hints.value : this.hints,
      wasHinted: data.wasHinted.present ? data.wasHinted.value : this.wasHinted,
      notesMode: data.notesMode.present ? data.notesMode.value : this.notesMode,
      elapsed: data.elapsed.present ? data.elapsed.value : this.elapsed,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedGameRow(')
          ..write('gameId: $gameId, ')
          ..write('difficulty: $difficulty, ')
          ..write('seed: $seed, ')
          ..write('givens: $givens, ')
          ..write('solution: $solution, ')
          ..write('cells: $cells, ')
          ..write('notes: $notes, ')
          ..write('history: $history, ')
          ..write('hints: $hints, ')
          ..write('wasHinted: $wasHinted, ')
          ..write('notesMode: $notesMode, ')
          ..write('elapsed: $elapsed, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    gameId,
    difficulty,
    seed,
    givens,
    solution,
    cells,
    notes,
    history,
    hints,
    wasHinted,
    notesMode,
    elapsed,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedGameRow &&
          other.gameId == this.gameId &&
          other.difficulty == this.difficulty &&
          other.seed == this.seed &&
          other.givens == this.givens &&
          other.solution == this.solution &&
          other.cells == this.cells &&
          other.notes == this.notes &&
          other.history == this.history &&
          other.hints == this.hints &&
          other.wasHinted == this.wasHinted &&
          other.notesMode == this.notesMode &&
          other.elapsed == this.elapsed &&
          other.updatedAt == this.updatedAt);
}

class SavedGamesCompanion extends UpdateCompanion<SavedGameRow> {
  final Value<String> gameId;
  final Value<String> difficulty;
  final Value<int> seed;
  final Value<List<int>> givens;
  final Value<List<int>> solution;
  final Value<List<int>> cells;
  final Value<List<int>> notes;
  final Value<MoveHistory> history;
  final Value<List<int>> hints;
  final Value<bool> wasHinted;
  final Value<bool> notesMode;
  final Value<Duration> elapsed;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SavedGamesCompanion({
    this.gameId = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.seed = const Value.absent(),
    this.givens = const Value.absent(),
    this.solution = const Value.absent(),
    this.cells = const Value.absent(),
    this.notes = const Value.absent(),
    this.history = const Value.absent(),
    this.hints = const Value.absent(),
    this.wasHinted = const Value.absent(),
    this.notesMode = const Value.absent(),
    this.elapsed = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SavedGamesCompanion.insert({
    required String gameId,
    required String difficulty,
    required int seed,
    required List<int> givens,
    required List<int> solution,
    required List<int> cells,
    required List<int> notes,
    required MoveHistory history,
    this.hints = const Value.absent(),
    this.wasHinted = const Value.absent(),
    this.notesMode = const Value.absent(),
    required Duration elapsed,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : gameId = Value(gameId),
       difficulty = Value(difficulty),
       seed = Value(seed),
       givens = Value(givens),
       solution = Value(solution),
       cells = Value(cells),
       notes = Value(notes),
       history = Value(history),
       elapsed = Value(elapsed),
       updatedAt = Value(updatedAt);
  static Insertable<SavedGameRow> custom({
    Expression<String>? gameId,
    Expression<String>? difficulty,
    Expression<int>? seed,
    Expression<String>? givens,
    Expression<String>? solution,
    Expression<String>? cells,
    Expression<String>? notes,
    Expression<String>? history,
    Expression<String>? hints,
    Expression<bool>? wasHinted,
    Expression<bool>? notesMode,
    Expression<int>? elapsed,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (gameId != null) 'game_id': gameId,
      if (difficulty != null) 'difficulty': difficulty,
      if (seed != null) 'seed': seed,
      if (givens != null) 'givens': givens,
      if (solution != null) 'solution': solution,
      if (cells != null) 'cells': cells,
      if (notes != null) 'notes': notes,
      if (history != null) 'history': history,
      if (hints != null) 'hints': hints,
      if (wasHinted != null) 'was_hinted': wasHinted,
      if (notesMode != null) 'notes_mode': notesMode,
      if (elapsed != null) 'elapsed': elapsed,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SavedGamesCompanion copyWith({
    Value<String>? gameId,
    Value<String>? difficulty,
    Value<int>? seed,
    Value<List<int>>? givens,
    Value<List<int>>? solution,
    Value<List<int>>? cells,
    Value<List<int>>? notes,
    Value<MoveHistory>? history,
    Value<List<int>>? hints,
    Value<bool>? wasHinted,
    Value<bool>? notesMode,
    Value<Duration>? elapsed,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SavedGamesCompanion(
      gameId: gameId ?? this.gameId,
      difficulty: difficulty ?? this.difficulty,
      seed: seed ?? this.seed,
      givens: givens ?? this.givens,
      solution: solution ?? this.solution,
      cells: cells ?? this.cells,
      notes: notes ?? this.notes,
      history: history ?? this.history,
      hints: hints ?? this.hints,
      wasHinted: wasHinted ?? this.wasHinted,
      notesMode: notesMode ?? this.notesMode,
      elapsed: elapsed ?? this.elapsed,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (gameId.present) {
      map['game_id'] = Variable<String>(gameId.value);
    }
    if (difficulty.present) {
      map['difficulty'] = Variable<String>(difficulty.value);
    }
    if (seed.present) {
      map['seed'] = Variable<int>(seed.value);
    }
    if (givens.present) {
      map['givens'] = Variable<String>(
        $SavedGamesTable.$convertergivens.toSql(givens.value),
      );
    }
    if (solution.present) {
      map['solution'] = Variable<String>(
        $SavedGamesTable.$convertersolution.toSql(solution.value),
      );
    }
    if (cells.present) {
      map['cells'] = Variable<String>(
        $SavedGamesTable.$convertercells.toSql(cells.value),
      );
    }
    if (notes.present) {
      map['notes'] = Variable<String>(
        $SavedGamesTable.$converternotes.toSql(notes.value),
      );
    }
    if (history.present) {
      map['history'] = Variable<String>(
        $SavedGamesTable.$converterhistory.toSql(history.value),
      );
    }
    if (hints.present) {
      map['hints'] = Variable<String>(
        $SavedGamesTable.$converterhints.toSql(hints.value),
      );
    }
    if (wasHinted.present) {
      map['was_hinted'] = Variable<bool>(wasHinted.value);
    }
    if (notesMode.present) {
      map['notes_mode'] = Variable<bool>(notesMode.value);
    }
    if (elapsed.present) {
      map['elapsed'] = Variable<int>(
        $SavedGamesTable.$converterelapsed.toSql(elapsed.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedGamesCompanion(')
          ..write('gameId: $gameId, ')
          ..write('difficulty: $difficulty, ')
          ..write('seed: $seed, ')
          ..write('givens: $givens, ')
          ..write('solution: $solution, ')
          ..write('cells: $cells, ')
          ..write('notes: $notes, ')
          ..write('history: $history, ')
          ..write('hints: $hints, ')
          ..write('wasHinted: $wasHinted, ')
          ..write('notesMode: $notesMode, ')
          ..write('elapsed: $elapsed, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StatisticsTable extends Statistics
    with TableInfo<$StatisticsTable, GameStatsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StatisticsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _gameIdMeta = const VerificationMeta('gameId');
  @override
  late final GeneratedColumn<String> gameId = GeneratedColumn<String>(
    'game_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _difficultyMeta = const VerificationMeta(
    'difficulty',
  );
  @override
  late final GeneratedColumn<String> difficulty = GeneratedColumn<String>(
    'difficulty',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _solvedMeta = const VerificationMeta('solved');
  @override
  late final GeneratedColumn<int> solved = GeneratedColumn<int>(
    'solved',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<Duration?, int> bestTime =
      GeneratedColumn<int>(
        'best_time',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<Duration?>($StatisticsTable.$converterbestTimen);
  @override
  List<GeneratedColumn> get $columns => [gameId, difficulty, solved, bestTime];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'statistics';
  @override
  VerificationContext validateIntegrity(
    Insertable<GameStatsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('game_id')) {
      context.handle(
        _gameIdMeta,
        gameId.isAcceptableOrUnknown(data['game_id']!, _gameIdMeta),
      );
    } else if (isInserting) {
      context.missing(_gameIdMeta);
    }
    if (data.containsKey('difficulty')) {
      context.handle(
        _difficultyMeta,
        difficulty.isAcceptableOrUnknown(data['difficulty']!, _difficultyMeta),
      );
    } else if (isInserting) {
      context.missing(_difficultyMeta);
    }
    if (data.containsKey('solved')) {
      context.handle(
        _solvedMeta,
        solved.isAcceptableOrUnknown(data['solved']!, _solvedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {gameId, difficulty};
  @override
  GameStatsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GameStatsRow(
      gameId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}game_id'],
      )!,
      difficulty: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}difficulty'],
      )!,
      solved: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}solved'],
      )!,
      bestTime: $StatisticsTable.$converterbestTimen.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}best_time'],
        ),
      ),
    );
  }

  @override
  $StatisticsTable createAlias(String alias) {
    return $StatisticsTable(attachedDatabase, alias);
  }

  static TypeConverter<Duration, int> $converterbestTime =
      const _DurationConverter();
  static TypeConverter<Duration?, int?> $converterbestTimen =
      NullAwareTypeConverter.wrap($converterbestTime);
}

class GameStatsRow extends DataClass implements Insertable<GameStatsRow> {
  /// Which game, as the same stable identifier a save uses.
  final String gameId;

  /// Which tier of it, as an identifier rather than a name a player reads.
  final String difficulty;

  /// How many puzzles have been finished here.
  final int solved;

  /// The fastest hint-free solve, or null if there has not been one.
  final Duration? bestTime;
  const GameStatsRow({
    required this.gameId,
    required this.difficulty,
    required this.solved,
    this.bestTime,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['game_id'] = Variable<String>(gameId);
    map['difficulty'] = Variable<String>(difficulty);
    map['solved'] = Variable<int>(solved);
    if (!nullToAbsent || bestTime != null) {
      map['best_time'] = Variable<int>(
        $StatisticsTable.$converterbestTimen.toSql(bestTime),
      );
    }
    return map;
  }

  StatisticsCompanion toCompanion(bool nullToAbsent) {
    return StatisticsCompanion(
      gameId: Value(gameId),
      difficulty: Value(difficulty),
      solved: Value(solved),
      bestTime: bestTime == null && nullToAbsent
          ? const Value.absent()
          : Value(bestTime),
    );
  }

  factory GameStatsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GameStatsRow(
      gameId: serializer.fromJson<String>(json['gameId']),
      difficulty: serializer.fromJson<String>(json['difficulty']),
      solved: serializer.fromJson<int>(json['solved']),
      bestTime: serializer.fromJson<Duration?>(json['bestTime']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'gameId': serializer.toJson<String>(gameId),
      'difficulty': serializer.toJson<String>(difficulty),
      'solved': serializer.toJson<int>(solved),
      'bestTime': serializer.toJson<Duration?>(bestTime),
    };
  }

  GameStatsRow copyWith({
    String? gameId,
    String? difficulty,
    int? solved,
    Value<Duration?> bestTime = const Value.absent(),
  }) => GameStatsRow(
    gameId: gameId ?? this.gameId,
    difficulty: difficulty ?? this.difficulty,
    solved: solved ?? this.solved,
    bestTime: bestTime.present ? bestTime.value : this.bestTime,
  );
  GameStatsRow copyWithCompanion(StatisticsCompanion data) {
    return GameStatsRow(
      gameId: data.gameId.present ? data.gameId.value : this.gameId,
      difficulty: data.difficulty.present
          ? data.difficulty.value
          : this.difficulty,
      solved: data.solved.present ? data.solved.value : this.solved,
      bestTime: data.bestTime.present ? data.bestTime.value : this.bestTime,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GameStatsRow(')
          ..write('gameId: $gameId, ')
          ..write('difficulty: $difficulty, ')
          ..write('solved: $solved, ')
          ..write('bestTime: $bestTime')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(gameId, difficulty, solved, bestTime);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GameStatsRow &&
          other.gameId == this.gameId &&
          other.difficulty == this.difficulty &&
          other.solved == this.solved &&
          other.bestTime == this.bestTime);
}

class StatisticsCompanion extends UpdateCompanion<GameStatsRow> {
  final Value<String> gameId;
  final Value<String> difficulty;
  final Value<int> solved;
  final Value<Duration?> bestTime;
  final Value<int> rowid;
  const StatisticsCompanion({
    this.gameId = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.solved = const Value.absent(),
    this.bestTime = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StatisticsCompanion.insert({
    required String gameId,
    required String difficulty,
    this.solved = const Value.absent(),
    this.bestTime = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : gameId = Value(gameId),
       difficulty = Value(difficulty);
  static Insertable<GameStatsRow> custom({
    Expression<String>? gameId,
    Expression<String>? difficulty,
    Expression<int>? solved,
    Expression<int>? bestTime,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (gameId != null) 'game_id': gameId,
      if (difficulty != null) 'difficulty': difficulty,
      if (solved != null) 'solved': solved,
      if (bestTime != null) 'best_time': bestTime,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StatisticsCompanion copyWith({
    Value<String>? gameId,
    Value<String>? difficulty,
    Value<int>? solved,
    Value<Duration?>? bestTime,
    Value<int>? rowid,
  }) {
    return StatisticsCompanion(
      gameId: gameId ?? this.gameId,
      difficulty: difficulty ?? this.difficulty,
      solved: solved ?? this.solved,
      bestTime: bestTime ?? this.bestTime,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (gameId.present) {
      map['game_id'] = Variable<String>(gameId.value);
    }
    if (difficulty.present) {
      map['difficulty'] = Variable<String>(difficulty.value);
    }
    if (solved.present) {
      map['solved'] = Variable<int>(solved.value);
    }
    if (bestTime.present) {
      map['best_time'] = Variable<int>(
        $StatisticsTable.$converterbestTimen.toSql(bestTime.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StatisticsCompanion(')
          ..write('gameId: $gameId, ')
          ..write('difficulty: $difficulty, ')
          ..write('solved: $solved, ')
          ..write('bestTime: $bestTime, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$NookDatabase extends GeneratedDatabase {
  _$NookDatabase(QueryExecutor e) : super(e);
  $NookDatabaseManager get managers => $NookDatabaseManager(this);
  late final $SavedGamesTable savedGames = $SavedGamesTable(this);
  late final $StatisticsTable statistics = $StatisticsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [savedGames, statistics];
}

typedef $$SavedGamesTableCreateCompanionBuilder = SavedGamesCompanion Function({
  required String gameId,
  required String difficulty,
  required int seed,
  required List<int> givens,
  required List<int> solution,
  required List<int> cells,
  required List<int> notes,
  required MoveHistory history,
  Value<List<int>> hints,
  Value<bool> wasHinted,
  Value<bool> notesMode,
  required Duration elapsed,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$SavedGamesTableUpdateCompanionBuilder = SavedGamesCompanion Function({
  Value<String> gameId,
  Value<String> difficulty,
  Value<int> seed,
  Value<List<int>> givens,
  Value<List<int>> solution,
  Value<List<int>> cells,
  Value<List<int>> notes,
  Value<MoveHistory> history,
  Value<List<int>> hints,
  Value<bool> wasHinted,
  Value<bool> notesMode,
  Value<Duration> elapsed,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$SavedGamesTableFilterComposer
    extends Composer<_$NookDatabase, $SavedGamesTable> {
  $$SavedGamesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get gameId => $composableBuilder(
    column: $table.gameId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seed => $composableBuilder(
    column: $table.seed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<int>, List<int>, String> get givens =>
      $composableBuilder(
        column: $table.givens,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<List<int>, List<int>, String> get solution =>
      $composableBuilder(
        column: $table.solution,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<List<int>, List<int>, String> get cells =>
      $composableBuilder(
        column: $table.cells,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<List<int>, List<int>, String> get notes =>
      $composableBuilder(
        column: $table.notes,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<MoveHistory, MoveHistory, String>
  get history => $composableBuilder(
    column: $table.history,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<int>, List<int>, String> get hints =>
      $composableBuilder(
        column: $table.hints,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get wasHinted => $composableBuilder(
    column: $table.wasHinted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get notesMode => $composableBuilder(
    column: $table.notesMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Duration, Duration, int> get elapsed =>
      $composableBuilder(
        column: $table.elapsed,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SavedGamesTableOrderingComposer
    extends Composer<_$NookDatabase, $SavedGamesTable> {
  $$SavedGamesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get gameId => $composableBuilder(
    column: $table.gameId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seed => $composableBuilder(
    column: $table.seed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get givens => $composableBuilder(
    column: $table.givens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get solution => $composableBuilder(
    column: $table.solution,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cells => $composableBuilder(
    column: $table.cells,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get history => $composableBuilder(
    column: $table.history,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hints => $composableBuilder(
    column: $table.hints,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get wasHinted => $composableBuilder(
    column: $table.wasHinted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get notesMode => $composableBuilder(
    column: $table.notesMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get elapsed => $composableBuilder(
    column: $table.elapsed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SavedGamesTableAnnotationComposer
    extends Composer<_$NookDatabase, $SavedGamesTable> {
  $$SavedGamesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get gameId =>
      $composableBuilder(column: $table.gameId, builder: (column) => column);

  GeneratedColumn<String> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => column,
  );

  GeneratedColumn<int> get seed =>
      $composableBuilder(column: $table.seed, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<int>, String> get givens =>
      $composableBuilder(column: $table.givens, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<int>, String> get solution =>
      $composableBuilder(column: $table.solution, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<int>, String> get cells =>
      $composableBuilder(column: $table.cells, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<int>, String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumnWithTypeConverter<MoveHistory, String> get history =>
      $composableBuilder(column: $table.history, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<int>, String> get hints =>
      $composableBuilder(column: $table.hints, builder: (column) => column);

  GeneratedColumn<bool> get wasHinted =>
      $composableBuilder(column: $table.wasHinted, builder: (column) => column);

  GeneratedColumn<bool> get notesMode =>
      $composableBuilder(column: $table.notesMode, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Duration, int> get elapsed =>
      $composableBuilder(column: $table.elapsed, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SavedGamesTableTableManager
    extends
        RootTableManager<
          _$NookDatabase,
          $SavedGamesTable,
          SavedGameRow,
          $$SavedGamesTableFilterComposer,
          $$SavedGamesTableOrderingComposer,
          $$SavedGamesTableAnnotationComposer,
          $$SavedGamesTableCreateCompanionBuilder,
          $$SavedGamesTableUpdateCompanionBuilder,
          (
            SavedGameRow,
            BaseReferences<_$NookDatabase, $SavedGamesTable, SavedGameRow>,
          ),
          SavedGameRow,
          PrefetchHooks Function()
        > {
  $$SavedGamesTableTableManager(_$NookDatabase db, $SavedGamesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedGamesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedGamesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavedGamesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> gameId = const Value.absent(),
                Value<String> difficulty = const Value.absent(),
                Value<int> seed = const Value.absent(),
                Value<List<int>> givens = const Value.absent(),
                Value<List<int>> solution = const Value.absent(),
                Value<List<int>> cells = const Value.absent(),
                Value<List<int>> notes = const Value.absent(),
                Value<MoveHistory> history = const Value.absent(),
                Value<List<int>> hints = const Value.absent(),
                Value<bool> wasHinted = const Value.absent(),
                Value<bool> notesMode = const Value.absent(),
                Value<Duration> elapsed = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SavedGamesCompanion(
                gameId: gameId,
                difficulty: difficulty,
                seed: seed,
                givens: givens,
                solution: solution,
                cells: cells,
                notes: notes,
                history: history,
                hints: hints,
                wasHinted: wasHinted,
                notesMode: notesMode,
                elapsed: elapsed,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String gameId,
                required String difficulty,
                required int seed,
                required List<int> givens,
                required List<int> solution,
                required List<int> cells,
                required List<int> notes,
                required MoveHistory history,
                Value<List<int>> hints = const Value.absent(),
                Value<bool> wasHinted = const Value.absent(),
                Value<bool> notesMode = const Value.absent(),
                required Duration elapsed,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SavedGamesCompanion.insert(
                gameId: gameId,
                difficulty: difficulty,
                seed: seed,
                givens: givens,
                solution: solution,
                cells: cells,
                notes: notes,
                history: history,
                hints: hints,
                wasHinted: wasHinted,
                notesMode: notesMode,
                elapsed: elapsed,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SavedGamesTableProcessedTableManager =
    ProcessedTableManager<
      _$NookDatabase,
      $SavedGamesTable,
      SavedGameRow,
      $$SavedGamesTableFilterComposer,
      $$SavedGamesTableOrderingComposer,
      $$SavedGamesTableAnnotationComposer,
      $$SavedGamesTableCreateCompanionBuilder,
      $$SavedGamesTableUpdateCompanionBuilder,
      (
        SavedGameRow,
        BaseReferences<_$NookDatabase, $SavedGamesTable, SavedGameRow>,
      ),
      SavedGameRow,
      PrefetchHooks Function()
    >;
typedef $$StatisticsTableCreateCompanionBuilder = StatisticsCompanion Function({
  required String gameId,
  required String difficulty,
  Value<int> solved,
  Value<Duration?> bestTime,
  Value<int> rowid,
});
typedef $$StatisticsTableUpdateCompanionBuilder = StatisticsCompanion Function({
  Value<String> gameId,
  Value<String> difficulty,
  Value<int> solved,
  Value<Duration?> bestTime,
  Value<int> rowid,
});

class $$StatisticsTableFilterComposer
    extends Composer<_$NookDatabase, $StatisticsTable> {
  $$StatisticsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get gameId => $composableBuilder(
    column: $table.gameId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get solved => $composableBuilder(
    column: $table.solved,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Duration?, Duration, int> get bestTime =>
      $composableBuilder(
        column: $table.bestTime,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$StatisticsTableOrderingComposer
    extends Composer<_$NookDatabase, $StatisticsTable> {
  $$StatisticsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get gameId => $composableBuilder(
    column: $table.gameId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get solved => $composableBuilder(
    column: $table.solved,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bestTime => $composableBuilder(
    column: $table.bestTime,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StatisticsTableAnnotationComposer
    extends Composer<_$NookDatabase, $StatisticsTable> {
  $$StatisticsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get gameId =>
      $composableBuilder(column: $table.gameId, builder: (column) => column);

  GeneratedColumn<String> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => column,
  );

  GeneratedColumn<int> get solved =>
      $composableBuilder(column: $table.solved, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Duration?, int> get bestTime =>
      $composableBuilder(column: $table.bestTime, builder: (column) => column);
}

class $$StatisticsTableTableManager
    extends
        RootTableManager<
          _$NookDatabase,
          $StatisticsTable,
          GameStatsRow,
          $$StatisticsTableFilterComposer,
          $$StatisticsTableOrderingComposer,
          $$StatisticsTableAnnotationComposer,
          $$StatisticsTableCreateCompanionBuilder,
          $$StatisticsTableUpdateCompanionBuilder,
          (
            GameStatsRow,
            BaseReferences<_$NookDatabase, $StatisticsTable, GameStatsRow>,
          ),
          GameStatsRow,
          PrefetchHooks Function()
        > {
  $$StatisticsTableTableManager(_$NookDatabase db, $StatisticsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StatisticsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StatisticsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StatisticsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> gameId = const Value.absent(),
                Value<String> difficulty = const Value.absent(),
                Value<int> solved = const Value.absent(),
                Value<Duration?> bestTime = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StatisticsCompanion(
                gameId: gameId,
                difficulty: difficulty,
                solved: solved,
                bestTime: bestTime,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String gameId,
                required String difficulty,
                Value<int> solved = const Value.absent(),
                Value<Duration?> bestTime = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StatisticsCompanion.insert(
                gameId: gameId,
                difficulty: difficulty,
                solved: solved,
                bestTime: bestTime,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StatisticsTableProcessedTableManager =
    ProcessedTableManager<
      _$NookDatabase,
      $StatisticsTable,
      GameStatsRow,
      $$StatisticsTableFilterComposer,
      $$StatisticsTableOrderingComposer,
      $$StatisticsTableAnnotationComposer,
      $$StatisticsTableCreateCompanionBuilder,
      $$StatisticsTableUpdateCompanionBuilder,
      (
        GameStatsRow,
        BaseReferences<_$NookDatabase, $StatisticsTable, GameStatsRow>,
      ),
      GameStatsRow,
      PrefetchHooks Function()
    >;

class $NookDatabaseManager {
  final _$NookDatabase _db;
  $NookDatabaseManager(this._db);
  $$SavedGamesTableTableManager get savedGames =>
      $$SavedGamesTableTableManager(_db, _db.savedGames);
  $$StatisticsTableTableManager get statistics =>
      $$StatisticsTableTableManager(_db, _db.statistics);
}
