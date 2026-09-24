import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Das kleine ⋮-Symbol an einer Karte (E-06, v6.17).
///
/// Seit Text überall markierbar ist, gehört das lange Drücken einheitlich der
/// Markier-Geste. Die Aktionen, die vorher am langen Drücken hingen
/// (Aktionsblatt am Eintrag, Brücke an Aufgabe und Termin), öffnen sich
/// inhaltlich unverändert über dieses Symbol.
///
/// Bewusst dezent (Platzhalter-Grau, kleines Icon), aber mit einer Trefffläche,
/// die Finger und Stift zuverlässig erwischen. Liegt in einer
/// `SelectionContainer.disabled`, damit das Symbol nie Teil einer
/// Text-Auswahl wird.
class CardMenuButton extends StatelessWidget {
  final VoidCallback onPressed;
  const CardMenuButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SelectionContainer.disabled(
      child: IconButton(
        onPressed: onPressed,
        tooltip: 'Aktionen',
        icon: const Icon(Icons.more_vert),
        iconSize: 18,
        color: AppColors.placeholder,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      ),
    );
  }
}
