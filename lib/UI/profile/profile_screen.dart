import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:attendance_app/ui/face_enroll/face_enrollment_screen.dart';
import 'package:attendance_app/ui/home_screen.dart';
import 'package:attendance_app/ui/register/register_screen.dart';
import 'package:attendance_app/ui/widgets/entrance.dart';
import 'package:attendance_app/utils/face_recognition/face_recognition_service.dart';

/// Tab profil pada dashboard: data diri hasil sertifikasi, status wajah
/// terdaftar, serta aksi daftar ulang wajah dan reset data.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = '';
  String _class = '';
  List<String> _faceUuids = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(kUserNameKey) ?? '';
    final uuids = name.isEmpty
        ? <String>[]
        : await FaceProfileStore.loadUuidsForName(name);
    if (!mounted) return;
    setState(() {
      _name = name;
      _class = prefs.getString(kUserClassKey) ?? '';
      _faceUuids = uuids;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final firstName = _name.trim().isEmpty
        ? 'Siswa'
        : _name.trim().split(' ').first;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const SizedBox(height: 8),
                StaggeredEntrance(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: scheme.primary.withValues(alpha: 0.14),
                        child: Text(
                          firstName[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _name.isEmpty ? 'Belum terdaftar' : _name,
                        style: text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_class.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _class,
                            style: text.labelMedium?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Status wajah terdaftar.
                StaggeredEntrance(
                  delay: const Duration(milliseconds: 120),
                  child: Card(
                    child: ListTile(
                      leading: Icon(
                        _faceUuids.isNotEmpty
                            ? Icons.verified_user_rounded
                            : Icons.face_retouching_off_rounded,
                        color: _faceUuids.isNotEmpty
                            ? Colors.green
                            : Colors.orange.shade800,
                      ),
                      title: const Text('Wajah Terdaftar'),
                      subtitle: Text(
                        _faceUuids.isNotEmpty
                            ? 'Presensi akan mengenali wajahmu dan mengisi '
                                  'nama otomatis.'
                            : 'Wajah belum terdaftar — presensi memakai nama '
                                  'manual.',
                      ),
                      trailing: Icon(
                        _faceUuids.isNotEmpty
                            ? Icons.check_circle_rounded
                            : Icons.warning_amber_rounded,
                        color: _faceUuids.isNotEmpty
                            ? Colors.green
                            : Colors.orange.shade800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                StaggeredEntrance(
                  delay: const Duration(milliseconds: 220),
                  child: FilledButton.icon(
                    onPressed: _reRegisterFace,
                    icon: const Icon(Icons.face_retouching_natural_rounded),
                    label: const Text('Daftar Ulang Wajah'),
                  ),
                ),
                const SizedBox(height: 12),
                StaggeredEntrance(
                  delay: const Duration(milliseconds: 300),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.error,
                      side: BorderSide(
                        color: scheme.error.withValues(alpha: 0.5),
                      ),
                    ),
                    onPressed: _confirmReset,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Reset Data & Sertifikasi Ulang'),
                  ),
                ),
                const SizedBox(height: 24),
                StaggeredEntrance(
                  delay: const Duration(milliseconds: 380),
                  child: Text(
                    'Wajah tersimpan sebagai template biometrik di server '
                    'face recognition, bukan sebagai foto. Template tidak '
                    'dapat digunakan untuk merekonstruksi wajahmu.',
                    style: text.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _reRegisterFace() async {
    if (_name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lengkapi data profil terlebih dahulu.')),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FaceEnrollmentScreen(presetName: _name),
      ),
    );
    _loadProfile();
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset data?'),
        content: const Text(
          'Data nama, kelas, dan status sertifikasi di perangkat ini akan '
          'dihapus. Kamu akan diminta melakukan sertifikasi ulang. '
          'Wajah yang terdaftar tidak ikut terhapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kUserNameKey);
    await prefs.remove(kUserClassKey);
    await prefs.remove(kUserRegisteredKey);

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
      (route) => false,
    );
  }
}
