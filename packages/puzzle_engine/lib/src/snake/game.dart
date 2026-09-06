import 'package:meta/meta.dart';

import '../random.dart';
import 'spec.dart';

/// Whether the snake is still travelling or has hit something.
///
/// Nameless like every engine enum. There is no "won" here: a Snake run ends
/// only when the snake dies, and how far it got is its [SnakeGame.score].
enum SnakeStatus {
  /// The snake is alive and moving.
  running,

  /// The snake has run into a wall or into itself; the run is over.
  dead,
}

/// One frame of a Snake game: where the snake is, which way it is going, where
/// the food is, how much it has eaten, and whether it is still alive.
///
/// **Immutable and clock-free by design.** Like every other Nook game state it
/// is a pure value: [step] takes a frame and returns the next one, reading no
/// clock and touching no I/O, so a whole run is reproducible from a seed and can
/// be tested without pumping a single frame. What turns those steps into
/// real-time play — a timer ticking [step] on an interval — lives in the board
/// widget, never here, exactly as `_DuoBoardState` owns its timers while
/// `DuoGameState` stays pure.
///
/// The snake is [body], a list of cell indices with the **head first**. Food is
/// a single cell, or `-1` in the (unreachable in normal play) case that the
/// snake has filled the board and there is nowhere left to put any. Randomness
/// is a seeded stream carried as a plain integer, [rngState]: each food is
/// placed from it and the advanced state stored back, so the sequence of food a
/// run sees is fixed by [seed] alone.
@immutable
class SnakeGame {
  SnakeGame._({
    required this.spec,
    required List<int> body,
    required this.direction,
    required this.food,
    required this.score,
    required this.status,
    required this.seed,
    required this.rngState,
  }) : body = List<int>.unmodifiable(body),
       _occupied = Set<int>.of(body);

  /// Begins a run on [spec], with the first food placed from [seed].
  ///
  /// The snake starts [SnakeSpec.startLength] long in the middle of the board,
  /// its head travelling [SnakeSpec.startDirection] and its tail laid out behind
  /// it, so the first thing the player does is decide where an already-moving
  /// snake turns.
  factory SnakeGame.start(SnakeSpec spec, {int seed = 0}) {
    spec.validate();

    final int headRow = spec.rows ~/ 2;
    final int headColumn = spec.cols ~/ 2;
    // The tail is laid out behind the head, one cell per segment against the
    // way it travels, so the whole snake sits in a straight line already moving.
    final SnakeDirection back = spec.startDirection.opposite;
    final List<int> body = <int>[
      for (int i = 0; i < spec.startLength; i++)
        spec.indexOf(headRow + back.dRow * i, headColumn + back.dColumn * i),
    ];

    final PuzzleRandom random = PuzzleRandom(seed);
    final int food = _placeFood(random, body, spec.cellCount);

    return SnakeGame._(
      spec: spec,
      body: body,
      direction: spec.startDirection,
      food: food,
      score: 0,
      status: SnakeStatus.running,
      seed: seed,
      rngState: random.state,
    );
  }

  /// The board this game is played on.
  final SnakeSpec spec;

  /// The snake, head first: `body.first` is the head, `body.last` the tail tip.
  final List<int> body;

  /// The membership set behind [occupies], built once so the board can ask
  /// "is the snake on this cell?" for every cell it draws without scanning
  /// [body] each time.
  final Set<int> _occupied;

  /// The way the snake is currently travelling.
  final SnakeDirection direction;

  /// The cell the food sits on, or `-1` when the board is full.
  final int food;

  /// How many pieces of food the snake has eaten — the run's score.
  final int score;

  /// Whether the snake is still alive.
  final SnakeStatus status;

  /// The seed the run was started from, kept as provenance.
  final int seed;

  /// The seeded stream's state, from which the *next* food will be placed.
  ///
  /// Carrying the generator's state as a value rather than keeping a live
  /// [PuzzleRandom] is what lets this whole class stay immutable: [step]
  /// reconstructs the stream from here, draws a cell, and stores the advanced
  /// state on the frame it returns.
  final int rngState;

  /// The head cell.
  int get head => body.first;

