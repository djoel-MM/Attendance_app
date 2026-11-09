import 'package:flutter/material.dart';

/// Bingkai panduan wajah dengan animasi scan-line berulang.
///
/// Pengganti aset Lottie placeholder — digambar full custom dengan widget
/// Flutter sehingga tajam di semua resolusi dan tanpa file eksternal.
class FaceScanFrame extends StatefulWidget {
  final Duration duration;

  const FaceScanFrame({super.key, this.duration = const Duration(seconds: 2)});

  @override
  State<FaceScanFrame> createState() => _FaceScanFrameState();
}

class _FaceScanFrameState extends State<FaceScanFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: 264,
          height: 344,
          child: Stack(
            children: [
              // Empat sudut bracket bingkai.
              const _Corner(position: Alignment.topLeft),
              const _Corner(position: Alignment.topRight),
              const _Corner(position: Alignment.bottomLeft),
              const _Corner(position: Alignment.bottomRight),

              // Garis pemindai yang bergerak naik-turun.
              Positioned(
                left: 28,
                right: 28,
                top: 24 + _controller.value * (344 - 72),
                child: Opacity(
                  opacity: 0.35 + 0.65 * (1 - (2 * _controller.value - 1).abs()),
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: const LinearGradient(
                        colors: [Colors.transparent, Colors.white, Colors.transparent],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.8),
                          blurRadius: 14,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Ikon wajah samar di tengah sebagai panduan posisi.
              Center(
                child: Icon(
                  Icons.face_rounded,
                  size: 120,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Corner extends StatelessWidget {
  final Alignment position;

  const _Corner({required this.position});

  @override
  Widget build(BuildContext context) {
    Widget side(Alignment alignment) => Align(
          alignment: alignment,
          child: Container(
            width: alignment == Alignment.centerLeft ||
                    alignment == Alignment.centerRight
                ? 4
                : 44,
            height: alignment == Alignment.topCenter ||
                    alignment == Alignment.bottomCenter
                ? 4
                : 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        );

    return Align(
      alignment: position,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          children: [
            // Untuk tiap sudut, gabungkan dua sisi (horizontal + vertikal).
            if (position == Alignment.topLeft) ...[
              side(Alignment.topCenter),
              side(Alignment.centerLeft),
            ] else if (position == Alignment.topRight) ...[
              side(Alignment.topCenter),
              side(Alignment.centerRight),
            ] else if (position == Alignment.bottomLeft) ...[
              side(Alignment.bottomCenter),
              side(Alignment.centerLeft),
            ] else ...[
              side(Alignment.bottomCenter),
              side(Alignment.centerRight),
            ],
          ],
        ),
      ),
    );
  }
}
