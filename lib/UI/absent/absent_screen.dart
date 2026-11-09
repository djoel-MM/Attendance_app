import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:attendance_app/ui/home_screen.dart';
import 'package:attendance_app/ui/widgets/location_card.dart';
import 'package:attendance_app/ui/widgets/success_dialog.dart';

class AbsentScreen extends StatefulWidget {
  const AbsentScreen({super.key});

  @override
  State<AbsentScreen> createState() => _AbsentScreenState();
}

class _AbsentScreenState extends State<AbsentScreen> {
  bool isLoading = false;
  double dLat = 0.0;
  double dLong = 0.0;
  String strAlamat = "Mengambil lokasi...";

  /// Kondisi validasi per-field untuk errorText inline.
  bool _showErrors = false;

  final CollectionReference dataCollection =
      FirebaseFirestore.instance.collection('attendance');

  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _keteranganController = TextEditingController();
  final TextEditingController _dariController = TextEditingController();
  final TextEditingController _sampaiController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSavedName();
    getGeoLocationPosition();
  }

  Future<void> _loadSavedName() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(kUserNameKey);
    if (saved != null && saved.isNotEmpty && mounted) {
      _namaController.text = saved;
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _keteranganController.dispose();
    _dariController.dispose();
    _sampaiController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, IconData icon) {
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

  Future<void> getAddressFromLongLat(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks[0];
        setState(() {
          strAlamat =
              "${place.street ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? ''}, ${place.country ?? ''}"
                  .replaceAll(RegExp(r'^[,\s]+|[,\s]+$'), '')
                  .replaceAll(RegExp(r',\s*,+'), ',');
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        strAlamat =
            "Lat: ${position.latitude.toStringAsFixed(5)}, Long: ${position.longitude.toStringAsFixed(5)}";
        isLoading = false;
      });
    }
  }

  Future<bool> handleLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar(
          "Layanan GPS tidak aktif. Silakan aktifkan GPS perangkat Anda.",
          Icons.location_off);
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar("Izin akses lokasi ditolak.", Icons.warning_amber_rounded);
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar(
          "Izin lokasi ditolak permanen. Buka pengaturan aplikasi untuk mengizinkan.",
          Icons.error_outline);
      return false;
    }

    return true;
  }

  Future<void> getGeoLocationPosition() async {
    final hasPermission = await handleLocationPermission();
    if (!hasPermission) return;

    setState(() => isLoading = true);
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      dLat = position.latitude;
      dLong = position.longitude;
      await getAddressFromLongLat(position);
    } catch (e) {
      debugPrint("Error GPS: $e");
      if (mounted) {
        setState(() {
          strAlamat = "Koordinat: Lat $dLat, Long $dLong";
          isLoading = false;
        });
      }
    }
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      setState(() {
        controller.text = DateFormat('dd/MM/yyyy').format(pickedDate);
      });
    }
  }

  Future<void> submitPermission(
      String nama, String keterangan, String from, String until) async {
    await dataCollection.add({
      'name': nama.trim(),
      'address': '-',
      'description': keterangan,
      'datetime': '$from - $until',
      'type': 'permission',
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  bool get _isValid =>
      _namaController.text.trim().isNotEmpty &&
      _keteranganController.text.trim().isNotEmpty &&
      _dariController.text.isNotEmpty &&
      _sampaiController.text.isNotEmpty;

  Future<void> _submit() async {
    if (!_isValid) {
      setState(() => _showErrors = true);
      _showSnackBar("Semua kolom wajib diisi.", Icons.warning_amber_rounded);
      return;
    }

    final nama = _namaController.text.trim();
    try {
      await submitPermission(nama, _keteranganController.text.trim(),
          _dariController.text, _sampaiController.text);

      // Simpan nama agar tidak perlu diketik ulang di lain waktu.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kUserNameKey, nama);

      if (!mounted) return;
      await showSuccessDialog(
        context,
        title: 'Pengajuan Terkirim!',
        message: 'Pengajuan izin/sakit berhasil dikirim dan menunggu persetujuan.',
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _showSnackBar("Gagal mengirim pengajuan: $e", Icons.error_outline);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Pengajuan Izin / Sakit")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("Ajukan Izin / Sakit",
                  textAlign: TextAlign.center, style: text.titleLarge),
              const SizedBox(height: 6),
              Text(
                "Isi form di bawah, pengajuan langsung tercatat di riwayat.",
                textAlign: TextAlign.center,
                style: text.bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              LocationCard(isLoading: isLoading, address: strAlamat),
              const SizedBox(height: 16),
              TextField(
                controller: _namaController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: "Nama Lengkap",
                  prefixIcon: const Icon(Icons.person_rounded),
                  errorText: _showErrors &&
                          _namaController.text.trim().isEmpty
                      ? "Nama wajib diisi"
                      : null,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _keteranganController,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: "Keterangan (sakit / izin)",
                  hintText: "Contoh: Demam, perlu istirahat",
                  prefixIcon: const Icon(Icons.notes_rounded),
                  errorText: _showErrors &&
                          _keteranganController.text.trim().isEmpty
                      ? "Keterangan wajib diisi"
                      : null,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _dariController,
                readOnly: true,
                onTap: () => _pickDate(_dariController),
                decoration: InputDecoration(
                  labelText: "Dari Tanggal",
                  prefixIcon: const Icon(Icons.calendar_today_rounded),
                  errorText:
                      _showErrors && _dariController.text.isEmpty
                          ? "Pilih tanggal mulai"
                          : null,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _sampaiController,
                readOnly: true,
                onTap: () => _pickDate(_sampaiController),
                decoration: InputDecoration(
                  labelText: "Sampai Tanggal",
                  prefixIcon: const Icon(Icons.calendar_month_rounded),
                  errorText: _showErrors && _sampaiController.text.isEmpty
                      ? "Pilih tanggal selesai"
                      : null,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.send_rounded),
                label: const Text("Kirim Pengajuan"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