  /// How long the snake is.
  int get length => body.length;

  /// Whether the snake is dead.
  bool get isDead => status == SnakeStatus.dead;

  /// Whether the snake occupies [index].
  bool occupies(int index) => _occupied.contains(index);

  /// The next frame, after trying to turn to [intended] and taking one step.
  ///
  /// Pure: it reads no clock and returns a new [SnakeGame] rather than mutating
  /// this one. A dead game steps to itself. A [intended] that is a straight
  /// reversal of the current heading is ignored — the snake keeps its heading
  /// rather than driving into its own neck. The head then moves one cell:
  ///
  ///  * off the board, or into a part of the snake that will still be there
  ///    after the tail has moved, ends the run ([SnakeStatus.dead]);
  ///  * onto the food grows the snake by one and places the next food;
  ///  * onto empty ground moves the whole snake forward one cell.
  SnakeGame step(SnakeDirection intended) {
    if (status == SnakeStatus.dead) {
      return this;
    }

    // A straight reversal is ignored: the snake carries on the way it was.
    final SnakeDirection heading = intended.isReverseOf(direction)
        ? direction
        : intended;

    final int? next = spec.neighbour(head, heading);
    if (next == null) {
      // Ran into a wall. The snake does not move onto the wall; it stops where
      // it was, now dead, facing the way it tried to go.
      return _copyWith(heading: heading, status: SnakeStatus.dead);
    }

    final bool eating = next == food;

    // The tail vacates its cell on a plain move, so stepping onto where the tail
    // is about to leave is allowed; when the snake is growing the tail stays, so
    // the whole body counts. Either way, running into an occupied cell is death.
    final bool hitsSelf = eating
        ? _occupied.contains(next)
        : _occupied.contains(next) && next != body.last;
    if (hitsSelf) {
      return _copyWith(heading: heading, status: SnakeStatus.dead);
    }

    final List<int> grown = <int>[next, ...body];
    if (!eating) {
      grown.removeLast();
    }

    if (!eating) {
      return _copyWith(heading: heading, body: grown);
    }

    // Ate: grow, score, and place the next food from the carried stream over the
    // snake's new position.
    final PuzzleRandom random = PuzzleRandom(rngState);
    final int nextFood = _placeFood(random, grown, spec.cellCount);
    return _copyWith(
      heading: heading,
      body: grown,
      food: nextFood,
      score: score + 1,
      rngState: random.state,
    );
  }

  /// A random empty cell for the food among [cellCount] cells, or `-1` if
  /// [occupied] fills the board.
  ///
  /// The empties are gathered in ascending index order so the choice is a pure
  /// function of [random]'s state — the same seed always drops food in the same
  /// places.
  static int _placeFood(
    PuzzleRandom random,
    List<int> occupied,
    int cellCount,
  ) {
    final Set<int> taken = Set<int>.of(occupied);
    final List<int> empties = <int>[
      for (int cell = 0; cell < cellCount; cell++)
        if (!taken.contains(cell)) cell,
    ];
    if (empties.isEmpty) {
      return -1;
    }
    return empties[random.nextInt(empties.length)];
  }

  SnakeGame _copyWith({
    List<int>? body,
    SnakeDirection? heading,
    int? food,
    int? score,
    SnakeStatus? status,
    int? rngState,
  }) {
    return SnakeGame._(
      spec: spec,
      body: body ?? this.body,
      direction: heading ?? direction,
      food: food ?? this.food,
      score: score ?? this.score,
      status: status ?? this.status,
      seed: seed,
      rngState: rngState ?? this.rngState,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SnakeGame &&
      other.spec == spec &&
      other.direction == direction &&
      other.food == food &&
      other.score == score &&
      other.status == status &&
      other.seed == seed &&
      other.rngState == rngState &&
      _sameBody(other.body, body);

  @override
  int get hashCode => Object.hash(
    spec,
    direction,
    food,
    score,
    status,
    seed,
    rngState,
    Object.hashAll(body),
  );

  static bool _sameBody(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  String toString() =>
      'SnakeGame($spec, length $length, score $score, ${status.name})';
}
