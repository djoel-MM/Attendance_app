import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:attendance_app/ui/app_theme.dart';
import 'package:attendance_app/ui/dashboard_screen.dart';
import 'package:attendance_app/ui/home_screen.dart'
    show kUserClassKey, kUserNameKey, kUserRegisteredKey;
import 'package:attendance_app/ui/register/register_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyDauGqKgEV6Q2yJMjFbaCbUNDk5FjGb0hc',
        appId: '1:113228359740:android:c9363c7bec701353b93b39',
        messagingSenderId: '113228359740',
        projectId: 'idn-attendance-app-6ceac',
      ),
    );
    debugPrint("Firebase connected successfully!");
  } catch (e) {
    debugPrint("Firebase connection failed: $e");
  }
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Presensi IDN',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const RootGate(),
    );
  }
}

/// Gerbang awal aplikasi:
/// - Belum sertifikasi -> layar Sertifikasi (data diri + daftar wajah).
/// - Sudah sertifikasi -> langsung Dashboard dengan navbar (tidak perlu
///   daftar ulang; cukup verifikasi wajah bila diminta aplikasi).
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        // Splash sederhana saat preferensi sedang dibaca.
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final prefs = snapshot.data!;
        final registered = prefs.getBool(kUserRegisteredKey) ?? false;
        // Fallback defensif: user yang datanya sudah lengkap dianggap
        // sudah login meskipun penanda sertifikasi hilang.
        final hasName = (prefs.getString(kUserNameKey) ?? '').isNotEmpty;
        final hasClass = (prefs.getString(kUserClassKey) ?? '').isNotEmpty;
        final isLoggedIn = registered || (hasName && hasClass);
        return isLoggedIn
            ? const DashboardScreen()
            : const RegisterScreen();
      },
    );
  }
}
