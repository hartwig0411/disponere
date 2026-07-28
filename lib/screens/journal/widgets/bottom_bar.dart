import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

/// Untere Icon-Leiste (Design 8): Journal (heute), Suche, Aufgaben, Neuer
/// Eintrag. Das Journal-Icon steht als aktiver Tab im Akzentblau, die uebrigen
/// ruhig in Grau. Vorerst fest unten - die Praxis entscheidet ueber die
/// endgueltige Position (Design 9).
class BottomBar extends StatelessWidget {
  final VoidCallback onJournal;
  final VoidCallback onSearch;
  final VoidCallback onTasks;
  final VoidCallback onNewEntry;
  const BottomBar({
    required this.onJournal,
    required this.onSearch,
    required this.onTasks,
    required this.onNewEntry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.paper,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              BottomBarButton(
                icon: Icons.menu_book_outlined,
                tooltip: 'Journal',
                active: true,
                onTap: onJournal,
              ),
              BottomBarButton(
                icon: Icons.search,
                tooltip: 'Suchen',
                onTap: onSearch,
              ),
              BottomBarButton(
                icon: Icons.check_box_outlined,
                tooltip: 'Aufgaben',
                onTap: onTasks,
              ),
              BottomBarButton(
                icon: Icons.edit_outlined,
                tooltip: 'Neuer Eintrag',
                onTap: onNewEntry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BottomBarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;
  const BottomBarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon,
          color: active ? AppColors.accent : AppColors.iconInactive),
      tooltip: tooltip,
      onPressed: onTap,
    );
  }
}

/// Umschalter fuer das Heute-Panel (Design 5/9): ein Sidebar-Symbol mit einem
/// leisen Zahl-Badge im Akzentblau. Die Zahl = heutige Termine + offene
/// Aufgaben; ist sie 0, erscheint kein Badge (Leerfall, Design 5).
class PanelToggleButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const PanelToggleButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.view_sidebar_outlined,
              color: AppColors.iconInactive),
          tooltip: 'Heute-Agenda',
          onPressed: onTap,
        ),
        if (count > 0)
          Positioned(
            right: 4,
            top: 6,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  height: 1.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
