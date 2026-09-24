import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../services/draft_store.dart';

/// Dezente Hinweiszeile im Sheet, wenn ein Entwurf wiederhergestellt wurde
/// (E-05): „Entwurf von 14:32 wiederhergestellt · Verwerfen“. „Verwerfen“ ist
/// der einzige bewusste Weg, einen alten Entwurf loszuwerden — die Sheets
/// haben keinen Abbrechen-Knopf, und Wegwischen behält den Entwurf.
class DraftHint extends StatelessWidget {
  final DateTime restoredAt;
  final VoidCallback onDiscard;

  const DraftHint({
    super.key,
    required this.restoredAt,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.history, size: 18, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Entwurf von ${formatDraftTime(restoredAt)} wiederhergestellt',
              style: const TextStyle(color: AppColors.text, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: onDiscard,
            child: const Text(
              'Verwerfen',
              style: TextStyle(color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }
}
