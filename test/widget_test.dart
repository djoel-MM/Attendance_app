// Smoke test: gerbang awal aplikasi (RootGate) — alur sertifikasi vs
// langsung masuk, plus tombol "Sudah Punya Akun".
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:attendance_app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Mock plugin agar RootGate dan HomeScreen bisa membaca data tersimpan.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Belum sertifikasi -> layar sertifikasi dengan tombol masuk',
      (WidgetTester tester) async {
    await tester.pumpWidget(const AttendanceApp());
    await tester.pumpAndSettle();

    // Layar sertifikasi tampil, lengkap dengan tombol pemilik akun lama.
    expect(find.text('Sertifikasi Wajah'), findsOneWidget);
    expect(
      find.text('Sudah Punya Akun? Masuk dengan Wajah'),
      findsOneWidget,
    );
  });

  testWidgets('Sudah sertifikasi -> langsung beranda tanpa daftar ulang',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'user_registered': true,
      'user_name': 'Budi',
      'user_class': 'XI RPL 1',
    });
    await tester.pumpWidget(const AttendanceApp());
    await tester.pumpAndSettle();

    // Beranda menampilkan menu dengan label Bahasa Indonesia.
    expect(find.text('Absen Sekarang'), findsOneWidget);
    expect(find.text('Izin / Sakit'), findsOneWidget);
    expect(find.text('Riwayat Presensi'), findsOneWidget);
    // Layar sertifikasi tidak lagi ditampilkan.
    expect(find.text('Sertifikasi Wajah'), findsNothing);
  });
}
