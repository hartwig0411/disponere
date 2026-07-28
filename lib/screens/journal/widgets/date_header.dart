import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

/// Zweizeiliger Datumskopf: klein und grau der Wochentag, darunter gross das
/// Datum. Der ruhige Anker des heutigen Tages (Design 3/4).
class DateHeader extends StatelessWidget {
  final String weekday;
  final String date;
  const DateHeader({required this.weekday, required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            weekday,
            style: const TextStyle(
              color: AppColors.weekday,
              fontSize: 12,
              letterSpacing: 2.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            date,
            style: const TextStyle(
              color: AppColors.dateLarge,
              fontSize: 30,
              fontWeight: FontWeight.w500,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Antippbare Datumszeile fuer das Daily-Info-Sheet.
class DateRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const DateRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                  color: AppColors.iconInactive, fontSize: 13),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(color: AppColors.text, fontSize: 15),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.calendar_today,
                size: 15, color: AppColors.iconInactive),
          ],
        ),
      ),
    );
  }
}
