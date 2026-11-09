import 'package:flutter/material.dart';

/// Dialog konfirmasi sukses dengan ikon centang beranimasi scale-in.
///
/// Jika [secondaryLabel] diberikan, tampil tombol aksi kedua (mis.
/// "Checkout Sekarang"). Return `true` bila user memilih aksi kedua,
/// `false` bila menekan "Oke".
Future<bool> showSuccessDialog(
  BuildContext context, {
  required String title,
  String? message,
  String? secondaryLabel,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _SuccessDialog(
      title: title,
      message: message,
      secondaryLabel: secondaryLabel,
    ),
  ).then((value) => value ?? false);
}

class _SuccessDialog extends StatelessWidget {
  final String title;
  final String? message;
  final String? secondaryLabel;

  const _SuccessDialog({
    required this.title,
    this.message,
    this.secondaryLabel,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 450),
              curve: Curves.elasticOut,
              builder: (context, value, child) =>
                  Transform.scale(scale: value, child: child),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF16A34A), size: 44),
              ),
            ),
            const SizedBox(height: 18),
            Text(title, style: text.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: text.bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  if (secondaryLabel != null) ...[
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(secondaryLabel!),
                    ),
                    const SizedBox(height: 8),
                  ],
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Oke'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
