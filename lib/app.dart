import 'package:flutter/material.dart';

import 'design/theme.dart';
import 'design/tokens.dart';
import 'home/home_screen.dart';
import 'l10n/app_localizations.dart';

/// The Nook application.
///
/// The app follows the system locale and offers no language picker: there is
/// no settings screen to put one in yet, and a player whose phone is in German
/// should not have to find a switch to be spoken to in German. Only English is
/// filled in today — the rest of the seam is built, so a new language is one
/// `.arb` file and a line in `supportedLocales`.
class NookApp extends StatelessWidget {
  const NookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Resolved per locale rather than passed as a literal, because this is
      // the name the platform task switcher shows.
      onGenerateTitle: (BuildContext context) =>
          AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      theme: buildNookTheme(NookColors.softClay),
      home: const HomeScreen(),
    );
  }
}
