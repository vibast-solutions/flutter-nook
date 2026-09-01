import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

/// Assembles Nook's [ThemeData] from a token set.
///
/// Screens read colours from [NookColors] rather than from Material's scheme;
/// what is configured here is only what Material itself needs in order not to
/// contradict the design.
ThemeData buildNookTheme(NookColors colors) {
  return ThemeData(
    useMaterial3: true,
    fontFamily: NookFonts.body,
    scaffoldBackgroundColor: colors.sand,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: colors.clay,
          surface: colors.surface,
        ).copyWith(
          primary: colors.clay,
          secondary: colors.sage,
          onPrimary: colors.surface,
          onSurface: colors.ink,
        ),
    splashFactory: InkSparkle.splashFactory,
    extensions: <ThemeExtension<dynamic>>[colors],
  );
}
