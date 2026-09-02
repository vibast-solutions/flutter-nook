import 'package:flutter/material.dart';

/// Nook's two typefaces, both bundled with the app.
///
/// They are assets rather than a runtime download: Nook promises no network
/// traffic, and a font fetched on first launch would quietly break that (and
/// leave the app looking wrong offline).
abstract final class NookFonts {
  /// The wordmark and headings.
  static const String display = 'Fredoka';

  /// Body copy and every digit on a board.
  static const String body = 'Nunito';
}

/// Builds a [TextStyle] at [weight] in one of Nook's families.
///
/// Both fonts ship as single variable files, so weight is applied on the
/// `wght` axis as well as through [FontWeight] — set only the latter and every
/// weight renders identically.
TextStyle nookText({
  required double size,
  required int weight,
  String family = NookFonts.body,
  Color? color,
  double? height,
  double? letterSpacing,
}) {
  return TextStyle(
    fontFamily: family,
    fontSize: size,
    fontWeight: FontWeight.values[(weight ~/ 100) - 1],
    fontVariations: <FontVariation>[FontVariation('wght', weight.toDouble())],
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

/// The type ramp. Sizes come from the screen designs.
abstract final class NookType {
  /// The Nook wordmark.
  static TextStyle wordmark(Color color) => nookText(
    size: 30,
    weight: 600,
    family: NookFonts.display,
    color: color,
    letterSpacing: -0.4,
  );

  /// The name of a screen, in the display face.
  ///
  /// Smaller than the [wordmark]: the home screen says "Nook", every screen
  /// below it says where you are.
  static TextStyle screenTitle(Color color) => nookText(
    size: 23,
    weight: 600,
    family: NookFonts.display,
    color: color,
    letterSpacing: -0.2,
  );

  /// A screen or card title.
  static TextStyle title(Color color) =>
      nookText(size: 17, weight: 800, color: color);

  /// A row title in a list.
  static TextStyle rowTitle(Color color) =>
      nookText(size: 15.5, weight: 800, color: color);

  /// The supporting line under a row title.
  static TextStyle rowSubtitle(Color color) =>
      nookText(size: 12.5, weight: 600, color: color);

  /// A small uppercase section heading.
  static TextStyle sectionLabel(Color color) =>
      nookText(size: 12, weight: 700, color: color, letterSpacing: 0.9);

  /// A digit inside a board cell. [size] scales with the cell.
  static TextStyle cellDigit(Color color, double size) =>
      nookText(size: size, weight: 800, color: color, height: 1);

  /// One pencil mark inside a board cell. [size] scales with the cell.
  static TextStyle cellNote(Color color, double size) =>
      nookText(size: size, weight: 700, color: color, height: 1);

  /// The large digit on a number-pad key.
  static TextStyle padDigit(Color color, double size) =>
      nookText(size: size, weight: 800, color: color, height: 1);

  /// The remaining-count under a number-pad key.
  static TextStyle padCount(Color color) =>
      nookText(size: 10, weight: 700, color: color);

  /// The word under an icon in the board's action row.
  static TextStyle actionLabel(Color color) =>
      nookText(size: 11, weight: 700, color: color);

  /// The quiet line at the bottom of a screen.
  static TextStyle footnote(Color color) =>
      nookText(size: 12, weight: 600, color: color);
}
