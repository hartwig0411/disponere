import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../tags/tag_view_screen.dart';

/// Tag-Chip im Akzentblau. Antippen öffnet die Tag-Ansicht — „alles zu diesem
/// Tag über alle Tage". Der Chip navigiert über seinen eigenen `context`, damit
/// die Karten (Eintrag, Termin, Aufgabe) nichts durchreichen müssen.
class TagChip extends StatelessWidget {
  final String label;
  const TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.tagChipBg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TagViewScreen(tag: label)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            '#$label',
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
