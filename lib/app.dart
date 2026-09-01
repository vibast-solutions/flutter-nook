import 'package:flutter/material.dart';

import 'design/theme.dart';
import 'design/tokens.dart';
import 'home/home_screen.dart';

/// The Nook application.
class NookApp extends StatelessWidget {
  const NookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nook',
      debugShowCheckedModeBanner: false,
      theme: buildNookTheme(NookColors.softClay),
      home: const HomeScreen(),
    );
  }
}
