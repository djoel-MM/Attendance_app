import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:attendance_app/ui/dashboard_screen.dart';
import 'package:attendance_app/ui/face_enroll/face_enrollment_screen.dart';
import 'package:attendance_app/ui/face_login/face_login_screen.dart';
import 'package:attendance_app/ui/home_screen.dart';
import 'package:attendance_app/ui/widgets/entrance.dart';

/// Layar sertifikasi awal — wajib dilakukan sebelum masuk dashboard.
///
/// Alur:
/// 1. Form data diri (Nama Lengkap + Kelas).
/// 2. Pendaftaran wajah (3 foto, dikirim ke Luxand Cloud).
/// 3. Data disimpan di perangkat -> langsung masuk dashboard.
///
/// Aplikasi membuka layar ini otomatis (via RootGate di main.dart)
/// selama user belum menyelesaikan sertifikasi.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _classController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _classController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              StaggeredEntrance(
                child: Container(
                  width: 88,
                  height: 88,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.face_retouching_natural_rounded,
                    size: 48,
                    color: scheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              StaggeredEntrance(
                delay: const Duration(milliseconds: 80),
                child: Text(
                  'Sertifikasi Wajah',
                  style: text.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              StaggeredEntrance(
                delay: const Duration(milliseconds: 160),
                child: Text(
                  'Sebelum menggunakan aplikasi, daftarkan dirimu dulu: '
                  'isi data lalu daftarkan wajah agar presensi terverifikasi '
                  'atas nama kamu sendiri.',
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
              StaggeredEntrance(
                delay: const Duration(milliseconds: 240),
                child: TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nama Lengkap',
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              StaggeredEntrance(
                delay: const Duration(milliseconds: 320),
                child: TextField(
                  controller: _classController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Kelas',
                    hintText: 'Contoh: XI RPL 1',
                    prefixIcon: Icon(Icons.school_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              StaggeredEntrance(
                delay: const Duration(milliseconds: 400),
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.face_rounded),
                  label: const Text('Lanjut Daftarkan Wajah'),
                ),
              ),
              const SizedBox(height: 4),
              // Untuk yang sudah pernah sertifikasi — masuk cukup scan wajah,
              // akun lama otomatis dipulihkan tanpa daftar ulang.
              StaggeredEntrance(
                delay: const Duration(milliseconds: 460),
                child: TextButton.icon(
                  onPressed: _goToFaceLogin,
                  icon: const Icon(Icons.sensor_occupied_rounded),
                  label: const Text('Sudah Punya Akun? Masuk dengan Wajah'),
                ),
              ),
              const SizedBox(height: 12),
              StaggeredEntrance(
                delay: const Duration(milliseconds: 480),
                child: Text(
                  'Data tersimpan di perangkat ini dan wajahmu terdaftar '
                  'sebagai template biometrik, bukan foto.',
                  style: text.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final nama = _nameController.text.trim();
    final kelas = _classController.text.trim();
    if (nama.isEmpty) {
      _showSnack('Nama wajib diisi.', Icons.warning_amber_rounded);
      return;
    }
    if (kelas.isEmpty) {
      _showSnack('Kelas wajib diisi.', Icons.warning_amber_rounded);
      return;
    }

    // Buka pendaftaran wajah dengan nama & kelas yang sudah diisi.
    final success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => FaceEnrollmentScreen(
          presetName: nama,
          presetClass: kelas,
        ),
      ),
    );

    if (success != true || !mounted) return;

    // Sertifikasi selesai — simpan data diri di perangkat.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kUserNameKey, nama);
    await prefs.setString(kUserClassKey, kelas);
    await prefs.setBool(kUserRegisteredKey, true);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const DashboardScreen()),
    );
  }

  /// Buka verifikasi wajah untuk pemilik akun lama — bila wajah dikenali,
  /// data akun dipulihkan dan langsung masuk dashboard.
  Future<void> _goToFaceLogin() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FaceLoginScreen()),
    );
  }

  void _showSnack(String message, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
