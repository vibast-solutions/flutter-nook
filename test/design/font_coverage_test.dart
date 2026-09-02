import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/design/typography.dart';

import 'ttf_coverage.dart';

/// The letters each language Nook wants to speak cannot do without.
///
/// Not the whole alphabet — the accented characters, which are what a font
/// subset drops. A font that can set these can set the language.
const Map<String, String> accentedLetters = <String, String>{
  'English': '',
  'German': 'äöüßÄÖÜ',
  'Spanish': 'áéíóúüñ¿¡ÁÉÍÓÚÑ',
  'Italian': 'àèéìòùÀÈÉÌÒÙ',
  'Portuguese': 'ãõáâàéêíóôúçÃÕÁÂÀÉÊÍÓÔÚÇ',
  'Romanian': 'ăâîșțĂÂÎȘȚ',
  'Czech': 'áčďéěíňóřšťúůýžÁČĎÉĚÍŇÓŘŠŤÚŮÝŽ',
};

/// Which of those a font can actually draw.
Set<String> languagesCoveredBy(Set<int> codepoints) {
  return <String>{
    for (final MapEntry<String, String> language in accentedLetters.entries)
      if (language.value.runes.every(codepoints.contains)) language.key,
  };
}

Set<int> coverageOf(String family) => supportedCodepoints(
  File('assets/fonts/$family-Variable.ttf').readAsBytesSync(),
);

/// Every character that appears in a message the app can show.
Set<int> shippedCharacters() {
  final Map<String, dynamic> arb = jsonDecode(
    File('lib/l10n/app_en.arb').readAsStringSync(),
  ) as Map<String, dynamic>;
  final Set<int> characters = <int>{};
  for (final MapEntry<String, dynamic> entry in arb.entries) {
    // Keys starting with @ hold notes for translators, which nobody renders.
    if (entry.key.startsWith('@')) {
      continue;
    }
    characters.addAll((entry.value as String).runes);
  }
  return characters;
}

void main() {
  group('the bundled fonts can draw what the app says', () {
    test('every character in every shipped message', () {
      // The strongest form of this check: rather than a list of characters
      // someone remembered to write down, it reads the messages themselves. A
      // new message with a character neither font has fails here, at the point
      // the message is added, rather than as an empty box on a phone.
      final Set<int> shipped = shippedCharacters();
      expect(shipped, isNotEmpty, reason: 'the .arb should not be empty');

      for (final String family in <String>[NookFonts.display, NookFonts.body]) {
        final Set<int> covered = coverageOf(family);
        final List<String> missing = shipped
            .where((int c) => !covered.contains(c))
            // ICU syntax characters are consumed by the formatter, and a
            // newline is not drawn.
            .where((int c) => c != 0x0A)
            .map(String.fromCharCode)
            .toList();
        expect(
          missing,
          isEmpty,
          reason: '$family cannot draw ${missing.join()}',
        );
      }
    });

    test('the body font is ready for every language Nook plans', () {
      // Nunito sets all of them, so nothing a player reads on a board or in a
      // row of copy will ever be a box.
      expect(
        languagesCoveredBy(coverageOf(NookFonts.body)),
        accentedLetters.keys.toSet(),
      );
    });

    test('the display font covers exactly what it is recorded as covering', () {
      // Fredoka ships as a 320-codepoint build with no Latin Extended-A: it
      // cannot set Czech or Romanian. Nothing renders as a box today, because
      // English is the only language filled in — but the day one of those two
      // is added, the wordmark and the screen titles are where it shows.
      //
      // This is written as an equality rather than a list of what works, so
      // that swapping the display font — or Fredoka gaining glyphs upstream —
      // fails here and has to be looked at, in either direction. Deciding what
      // to do about it is VIB-82.
      expect(languagesCoveredBy(coverageOf(NookFonts.display)), <String>{
        'English',
        'German',
        'Spanish',
        'Italian',
        'Portuguese',
      });
    });
  });

  group('the coverage reader', () {
    test('reads a real font rather than guessing', () {
      final Set<int> nunito = coverageOf(NookFonts.body);
      // Sanity: the letter A, and a character no Latin font has.
      expect(nunito.contains(0x41), isTrue);
      expect(nunito.contains(0x4E00), isFalse, reason: 'that is a CJK glyph');
      expect(nunito.length, greaterThan(300));
    });

    test('rejects something that is not a font', () {
      expect(
        () => supportedCodepoints(Uint8List.fromList(List<int>.filled(64, 0))),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
