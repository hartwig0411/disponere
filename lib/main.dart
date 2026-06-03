import 'package:flutter/material.dart';
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
      theme: ThemeData.dark(),
      home: const JournalScreen(),
    );
  }
}