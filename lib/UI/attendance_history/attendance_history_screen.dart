import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:attendance_app/ui/app_theme.dart';
import 'package:attendance_app/ui/attend/attend_screen.dart';
import 'package:attendance_app/ui/widgets/empty_state.dart';
import 'package:attendance_app/ui/widgets/skeleton.dart';
import 'package:attendance_app/ui/widgets/status_chip.dart';

/// Filter riwayat yang tersedia.
enum _HistoryFilter { semua, hadir, terlambat, izin }

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  _HistoryFilter _filter = _HistoryFilter.semua;

  /// Dipakai untuk memaksa StreamBuilder mendengarkan ulang stream
  /// saat pengguna menekan tombol "Coba Lagi" pada state error.
  int _streamGeneration = 0;

  /// Stream riwayat presensi — dibuat defensif: jika Firebase belum siap
  /// (mis. saat smoke test atau inisialisasi gagal), stream null ->
  /// tampil state kosong alih-alih crash.
  Stream<QuerySnapshot>? _historyStream() {
    try {
      return FirebaseFirestore.instance.collection('attendance').snapshots();
    } catch (_) {
      return null;
    }
  }

  bool _matchesFilter(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    final desc = data['description']?.toString() ?? '';
    switch (_filter) {
      case _HistoryFilter.hadir:
        return type != 'permission' && desc == 'Attend';
      case _HistoryFilter.terlambat:
        return type != 'permission' && desc == 'Late';
      case _HistoryFilter.izin:
        return type == 'permission';
      case _HistoryFilter.semua:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Riwayat Presensi")),
      body: SafeArea(
        child: Column(
          children: [
            // Baris filter status.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _filterChip('Semua', _HistoryFilter.semua, scheme.primary),
                    const SizedBox(width: 8),
                    _filterChip(
                        'Hadir', _HistoryFilter.hadir, AppTheme.statusAttend),
                    const SizedBox(width: 8),
                    _filterChip('Terlambat', _HistoryFilter.terlambat,
                        AppTheme.statusLate),
                    const SizedBox(width: 8),
                    _filterChip(
                        'Izin', _HistoryFilter.izin, AppTheme.statusPermission),
                  ],
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                key: ValueKey(_streamGeneration),
                stream: _historyStream(),
                builder: (context, snapshot) {
                  // 1) State loading -> skeleton shimmer.
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: 5,
                      itemBuilder: (_, _) => const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: HistoryCardSkeleton(),
                      ),
                    );
                  }

                  // 2) State error -> pesan + tombol coba lagi.
                  if (snapshot.hasError) {
                    return EmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: 'Gagal Memuat Riwayat',
                      message:
                          'Terjadi kendala saat mengambil data.\nPeriksa koneksi internet kamu lalu coba lagi.',
                      actionLabel: 'Coba Lagi',
                      onAction: () =>
                          setState(() => _streamGeneration++), // re-listen
                    );
                  }

                  final docs = (snapshot.data?.docs ?? const [])
                      .map((doc) => (
                            id: doc.id,
                            data: doc.data() as Map<String, dynamic>? ?? {},
                          ))
                      .where((entry) => _matchesFilter(entry.data))
                      .toList()
                    // Urutkan terbaru dulu berdasarkan created_at (aman di memori).
                    ..sort((a, b) {
                      final timeA = a.data['created_at'] as Timestamp?;
                      final timeB = b.data['created_at'] as Timestamp?;
                      if (timeA != null && timeB != null) {
                        return timeB.compareTo(timeA);
                      }
                      return 0;
                    });

                  // 3) State kosong -> ilustrasi + ajakan aksi.
                  if (docs.isEmpty) {
                    return EmptyState(
                      icon: _filter == _HistoryFilter.semua
                          ? Icons.fact_check_outlined
                          : Icons.filter_alt_off_outlined,
                      title: _filter == _HistoryFilter.semua
                          ? 'Belum Ada Riwayat'
                          : 'Tidak Ada Data',
                      message: _filter == _HistoryFilter.semua
                          ? 'Presensi yang kamu kirim akan tampil di sini.'
                          : 'Coba ganti filter atau pilih "Semua".',
                      actionLabel: _filter == _HistoryFilter.semua
                          ? 'Absen Sekarang'
                          : null,
                      onAction: _filter == _HistoryFilter.semua
                          ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const AttendScreen()),
                              )
                          : null,
                    );
                  }

                  // 4) State sukses -> daftar kartu.
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final entry = docs[index];
                      final data = entry.data;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _HistoryCard(
                          docId: entry.id,
                          name: data['name']?.toString() ?? 'Unknown',
                          address: data['address']?.toString() ?? '-',
                          description: data['description']?.toString() ?? '-',
                          datetime: data['datetime']?.toString() ?? '-',
                          type: data['type']?.toString() ?? 'attendance',
                          checkoutTime:
                              (data['checkout_time'] ?? '').toString(),
                          checkoutStatus:
                              (data['checkout_status'] ?? '').toString(),
                          workDuration:
                              (data['work_duration'] ?? '').toString(),
                          onEdit: () => _showEditDialog(
                            entry.id,
                            data['name']?.toString() ?? '',
                            data['address']?.toString() ?? '',
                            data['description']?.toString() ?? '',
                            data['datetime']?.toString() ?? '',
                            checkoutTime:
                                (data['checkout_time'] ?? '').toString(),
                          ),
                          onDelete: () =>
                              _confirmDelete(entry.id, data['name'] ?? ''),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, _HistoryFilter value, Color color) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: selected
            ? (Theme.of(context).colorScheme.brightness == Brightness.light
                ? color
                : color.withValues(alpha: 0.9))
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      selectedColor: color.withValues(alpha: 0.16),
      showCheckmark: false,
    );
  }

  void _showEditDialog(
      String docId, String name, String address, String description, String datetime,
      {String checkoutTime = ''}) {
    final nameController = TextEditingController(text: name);
    final addressController = TextEditingController(text: address);
    final descriptionController = TextEditingController(text: description);
    final datetimeController = TextEditingController(text: datetime);
    final checkoutTimeController = TextEditingController(text: checkoutTime);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Ubah Riwayat"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                    labelText: "Nama", prefixIcon: Icon(Icons.person_rounded)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                    labelText: "Alamat",
                    prefixIcon: Icon(Icons.location_on_rounded)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                    labelText: "Keterangan",
                    prefixIcon: Icon(Icons.notes_rounded)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: datetimeController,
                decoration: const InputDecoration(
                  labelText: "Tanggal & Waktu",
                  prefixIcon: Icon(Icons.schedule_rounded),
                  helperText: 'Format: dd/MM/yyyy, HH:mm:ss',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: checkoutTimeController,
                decoration: const InputDecoration(
                  labelText: "Waktu Checkout",
                  prefixIcon: Icon(Icons.logout_rounded),
                  helperText: 'Format: dd/MM/yyyy, HH:mm:ss — kosongkan '
                      'jika belum checkout',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('attendance')
                    .doc(docId)
                    .update({
                  'name': nameController.text.trim(),
                  'address': addressController.text.trim(),
                  'description': descriptionController.text.trim(),
                  'datetime': datetimeController.text.trim(),
                  'checkout_time': checkoutTimeController.text.trim(),
                });
              } catch (e) {
                debugPrint('Gagal memperbarui presensi: $e');
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String docId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Hapus riwayat $name?"),
        content: const Text("Riwayat presensi ini akan dihapus permanen."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('attendance')
                    .doc(docId)
                    .delete();
              } catch (e) {
                debugPrint('Gagal menghapus presensi: $e');
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Hapus"),
          ),
        ],
      ),
    );
  }
}

