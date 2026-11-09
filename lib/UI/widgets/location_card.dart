import 'package:flutter/material.dart';

/// Kartu tampilan lokasi GPS — komponen yang sebelumnya di-copy-paste
/// di AttendScreen dan AbsentScreen.
class LocationCard extends StatelessWidget {
  final bool isLoading;
  final String address;

  const LocationCard({
    super.key,
    required this.isLoading,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          if (isLoading)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2,
                  color: scheme.primary),
            )
          else
            Icon(Icons.location_on_rounded, color: scheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              address,
              style: text.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
