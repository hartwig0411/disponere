import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'theme/app_colors.dart';
import 'screens/journal/journal_screen.dart';

void main() {
  runApp(const DisponereApp());
}

class DisponereApp extends StatelessWidget {
  const DisponereApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Disponere',
      debugShowCheckedModeBanner: false,
      theme: AppColors.buildLightTheme(),
      // Deutsch als einzige Sprache: der Material-Datumsdialog (datierter
      // Eintrag) und alle Standard-Widgets erscheinen auf Deutsch. Die App
      // formatiert ihre eigenen Datumsangaben zwar von Hand (deutsche Wochen-
      // und Monatsnamen), aber die eingebauten Dialoge brauchen diese
      // Delegates. Bewusst nur `de` — ein Ein-Nutzer-Journal, kein Sprachwahl.
      locale: const Locale('de'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de')],
      home: const JournalScreen(),
    );
  }
}
