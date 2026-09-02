import 'dart:typed_data';

/// Reads which characters a TrueType/OpenType font can actually draw.
///
/// Fonts are routinely shipped as subsets — a build carrying only the letters
/// one language needs is smaller, and Nook bundles its fonts rather than
/// fetching them, so size matters. The risk is that a subset silently drops
/// the letters a language needs and every one of them renders as a blank box
/// on the player's phone, which is not the kind of thing anyone notices in an
/// English test run. Hence reading the font rather than trusting it.
///
/// Only the `cmap` table is parsed, and only formats 4 and 12 of it, which is
/// what every font in practical use provides for Unicode.
Set<int> supportedCodepoints(Uint8List bytes) {
  final ByteData data = ByteData.sublistView(bytes);
  final int cmapStart = _findTable(data, 'cmap');
  if (cmapStart < 0) {
    throw const FormatException('the font has no cmap table');
  }

  final int subtableCount = data.getUint16(cmapStart + 2);
  final Set<int> codepoints = <int>{};
  bool readAny = false;

  // Every Unicode subtable is read and the results unioned, rather than one
  // being picked as "the best". A font may split its coverage across a
  // format 4 subtable and a format 12 one, and reading only the richer-looking
  // of the two would under-report what it can draw — which for this check
  // would be a false alarm rather than a missed one, but a check that cries
  // wolf gets deleted.
  for (int i = 0; i < subtableCount; i++) {
    final int record = cmapStart + 4 + i * 8;
    final int platform = data.getUint16(record);
    final int encoding = data.getUint16(record + 2);
    final int offset = data.getUint32(record + 4);
    final bool isUnicode =
        platform == 0 || (platform == 3 && (encoding == 1 || encoding == 10));
    if (!isUnicode) {
      continue;
    }
    final int start = cmapStart + offset;
    final int format = data.getUint16(start);
    if (format == 4) {
      codepoints.addAll(_readFormat4(data, start));
      readAny = true;
    } else if (format == 12) {
      codepoints.addAll(_readFormat12(data, start));
      readAny = true;
    }
  }

  if (!readAny) {
    throw const FormatException(
      'the cmap table has no Unicode subtable in format 4 or 12',
    );
  }
  return codepoints;
}

/// The offset of [tag] in the font's table directory, or -1.
int _findTable(ByteData data, String tag) {
  final int count = data.getUint16(4);
  for (int i = 0; i < count; i++) {
    final int record = 12 + i * 16;
    final String found = String.fromCharCodes(<int>[
      data.getUint8(record),
      data.getUint8(record + 1),
      data.getUint8(record + 2),
      data.getUint8(record + 3),
    ]);
    if (found == tag) {
      return data.getUint32(record + 8);
    }
  }
  return -1;
}

/// Segment mapping to delta values — the usual Basic Multilingual Plane cmap.
Set<int> _readFormat4(ByteData data, int start) {
  final Set<int> codepoints = <int>{};
  final int segCountX2 = data.getUint16(start + 6);
  final int segCount = segCountX2 ~/ 2;
  final int endsAt = start + 14;
  final int startsAt = endsAt + segCountX2 + 2;
  final int deltasAt = startsAt + segCountX2;
  final int rangesAt = deltasAt + segCountX2;

  for (int seg = 0; seg < segCount; seg++) {
    final int end = data.getUint16(endsAt + seg * 2);
    final int begin = data.getUint16(startsAt + seg * 2);
    if (begin > end) {
      continue;
    }
    final int delta = data.getInt16(deltasAt + seg * 2);
    final int rangeOffset = data.getUint16(rangesAt + seg * 2);

    for (int c = begin; c <= end && c != 0xFFFF; c++) {
      int glyph;
      if (rangeOffset == 0) {
        glyph = (c + delta) & 0xFFFF;
      } else {
        final int at = rangesAt + seg * 2 + rangeOffset + (c - begin) * 2;
        if (at + 1 >= data.lengthInBytes) {
          continue;
        }
        glyph = data.getUint16(at);
        if (glyph != 0) {
          glyph = (glyph + delta) & 0xFFFF;
        }
      }
      // Glyph 0 is the box a font draws when it has nothing to draw.
      if (glyph != 0) {
        codepoints.add(c);
      }
    }
  }
  return codepoints;
}

/// Segmented coverage, used by fonts that reach beyond the BMP.
Set<int> _readFormat12(ByteData data, int start) {
  final Set<int> codepoints = <int>{};
  final int groups = data.getUint32(start + 12);
  for (int i = 0; i < groups; i++) {
    final int group = start + 16 + i * 12;
    final int begin = data.getUint32(group);
    final int end = data.getUint32(group + 4);
    for (int c = begin; c <= end; c++) {
      codepoints.add(c);
    }
  }
  return codepoints;
}