/// Kartu satu baris riwayat: avatar berwarna status, nama + chip status,
/// baris lokasi & waktu, serta aksi edit/hapus yang terlihat langsung.
class _HistoryCard extends StatelessWidget {
  final String docId;
  final String name;
  final String address;
  final String description;
  final String datetime;
  final String type;
  final String checkoutTime;
  final String checkoutStatus;
  final String workDuration;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _HistoryCard({
    required this.docId,
    required this.name,
    required this.address,
    required this.description,
    required this.datetime,
    required this.type,
    required this.checkoutTime,
    required this.checkoutStatus,
    required this.workDuration,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final color = statusColor(type, description);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: color.withValues(alpha: 0.16),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: color,
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleMedium),
                      ),
                      StatusChip(type: type, description: description),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _infoRow(Icons.location_on_rounded, address, scheme),
                  const SizedBox(height: 3),
                  _infoRow(Icons.schedule_rounded, datetime, scheme),
                  if (checkoutTime.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    _infoRow(
                      Icons.logout_rounded,
                      'Pulang: $checkoutTime'
                      '${checkoutStatus.isNotEmpty ? ' • $checkoutStatus' : ''}',
                      scheme,
                    ),
                  ],
                  if (workDuration.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    _infoRow(
                      Icons.timer_outlined,
                      'Durasi kerja: $workDuration',
                      scheme,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 4),
            // Aksi terlihat langsung — tidak lagi tersembunyi di menu popup.
            Column(
              children: [
                _actionIcon(
                  context,
                  icon: Icons.edit_outlined,
                  color: scheme.primary,
                  onTap: onEdit,
                ),
                const SizedBox(height: 6),
                _actionIcon(
                  context,
                  icon: Icons.delete_outline_rounded,
                  color: scheme.error,
                  onTap: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String value, ColorScheme scheme) {
    return Row(
      children: [
        Icon(icon, size: 14, color: scheme.onSurfaceVariant),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _actionIcon(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 38,
      height: 38,
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        iconSize: 19,
        color: color,
        onPressed: onTap,
        icon: Icon(icon),
      ),
    );
  }
}
