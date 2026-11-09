import 'package:flutter/material.dart';

import 'package:attendance_app/ui/attendance_history/attendance_history_screen.dart';
import 'package:attendance_app/ui/home_screen.dart';
import 'package:attendance_app/ui/profile/profile_screen.dart';

/// Dashboard utama setelah sertifikasi — tampilan beranda yang sudah ada
/// ditambah NavigationBar untuk navigasi cepat antar tab.
///
/// Tab:
/// 1. Beranda  — tampilan HomeScreen (kartu absen, izin, daftar wajah).
/// 2. Riwayat  — AttendanceHistoryScreen.
/// 3. Profil   — data diri, status wajah, daftar ulang, reset data.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tabIndex = 0;

  static const _tabs = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: 'Beranda',
    ),
    NavigationDestination(
      icon: Icon(Icons.history_outlined),
      selectedIcon: Icon(Icons.history_rounded),
      label: 'Riwayat',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outlined),
      selectedIcon: Icon(Icons.person_rounded),
      label: 'Profil',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack menjaga state tiap tab tetap hidup (stream tidak
      // di-relisten setiap pindah tab).
      body: IndexedStack(
        index: _tabIndex,
        children: const [
          HomeScreen(),
          AttendanceHistoryScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: _tabs,
      ),
    );
  }
}
