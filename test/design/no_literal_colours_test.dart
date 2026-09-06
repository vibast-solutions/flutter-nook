import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Nook's rule that **screens never write a literal colour** — every colour is
/// read from `Theme.of(context).nook`, so a theme is added by adding a
/// [NookColors] instance and touching no screen — is enforced here rather than
/// trusted. This is the "no-literal-colour test" the design rules refer to.
///
/// The one place a literal colour is allowed is `lib/design/tokens.dart`, where
/// the palette is actually defined; everywhere else a `Color(0x…)`,
/// `Color.fromARGB`/`fromRGBO`, or a Material `Colors.*` value is a colour that
/// has escaped the token set, and this test fails on it. Comments are ignored,
/// so doc references like `[NookColors.clay]` are fine.
void main() {
  // The single file where colours are defined, exempt from the rule.
  const String palette = 'lib/design/tokens.dart';

  // A literal colour: a hex/ARGB/RGBO `Color`, or a Material palette value. The
  // word boundary before `Colors` keeps `NookColors.` — the token set itself —
  // from matching.
  final RegExp literalColour = RegExp(
    r'\bColor\(0x|\bColor\.fromARGB\(|\bColor\.fromRGBO\(|\bColors\.',
  );

  // Strips `//` line comments (doc comments included) so prose that names a
  // colour is never mistaken for one written into a screen.
  String withoutComments(String line) {
    final int slashes = line.indexOf('//');
    return slashes == -1 ? line : line.substring(0, slashes);
  }

  test('no screen writes a literal colour — every colour comes from a token', () {
    final List<String> offences = <String>[];

    for (final FileSystemEntity entity in Directory(
      'lib',
    ).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      if (entity.path.replaceAll(r'\', '/').endsWith(palette)) {
        continue;
      }
      final List<String> lines = entity.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        if (literalColour.hasMatch(withoutComments(lines[i]))) {
          offences.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }

    expect(
      offences,
      isEmpty,
      reason:
          'Colours must be read from Theme.of(context).nook, not written as '
          'literals. Move these into a NookColors token:\n${offences.join('\n')}',
    );
  });
}
