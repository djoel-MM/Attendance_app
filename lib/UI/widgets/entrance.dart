import 'package:flutter/material.dart';

/// Entrance halus (fade + slide kecil dari bawah) dengan delay stagger.
///
/// Dipakai untuk satu momen orkestrasi per layar: elemen muncul berurutan
/// dengan sedikit jeda agar halaman terasa "menarik napas" saat dibuka.
///
/// Menghormati pengaturan aksesibilitas: jika [MediaQuery.disableAnimations]
/// aktif, konten langsung ditampilkan pada keadaan final tanpa gerakan.
class StaggeredEntrance extends StatefulWidget {
  /// Jeda sebelum animasi elemen ini dimulai (urutan elemen di layar).
  final Duration delay;

  final Widget child;

  const StaggeredEntrance({
    super.key,
    this.delay = Duration.zero,
    required this.child,
  });

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  static final Duration _animDuration = const Duration(milliseconds: 420);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _animDuration + widget.delay,
  );

  late final Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      widget.delay == Duration.zero
          ? 0
          // Fraksi jeda dalam total durasi, jangan sampai 1.0.
          : (widget.delay.inMilliseconds / _controller.duration!.inMilliseconds)
                .clamp(0.0, 0.99),
      1.0,
      curve: Curves.easeOutCubic,
    ),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      // Reduced motion: langsung keadaan final, tanpa gerakan.
      _controller.value = 1.0;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(_animation),
        child: widget.child,
      ),
    );
  }
}
