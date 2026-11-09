import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:attendance_app/ui/home_screen.dart';
import 'package:attendance_app/ui/widgets/face_scan_frame.dart';
import 'package:attendance_app/ui/widgets/location_card.dart';
import 'package:attendance_app/ui/widgets/success_dialog.dart';
import 'package:attendance_app/utils/face_detection/google_ml_kit.dart';
import 'package:attendance_app/utils/face_recognition/face_recognition_service.dart';

class AttendScreen extends StatefulWidget {
  final XFile? image;

  /// true = mode checkout (absen pulang), false = absen hadir.
  final bool isCheckout;

  /// Nama hasil pengenalan wajah (bila cocok) — membuat field nama terkunci.
  final String? recognizedName;

  const AttendScreen({
    super.key,
    this.image,
    this.isCheckout = false,
    this.recognizedName,
  });

  @override
  State<AttendScreen> createState() => _AttendScreenState();
}

class _AttendScreenState extends State<AttendScreen> {
  CameraController? controller;
  bool isCameraReady = false;

  // Bytes selfie untuk preview. Dibaca via XFile.readAsBytes() agar kompatibel
  // di semua platform termasuk Flutter Web (Image.file tidak didukung di Web).
  Uint8List? _selfieBytes;

  bool isBusy = false;
  final faceDetector = GoogleMlKit.vision.faceDetector();

  bool isLoading = false;
  double dLat = 0.0;
  double dLong = 0.0;
  String strAlamat = "Mengambil lokasi...";
  String strStatus = "";
  String strDateTime = "";

  final CollectionReference<Map<String, dynamic>> dataCollection =
      FirebaseFirestore.instance.collection('attendance');

