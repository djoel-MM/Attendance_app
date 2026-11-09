import 'package:flutter/material.dart';

/// Box skeleton beranimasi — pengganti `CircularProgressDialog` untuk
/// state loading daftar, sesuai pola shimmer modern.
class Skeleton extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius radius;

  const Skeleton({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.radius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest;
    final highlight = scheme.surfaceContainerLow;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Gradient bergeser kiri-kanan untuk efek shimmer.
        final t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.radius,
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * t, 0),
              end: Alignment(0 + 2 * t, 0),
              colors: [base, highlight, base],
              stops: const [0.35, 0.5, 0.65],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton khusus untuk satu kartu riwayat presensi.
class HistoryCardSkeleton extends StatelessWidget {
  const HistoryCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Skeleton(
                width: 46,
                height: 46,
                radius: BorderRadius.all(Radius.circular(23))),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Skeleton(height: 14, width: 140),
                  SizedBox(height: 8),
                  Skeleton(height: 10),
                  SizedBox(height: 6),
                  Skeleton(height: 10, width: 190),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
