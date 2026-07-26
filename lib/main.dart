import 'package:flutter/material.dart';
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
      home: const JournalScreen(),
    );
  }
}