  final TextEditingController _namaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.recognizedName != null) {
      // Nama hasil pengenalan wajah — field nama terkunci.
      _namaController.text = widget.recognizedName!;
    } else {
      _loadSavedName();
    }
    if (widget.image == null) {
      initializeCamera();
    } else {
      _loadSelfieBytes();
      getGeoLocationPosition();
    }
  }

  /// Membaca foto selfie sebagai bytes. XFile.readAsBytes() bekerja di
  /// Android/iOS maupun Web, tidak seperti File() dari dart:io.
  Future<void> _loadSelfieBytes() async {
    try {
      final bytes = await widget.image!.readAsBytes();
      if (mounted) setState(() => _selfieBytes = bytes);
    } catch (e) {
      debugPrint("Failed to read selfie image: $e");
    }
  }

  Future<void> _loadSavedName() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(kUserNameKey);
    if (saved != null && saved.isNotEmpty && mounted) {
      _namaController.text = saved;
    }
  }

  Future<void> _saveName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kUserNameKey, name);
  }

  @override
  void dispose() {
    controller?.dispose();
    // close() bisa melempar MissingPluginException di platform yang tidak
    // didukung ML Kit (macOS/Windows/Linux) — jangan sampai merusak dispose.
    try {
      faceDetector.close();
    } catch (_) {}
    _namaController.dispose();
    super.dispose();
  }

  Future<void> initializeCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    controller = CameraController(
      frontCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await controller!.initialize();
      if (mounted) setState(() => isCameraReady = true);
    } catch (e) {
      debugPrint("Failed to initialize camera: $e");
    }
  }

  void setStatusAbsen() {
    final now = DateTime.now();
    final dateHours = now.hour;
    final dateMinutes = now.minute;

    if (dateHours < 8 || (dateHours == 8 && dateMinutes <= 30)) {
      strStatus = "Attend"; // Tepat waktu (sebelum / pukul 08:30)
    } else if ((dateHours > 8 && dateHours < 18) ||
        (dateHours == 8 && dateMinutes >= 31)) {
      strStatus = "Late"; // Terlambat (08:31 s.d. 18:00)
    } else {
      strStatus = "Leave"; // Di luar jam operasional
    }
  }

  Future<void> submitAbsen(String alamat, String nama, String status) async {
    _showLoaderDialog();

    try {
      await dataCollection.add({
        'name': nama.trim(),
        'address': alamat.isEmpty ? 'Lokasi tidak terekam' : alamat,
        'description': status,
        'datetime': strDateTime,
        'latitude': dLat,
        'longitude': dLong,
        'type': 'attendance',
        'created_at': FieldValue.serverTimestamp(),
      });
      await _saveName(nama);

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      // Setelah check-in sukses, user bisa langsung lanjut checkout
      // atau kembali ke beranda.
      final wantsCheckout = await showSuccessDialog(
        context,
        title: 'Presensi Terkirim!',
        message: status == 'Attend'
            ? 'Kamu tercatat hadir tepat waktu. Tetap semangat belajar!'
            : 'Presensi tercatat dengan status "$status".',
        secondaryLabel: 'Checkout Sekarang',
      );
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => wantsCheckout
              ? const AttendScreen(isCheckout: true)
              : const HomeScreen(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _showSnackBar("Gagal menyimpan presensi: $e", Icons.error_outline);
    }
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

  void _showLoaderDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
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
      _showSnackBar("Layanan GPS tidak aktif. Silakan aktifkan GPS perangkat Anda.",
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

  /// ML Kit face detection hanya punya implementasi native di Android & iOS.
  bool get _faceDetectionSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Lanjut ke layar konfirmasi presensi dengan foto yang sudah diambil.
  ///
  /// Di Android/iOS, foto diverifikasi dulu lewat pengenalan wajah:
  /// - Cocok dengan profil terdaftar -> nama terisi otomatis & terkunci.
  /// - Tidak cocok -> fallback isi nama manual (dengan info).
  Future<void> _proceedToConfirmation(XFile imageFile) async {
    final messenger = ScaffoldMessenger.of(context);
    String? recognized;
    final recognitionSupported = FaceRecognitionService.instance.isSupported;

    if (recognitionSupported) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            const Center(child: CircularProgressIndicator()),
      );
      try {
        final match =
            await FaceRecognitionService.instance.matchFromXFile(imageFile);
        if (match.isMatch) recognized = match.name;
      } catch (e) {
        debugPrint('Gagal pengenalan wajah: $e');
      }
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Tutup loader
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => AttendScreen(
          image: imageFile,
          isCheckout: widget.isCheckout,
          recognizedName: recognized,
        ),
      ),
    );

    if (recognitionSupported && recognized == null) {
      messenger.showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.face_retouching_off_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                    'Wajah tidak dikenali — isi nama manual untuk melanjutkan.'),
              ),
            ],
          ),
          backgroundColor: Colors.orange.shade800,
        ),
      );
    }
  }

  Future<void> processImage(InputImage inputImage, XFile imageFile) async {
    if (isBusy) return;
    isBusy = true;

    try {
      final faces = await faceDetector.processImage(inputImage);
      isBusy = false;

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Tutup loader dialog

      if (faces.isNotEmpty) {
        // Wajah asli terdeteksi -> Lanjut ke layar form konfirmasi presensi
        await _proceedToConfirmation(imageFile);
      } else {
        _showSnackBar(
            "Wajah tidak terdeteksi! Pastikan wajah terlihat jelas di bingkai.",
            Icons.warning_amber_rounded);
      }
    } on MissingPluginException {
      // Plugin native tidak terdaftar (platform tidak didukung, atau aplikasi
      // belum di-build ulang setelah menambah plugin baru). Lanjutkan presensi
      // tanpa verifikasi wajah alih-alih menggagalkan total.
      isBusy = false;
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(SnackBar(
        content: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                  "Deteksi wajah tidak tersedia — presensi dilanjutkan tanpa verifikasi wajah."),
            ),
          ],
        ),
      ));
      await _proceedToConfirmation(imageFile);
    } catch (e) {
      isBusy = false;
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showSnackBar("Gagal memproses deteksi wajah: $e", Icons.error_outline);
      }
    }
  }

  Future<void> _takePicture() async {
    try {
      final XFile imageFile = await controller!.takePicture();
      if (!mounted) return;

      // Di luar Android/iOS: lewati deteksi wajah, langsung ke konfirmasi.
      if (!_faceDetectionSupported) {
        _showSnackBar(
            "Deteksi wajah tidak tersedia di platform ini — presensi dilanjutkan tanpa verifikasi wajah.",
            Icons.info_outline_rounded);
        await _proceedToConfirmation(imageFile);
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final inputImage = InputImage.fromFilePath(imageFile.path);
      await processImage(inputImage, imageFile);
    } catch (e) {
      debugPrint("Failed to take picture: $e");
    }
  }

  Future<void> _submitAttendance() async {
    final nama = _namaController.text.trim();
    if (nama.isEmpty) {
      _showSnackBar("Nama wajib diisi.", Icons.warning_amber_rounded);
      return;
    }

    final now = DateTime.now();
    strDateTime = DateFormat('dd/MM/yyyy, HH:mm:ss').format(now);

    if (widget.isCheckout) {
      await submitCheckout(now, nama);
    } else {
      setStatusAbsen();
      await submitAbsen(strAlamat, nama, strStatus);
    }
  }

  /// Checkout (absen pulang): mencari dokumen hadir hari ini milik nama
  /// yang diketik, lalu menambah field checkout ke dokumen yang sama.
  ///
  /// Aturan:
  /// - Hanya bisa dilakukan jika sudah absen hadir hari ini.
  /// - Hanya bisa dilakukan sekali per hari (checkout_time belum terisi).
  /// - Sebelum jam 16:00 -> status "Early Leave", setelahnya -> "On Time".
  ///
  /// Query memakai equality-only (where name) + filter tanggal di memori
  /// agar tidak membutuhkan composite index di Firestore.
  Future<void> submitCheckout(DateTime now, String nama) async {
    _showLoaderDialog();

    try {
      final startOfToday = DateTime(now.year, now.month, now.day);
      final snapshot = await dataCollection.where('name', isEqualTo: nama).get();

      QueryDocumentSnapshot<Map<String, dynamic>>? target;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['type'] != 'attendance') continue;

        final createdAt = data['created_at'] as Timestamp?;
        if (createdAt == null || createdAt.toDate().isBefore(startOfToday)) {
          continue;
        }
        // Sudah pernah checkout -> lewati.
        if ((data['checkout_time'] ?? '').toString().isNotEmpty) continue;

        // Simpan dokumen hadir yang paling baru hari ini.
        if (target == null) {
          target = doc;
          continue;
        }
        final targetCreatedAt = target.data()['created_at'] as Timestamp?;
        if (targetCreatedAt == null ||
            createdAt.compareTo(targetCreatedAt) > 0) {
          target = doc;
        }
      }

      if (target == null) {
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pop();
        _showSnackBar(
            "Tidak ditemukan absen hadir hari ini untuk nama \"$nama\". "
            "Checkout hanya bisa dilakukan setelah absen hadir.",
            Icons.warning_amber_rounded);
        return;
      }

      final status = now.hour < 16 ? 'Early Leave' : 'On Time';

      // Hitung durasi kerja: jam hadir (created_at) -> jam checkout.
      final checkInAt = (target.data()['created_at'] as Timestamp?)?.toDate();
      final workDuration =
          checkInAt == null ? null : now.difference(checkInAt);
      final workDurationText =
          workDuration == null ? null : _formatWorkDuration(workDuration);

      await dataCollection.doc(target.id).update({
        'checkout_time': strDateTime,
        'checkout_address':
            strAlamat.isEmpty ? 'Lokasi tidak terekam' : strAlamat,
        'checkout_latitude': dLat,
        'checkout_longitude': dLong,
        'checkout_status': status,
        'checked_out_at': FieldValue.serverTimestamp(),
        'work_duration_minutes': ?workDuration?.inMinutes,
        'work_duration': ?workDurationText,
      });

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      final durationLine =
          workDurationText == null ? '' : ' Total waktu kerja: $workDurationText.';
      await showSuccessDialog(
        context,
        title: 'Checkout Terkirim!',
        message: status == 'Early Leave'
            ? 'Checkout tercatat sebelum jam 16.00 dengan status "Early Leave".$durationLine'
            : 'Checkout tercatat dengan status "$status".$durationLine '
                'Sampai jumpa besok!',
      );
      if (!mounted) return;

      // Kembali ke HomeScreen setelah sukses
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _showSnackBar("Gagal menyimpan checkout: $e", Icons.error_outline);
    }
  }

  /// Memformat durasi kerja menjadi teks yang mudah dibaca,
  /// misal "7 jam 42 menit".
  String _formatWorkDuration(Duration duration) {
    if (duration.isNegative) return '0 menit';
    final totalMinutes = duration.inMinutes;
    if (totalMinutes < 1) return 'kurang dari 1 menit';
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours == 0) return '$minutes menit';
    if (minutes == 0) return '$hours jam';
    return '$hours jam $minutes menit';
  }

  @override
  Widget build(BuildContext context) {
    final XFile? image = widget.image;
    return Scaffold(
      appBar: AppBar(
          title:
              Text(widget.isCheckout ? "Checkout Presensi" : "Absen Selfie")),
      body: SafeArea(
        child: image != null
            ? _buildConfirmationForm()
            : !isCameraReady
                ? const Center(child: CircularProgressIndicator())
                : _buildCameraView(),
      ),
    );
  }

  // ---------- Form konfirmasi setelah selfie ----------

  Widget _buildConfirmationForm() {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Hero(
            tag: 'selfie-preview',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: _selfieBytes != null
                  ? Image.memory(
                      _selfieBytes!,
                      height: 340,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : const SizedBox(
                      height: 340,
                      width: double.infinity,
                      child: Center(child: CircularProgressIndicator()),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          // Banner hasil pengenalan wajah.
          if (widget.recognizedName != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.green.withValues(alpha: 0.45)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_rounded,
                      size: 18, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Wajah dikenali sebagai ${widget.recognizedName} — nama terisi otomatis.',
                      style: text.bodySmall
                          ?.copyWith(color: Colors.green.shade700),
                    ),
                  ),
                ],
              ),
            )
          else if (FaceRecognitionService.instance.isSupported)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.45)),
              ),
              child: Row(
                children: [
                  Icon(Icons.face_retouching_off_rounded,
                      size: 18, color: Colors.orange.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Wajah tidak dikenali. Isi nama manual, atau daftarkan '
                      'wajahmu lewat menu "Daftar Wajah".',
                      style: text.bodySmall
                          ?.copyWith(color: Colors.orange.shade800),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          LocationCard(isLoading: isLoading, address: strAlamat),
          const SizedBox(height: 16),
          TextField(
            controller: _namaController,
            readOnly: widget.recognizedName != null,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: "Nama Lengkap",
              prefixIcon: Icon(Icons.person_rounded),
            ),
          ),
          const SizedBox(height: 12),
          // Penjelasan aturan status otomatis.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  widget.isCheckout
                      ? Icons.logout_rounded
                      : Icons.info_outline_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.isCheckout
                        ? 'Checkout bebas kapan saja setelah hadir. '
                            'Sebelum jam 16.00 tercatat "Early Leave", '
                            'setelahnya "On Time".'
                        : 'Status ditentukan otomatis: sebelum 08.31 tercatat Hadir, setelah itu Terlambat.',
                    style: text.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _submitAttendance,
            icon: Icon(widget.isCheckout
                ? Icons.logout_rounded
                : Icons.check_circle),
            label:
                Text(widget.isCheckout ? "Kirim Checkout" : "Kirim Presensi"),
          ),
        ],
      ),
    );
  }

  // ---------- Tampilan kamera dengan bingkai scan ----------

  Widget _buildCameraView() {
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Positioned.fill(child: CameraPreview(controller!)),
        // Overlay gelap lembut agar bingkai menonjol.
        Positioned.fill(
          child: DecoratedBox(
            decoration:
                BoxDecoration(color: Colors.black.withValues(alpha: 0.25)),
          ),
        ),
        const Center(
          child: IgnorePointer(child: FaceScanFrame()),
        ),
        // Petunjuk di atas bingkai.
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Posisikan wajah di dalam bingkai',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
        ),
        // Tombol shutter besar khas aplikasi kamera.
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 36),
            child: GestureDetector(
              onTap: isBusy ? null : _takePicture,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isBusy ? Colors.grey : scheme.primary,
                    ),
                    child: isBusy
                        ? const Center(
                            child: SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.camera_alt,
                            color: Colors.white, size: 30),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
