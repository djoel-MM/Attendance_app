import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:attendance_app/ui/absent/absent_screen.dart';
import 'package:attendance_app/ui/app_theme.dart';
import 'package:attendance_app/ui/attend/attend_screen.dart';
import 'package:attendance_app/ui/attendance_history/attendance_history_screen.dart';
import 'package:attendance_app/ui/face_enroll/face_enrollment_screen.dart';
import 'package:attendance_app/ui/widgets/entrance.dart';
import 'package:attendance_app/ui/widgets/menu_card.dart';

/// Kunci penyimpanan nama user agar tidak perlu diketik ulang saat absen.
const String kUserNameKey = 'user_name';

/// Kunci penyimpanan kelas user (diisi saat sertifikasi awal).
const String kUserClassKey = 'user_class';

/// Penanda sertifikasi awal sudah selesai (nama + kelas + wajah terdaftar).
const String kUserRegisteredKey = 'user_registered';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userName = '';
  String _userClass = '';

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userName = prefs.getString(kUserNameKey) ?? '';
        _userClass = prefs.getString(kUserClassKey) ?? '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _Header(userName: _userName, userClass: _userClass),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Aksi utama — kartu besar paling menonjol.
                  // Dinamis: belum hadir -> "Absen Sekarang",
                  // sudah hadir -> "Absen Pulang",
                  // sudah checkout -> "Presensi Selesai" (nonaktif).
                  StaggeredEntrance(
                    delay: const Duration(milliseconds: 160),
                    child: _PrimaryActionCard(
                      onAttend: () => _push(const AttendScreen()),
                      onCheckout: () =>
                          _push(const AttendScreen(isCheckout: true)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  StaggeredEntrance(
                    delay: const Duration(milliseconds: 280),
                    child: MenuCard(
                      title: 'Izin / Sakit',
                      subtitle: 'Ajukan izin atau sakit dengan rentang tanggal',
                      icon: Icons.event_note_rounded,
                      iconColor: AppTheme.statusPermission,
                      onTap: () => _push(const AbsentScreen()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  StaggeredEntrance(
                    delay: const Duration(milliseconds: 360),
                    child: MenuCard(
                      title: 'Daftar Wajah',
                      subtitle: 'Agar presensi mengenali wajah & mengisi nama otomatis',
                      icon: Icons.face_retouching_natural_rounded,
                      iconColor: AppTheme.statusAttend,
                      onTap: () => _push(const FaceEnrollmentScreen()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  StaggeredEntrance(
                    delay: const Duration(milliseconds: 440),
                    child: MenuCard(
                      title: 'Riwayat Presensi',
                      subtitle: 'Lihat, ubah, dan hapus catatan presensi',
                      icon: Icons.history_rounded,
                      iconColor: scheme.primary,
                      onTap: () => _push(const AttendanceHistoryScreen()),
                    ),
                  ),
                  const SizedBox(height: 28),
                  StaggeredEntrance(
                    delay: const Duration(milliseconds: 520),
                    child: Text(
                      'IDN Boarding School Solo',
                      textAlign: TextAlign.center,
                      style: text.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }
}

/// Header ungu gradient berisi sapaan personal, tanggal, dan statistik hari ini.
class _Header extends StatelessWidget {
  final String userName;
  final String userClass;

  const _Header({required this.userName, this.userClass = ''});

  static const _hari = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];
  static const _bulan = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  String _tanggalIndo(DateTime now) =>
      '${_hari[now.weekday - 1]}, ${now.day} ${_bulan[now.month - 1]} ${now.year}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final firstName = userName.trim().isEmpty
        ? 'Siswa'
        : userName.trim().split(' ').first;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, const Color(0xFF4A21C9)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppTheme.radiusLg),
          bottomRight: Radius.circular(AppTheme.radiusLg),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                child: Text(
                  firstName[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Halo, $firstName 👋',
                      style: text.titleMedium?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _tanggalIndo(now),
                      style: text.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              if (userClass.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.school_rounded,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        userClass,
                        style: text.labelSmall?.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Rekap Hari Ini',
            style: text.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 8),
          const _TodayStats(),
        ],
      ),
    );
  }
}

/// Baris statistik presensi hari ini dari Firestore (StreamBuilder realtime).
///
/// Stream dibuat secara defensif: jika Firebase belum siap (mis. saat smoke
/// test atau koneksi gagal), statistik menampilkan nol alih-alih crash.
class _TodayStats extends StatelessWidget {
  const _TodayStats();

  Stream<QuerySnapshot>? _stream() {
    try {
      final startOfToday = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      return FirebaseFirestore.instance
          .collection('attendance')
          .where(
            'created_at',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday),
          )
          .snapshots();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _stream(),
      builder: (context, snapshot) {
        int hadir = 0, terlambat = 0, izin = 0;
        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>? ?? {};
            if (data['type'] == 'permission') {
              izin++;
            } else if (data['description'] == 'Attend') {
              hadir++;
            } else if (data['description'] == 'Late') {
              terlambat++;
            }
          }
        }
        return Row(
          children: [
            Expanded(
              child: _StatPill(
                label: 'Hadir',
                value: hadir,
                color: AppTheme.statusAttend,
                icon: Icons.check_circle_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatPill(
                label: 'Terlambat',
                value: terlambat,
                color: AppTheme.statusLate,
                icon: Icons.schedule_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatPill(
                label: 'Izin',
                value: izin,
                color: AppTheme.statusPermission,
                icon: Icons.event_note_rounded,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // Reduced motion: angka langsung tampil tanpa animasi count-up.
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.95)),
          const SizedBox(height: 4),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.toDouble()),
            duration: disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, animatedValue, _) => Text(
              '${animatedValue.round()}',
              style: text.titleMedium?.copyWith(color: Colors.white),
            ),
          ),
          Text(
            label,
            style: text.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu aksi utama "Absen Sekarang" — paling besar dan mencolok.
///
/// Kartu ini dinamis berdasarkan presensi hari ini milik nama user:
/// - Belum hadir      -> "Absen Sekarang"
/// - Hadir, belum checkout -> "Absen Pulang"
/// - Sudah checkout   -> "Presensi Selesai" (kartu nonaktif)
class _PrimaryActionCard extends StatefulWidget {
  final VoidCallback onAttend;
  final VoidCallback onCheckout;

  const _PrimaryActionCard({required this.onAttend, required this.onCheckout});

  @override
  State<_PrimaryActionCard> createState() => _PrimaryActionCardState();
}

class _PrimaryActionCardState extends State<_PrimaryActionCard> {
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(kUserNameKey);
    if (saved != null && saved != _userName && mounted) {
      setState(() => _userName = saved);
    }
  }

  /// Stream presensi hari ini — dibuat defensif: jika Firebase belum siap,
  /// kartu tetap tampil dengan state "Absen Sekarang" alih-alih crash.
  Stream<QuerySnapshot<Map<String, dynamic>>>? _todayStream() {
    try {
      final startOfToday = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      return FirebaseFirestore.instance
          .collection('attendance')
          .where(
            'created_at',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday),
          )
          .snapshots();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _todayStream(),
      builder: (context, snapshot) {
        // Cari presensi hadir terbaru hari ini milik user ini.
        Map<String, dynamic>? todayRecord;
        if (snapshot.hasData && _userName.isNotEmpty) {
          Timestamp? latest;
          for (final doc in snapshot.data!.docs) {
            final data = doc.data();
            if (data['type'] != 'attendance') continue;
            if ((data['name'] ?? '').toString() != _userName) continue;
            final createdAt = data['created_at'] as Timestamp?;
            if (createdAt == null) continue;
            if (latest == null || createdAt.compareTo(latest) >= 0) {
              latest = createdAt;
              todayRecord = data;
            }
          }
        }

        final checkoutTime = (todayRecord?['checkout_time'] ?? '').toString();
        final workDuration = (todayRecord?['work_duration'] ?? '').toString();

        if (todayRecord != null && checkoutTime.isNotEmpty) {
          // Sudah hadir dan sudah checkout hari ini.
          return _card(
            context,
            text: text,
            scheme: scheme,
            icon: Icons.task_alt_rounded,
            title: 'Presensi Selesai',
            subtitle:
                'Hadir ${todayRecord['datetime'] ?? '-'} • '
                'Pulang $checkoutTime'
                '${workDuration.isNotEmpty ? ' • $workDuration' : ''}',
            onTap: null,
          );
        }

        if (todayRecord != null) {
          // Sudah hadir, belum checkout -> tampilkan aksi checkout.
          return _card(
            context,
            text: text,
            scheme: scheme,
            icon: Icons.logout_rounded,
            title: 'Absen Pulang',
            subtitle:
                'Kamu sudah hadir (${todayRecord['datetime'] ?? '-'}) — '
                'tap untuk checkout',
            onTap: widget.onCheckout,
          );
        }

        // Belum ada presensi hari ini (atau Firebase belum siap).
        return _card(
          context,
          text: text,
          scheme: scheme,
          icon: Icons.photo_camera_front_rounded,
          title: 'Absen Sekarang',
          subtitle: 'Selfie + lokasi otomatis, selesai dalam 10 detik',
          onTap: widget.onAttend,
        );
      },
    );
  }

  Widget _card(
    BuildContext context, {
    required TextTheme text,
    required ColorScheme scheme,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    final disabled = onTap == null;
    // Reduced motion: transisi warna/isi langsung tanpa gerakan.
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    final transitionDuration = disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 400);

    return Card(
      // Morph mulus saat keadaan berubah:
      // Absen Sekarang -> Absen Pulang -> Presensi Selesai.
      color: disabled ? scheme.surfaceContainerHighest : scheme.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: AnimatedContainer(
        duration: transitionDuration,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: disabled ? scheme.surfaceContainerHighest : scheme.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: disabled
                        ? scheme.primary.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: AnimatedSwitcher(
                    duration: transitionDuration,
                    child: Icon(
                      icon,
                      key: ValueKey(icon),
                      size: 30,
                      color: disabled ? scheme.primary : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedSwitcher(
                        duration: transitionDuration,
                        child: Text(
                          title,
                          key: ValueKey(title),
                          style: text.titleMedium?.copyWith(
                            color: disabled ? scheme.onSurface : Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedSwitcher(
                        duration: transitionDuration,
                        child: Text(
                          subtitle,
                          key: ValueKey(subtitle),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(
                            color: disabled
                                ? scheme.onSurfaceVariant
                                : Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: transitionDuration,
                  child: disabled
                      ? Icon(
                          Icons.check_circle_rounded,
                          key: const ValueKey('done'),
                          color: AppTheme.statusAttend,
                        )
                      : const Icon(
                          Icons.arrow_forward_rounded,
                          key: ValueKey('go'),
                          color: Colors.white,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
