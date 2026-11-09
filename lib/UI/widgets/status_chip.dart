import 'package:flutter/material.dart';

import 'package:attendance_app/ui/app_theme.dart';

/// Chip status presensi berwarna — memvisualkan data `Attend/Late/Leave/permission`
/// yang sebelumnya hanya tampil sebagai teks polos.
class StatusChip extends StatelessWidget {
  final String type;
  final String description;

  const StatusChip({
    super.key,
    required this.type,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = _resolve();
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: scheme.brightness == Brightness.light
                  ? color
                  : color.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  (String, Color, IconData) _resolve() {
    if (type == 'permission') {
      return ('Izin', AppTheme.statusPermission, Icons.event_note_rounded);
    }
    switch (description) {
      case 'Attend':
        return ('Hadir', AppTheme.statusAttend, Icons.check_circle_rounded);
      case 'Late':
        return ('Terlambat', AppTheme.statusLate, Icons.schedule_rounded);
      default:
        return ('Di Luar Jam', AppTheme.statusLeave, Icons.warning_rounded);
    }
  }
}

/// Warna status untuk avatar/aksen, dipakai bersama [StatusChip].
Color statusColor(String type, String description) {
  if (type == 'permission') return AppTheme.statusPermission;
  switch (description) {
    case 'Attend':
      return AppTheme.statusAttend;
    case 'Late':
      return AppTheme.statusLate;
    default:
      return AppTheme.statusLeave;
  }
}
