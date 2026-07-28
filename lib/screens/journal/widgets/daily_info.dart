import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../models/daily_info.dart';

/// Tagesinfo-Band oben im Journal: was fuer den ganzen Tag gilt. Ruhige, grau
/// getoente Flaeche mit Info-Icon; klar von den Eintraegen abgesetzt.
class DailyInfoSection extends StatelessWidget {
  final List<DailyInfo> infos;
  final VoidCallback onAdd;
  final void Function(DailyInfo) onTapInfo;

  const DailyInfoSection({
    required this.infos,
    required this.onAdd,
    required this.onTapInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline,
                  size: 14, color: AppColors.dailyInfoText),
              const SizedBox(width: 6),
              const Text(
                'TAGESINFO',
                style: TextStyle(
                  color: AppColors.dailyInfoText,
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.add,
                    size: 20, color: AppColors.dailyInfoText),
                tooltip: 'Tagesinfo hinzufuegen',
                onPressed: onAdd,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (infos.isEmpty)
            InkWell(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.dailyInfoBand,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Keine Tagesinfo fuer heute - tippen zum Hinzufuegen',
                  style: TextStyle(color: AppColors.placeholder, fontSize: 13),
                ),
              ),
            )
          else
            ...infos.map((info) => DailyInfoCard(
                  info: info,
                  onTap: () => onTapInfo(info),
                )),
        ],
      ),
    );
  }
}

class DailyInfoCard extends StatelessWidget {
  final DailyInfo info;
  final VoidCallback onTap;
  const DailyInfoCard({required this.info, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.dailyInfoBand,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (info.isRange) ...[
                  Text(
                    _rangeLabel(info),
                    style: const TextStyle(
                      color: AppColors.dailyInfoText,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  info.text,
                  style: const TextStyle(
                    color: AppColors.dailyInfoText,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _rangeLabel(DailyInfo info) {
    String d(DateTime x) =>
        '${x.day.toString().padLeft(2, '0')}.${x.month.toString().padLeft(2, '0')}.';
    return '${d(info.startDate)} - ${d(info.endDate!)}';
  }
}
