/// A string literal found in Dart source, with the interpolations taken out.
///
/// [text] is what the literal contributes verbatim: `'Row $n, column $m'`
/// yields `Row , column `. That is the part a translator would have to own, so
/// it is the part worth checking.
class DartStringLiteral {
  const DartStringLiteral({required this.text, required this.line});

  /// The literal's static text, with `$x` and `${...}` removed.
  final String text;

  /// The one-based line the literal starts on.
  final int line;
}

/// Pulls every string literal out of [source], skipping comments.
///
/// Written by hand rather than with a parser package so that the guard test
/// this feeds needs no dependency of its own — a check that is awkward to run
/// is a check that gets turned off. It understands the parts of Dart's string
/// syntax that appear in real code: single and double quotes, triple quotes,
/// raw strings, escapes, and both interpolation forms including nested braces.
///
/// Import, export and part directives are skipped: their URIs are strings, and
/// none of them is anything a player reads.
List<DartStringLiteral> findStringLiterals(String source) {
  final List<DartStringLiteral> found = <DartStringLiteral>[];
  int line = 1;
  int i = 0;

  bool startsDirective() {
    final int lineStart = source.lastIndexOf('\n', i) + 1;
    final String before = source.substring(lineStart, i).trimLeft();
    return before.startsWith('import ') ||
        before.startsWith('export ') ||
        before.startsWith('part ') ||
        before.startsWith('part of ');
  }

  while (i < source.length) {
    final String c = source[i];

    if (c == '\n') {
      line++;
      i++;
      continue;
    }

    // Comments.
    if (c == '/' && i + 1 < source.length) {
      if (source[i + 1] == '/') {
        while (i < source.length && source[i] != '\n') {
          i++;
        }
        continue;
      }
      if (source[i + 1] == '*') {
        // Dart block comments nest.
        int depth = 1;
        i += 2;
        while (i < source.length && depth > 0) {
          if (source.startsWith('/*', i)) {
            depth++;
            i += 2;
          } else if (source.startsWith('*/', i)) {
            depth--;
            i += 2;
          } else {
            if (source[i] == '\n') {
              line++;
            }
            i++;
          }
        }
        continue;
      }
    }

    if (c != "'" && c != '"' && !(c == 'r' && _quoteFollows(source, i + 1))) {
      i++;
      continue;
    }

    final bool isRaw = c == 'r';
    final int quoteAt = isRaw ? i + 1 : i;
    final String quote = source[quoteAt];
    final bool triple = source.startsWith(quote * 3, quoteAt);
    final String terminator = triple ? quote * 3 : quote;
    final int startLine = line;
    final bool skip = startsDirective();

    int j = quoteAt + terminator.length;
    final StringBuffer text = StringBuffer();
    while (j < source.length && !source.startsWith(terminator, j)) {
      final String d = source[j];
      if (d == '\n') {
        line++;
        text.write(d);
        j++;
      } else if (!isRaw && d == r'\') {
        // An escape contributes a character, but not one worth reading.
        text.write('_');
        j += 2;
      } else if (!isRaw && d == r'$') {
        j = _skipInterpolation(source, j);
      } else {
        text.write(d);
        j++;
      }
    }

    if (!skip) {
      found.add(DartStringLiteral(text: text.toString(), line: startLine));
    }
    i = j + terminator.length;
  }

  return found;
}

bool _quoteFollows(String source, int at) =>
    at < source.length && (source[at] == "'" || source[at] == '"');

/// Returns the index just past the `$...` interpolation starting at [at].
int _skipInterpolation(String source, int at) {
  int j = at + 1;
  if (j < source.length && source[j] == '{') {
    int depth = 1;
    j++;
    while (j < source.length && depth > 0) {
      if (source[j] == '{') {
        depth++;
      } else if (source[j] == '}') {
        depth--;
      }
      j++;
    }
    return j;
  }
  while (j < source.length && _isIdentifierChar(source[j])) {
    j++;
  }
  return j;
}

bool _isIdentifierChar(String c) {
  final int code = c.codeUnitAt(0);
  return (code >= 0x30 && code <= 0x39) || // 0-9
      (code >= 0x41 && code <= 0x5A) || // A-Z
      (code >= 0x61 && code <= 0x7A) || // a-z
      c == '_';
}
