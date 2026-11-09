import 'package:flutter/material.dart';

/// Sumber kebenaran tunggal untuk seluruh design system aplikasi.
///
/// Semua warna, tipografi, radius, dan gaya komponen didefinisikan di sini
/// sehingga layar cukup membaca dari [Theme] — tidak ada warna/ukuran hardcode
/// yang tersebar di file layar.
abstract final class AppTheme {
  /// Warna identitas utama (ungu IDN).
  static const Color seedColor = Color(0xFF1A008F);

  // ---- Warna status (dipakai StatusChip & statistik) ----
  static const Color statusAttend = Color(0xFF16A34A); // hijau
  static const Color statusLate = Color(0xFFEA580C); // oranye
  static const Color statusLeave = Color(0xFFDC2626); // merah
  static const Color statusPermission = Color(0xFF2563EB); // biru

  /// Radius standar kartu (kelipatan 8 sesuai grid spacing).
  static const double radiusMd = 16;
  static const double radiusLg = 24;

  /// Spacing standar kelipatan 8.
  static const double spaceMd = 16;
  static const double spaceLg = 24;

  static ThemeData light() => _build(
    ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.light),
  );

  static ThemeData dark() => _build(
    ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark),
  );

  static ThemeData _build(ColorScheme scheme) {
    final isLight = scheme.brightness == Brightness.light;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isLight
          ? const Color(0xFFF6F6FA)
          : scheme.surface,
      textTheme:
          (isLight ? Typography.blackCupertino : Typography.whiteCupertino)
              .apply(
                bodyColor: scheme.onSurface,
                displayColor: scheme.onSurface,
              )
              .copyWith(
                // Skala tipografi: judul 20 w700 / judul kartu 16 w600 / body 14 / caption 12
                titleLarge: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
                titleMedium: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                ),
                bodyLarge: const TextStyle(fontSize: 15),
                bodyMedium: const TextStyle(fontSize: 14),
                bodySmall: const TextStyle(fontSize: 12),
                labelLarge: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                labelSmall: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: scheme.onPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? Colors.white : scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide.none,
      ),
      // Transisi antar halaman yang lembut dan nyaman di semua platform.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      // Navigasi bawah: tinggi lega, indikator tint kalem.
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: isLight ? Colors.white : scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
