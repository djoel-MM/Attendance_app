import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:attendance_app/ui/home_screen.dart';
import 'package:attendance_app/ui/widgets/empty_state.dart';
import 'package:attendance_app/ui/widgets/face_scan_frame.dart';
import 'package:attendance_app/ui/widgets/success_dialog.dart';
import 'package:attendance_app/utils/face_detection/google_ml_kit.dart';
import 'package:attendance_app/utils/face_recognition/face_recognition_service.dart';

/// Layar pendaftaran wajah — wajah dikirim ke Luxand Cloud API sehingga
/// pendaftaran bisa dilakukan dari Android, iOS, maupun Web.
///
/// Alur: isi nama -> kamera dengan panduan 3 foto
/// (Hadap Depan -> Hadap Samping -> Hadap Samping Lainnya).
///
/// - Android/iOS : frame ditangkap otomatis tiap ~2 detik dan divalidasi
///   lewat sudut kepala (euler angle) ML Kit sebelum dikirim.
/// - Platform lain (Web): tanpa validasi pose lokal — foto dikirim apa
///   adanya; keberadaan wajah divalidasi oleh server Luxand.
///
/// Jika [presetName] diberikan (alur sertifikasi awal), form nama
/// dilewati dan layar langsung membuka kamera. [presetClass] opsional —
/// kelas yang diisi pada form sertifikasi, disimpan bersama profil wajah.
/// Selesai -> `Navigator.pop(context, true)`.
class FaceEnrollmentScreen extends StatefulWidget {
  final String? presetName;
  final String? presetClass;

  const FaceEnrollmentScreen({super.key, this.presetName, this.presetClass});

  @override
  State<FaceEnrollmentScreen> createState() => _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends State<FaceEnrollmentScreen> {
  static const int _totalSteps = 3;

  final TextEditingController _nameController = TextEditingController();
  final faceDetector = GoogleMlKit.vision.faceDetector();

  CameraController? _controller;
  bool _isCameraReady = false;
  bool _cameraFailed = false;

  /// ML Kit (validasi pose lokal) hanya ada di Android & iOS.
  late final bool _poseGuideSupported =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// 0 = form nama (bila tanpa presetName), 1 = pemindaian, 2 = menyimpan.
  int _phase = 0;
  int _step = 0;

  String _name = '';

  /// Uuid orang di database Luxand — foto pertama membuatnya,
  /// foto berikutnya menempel ke uuid yang sama.
  String? _luxandUuid;
  bool _isDeletingOldProfile = false;

  /// Arah putar kepala pada pose samping pertama (1 = kanan, -1 = kiri)
  /// agar pose kedua dipastikan arah sebaliknya.
  int? _firstSideSign;

  bool _busy = false;
  bool _isSaving = false;
  String _feedback = 'Posisikan wajah di dalam bingkai';

  @override
  void initState() {
    super.initState();
    if (widget.presetName != null && widget.presetName!.trim().isNotEmpty) {
      _name = widget.presetName!.trim();
      _phase = 1;
      _startScan();
    } else {
      _phase = 0;
      _loadSavedName();
    }
  }

  Future<void> _loadSavedName() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(kUserNameKey);
    if (saved != null && saved.isNotEmpty && mounted) {
      _nameController.text = saved;
    }
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _controller?.dispose();
    _nameController.dispose();
    // close() bisa melempar MissingPluginException di platform tak didukung.
    try {
      faceDetector.close();
    } catch (_) {}
    super.dispose();
  }

  // ---------- Form nama ----------

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
          title: Text(
              _poseGuideSupported ? 'Daftar Wajah' : 'Daftar Wajah (Online)')),
      body: SafeArea(
        child: !FaceRecognitionService.instance.isSupported
            ? const EmptyState(
                icon: Icons.face_retouching_off_rounded,
                title: 'Konfigurasi Belum Lengkap',
                message:
                    'API token face recognition belum diatur.\n'
                    'Hubungi pengembang aplikasi.',
              )
            : _phase == 0
                ? _buildNameForm(text)
                : _phase == 1
                    ? _buildScanView(text)
                    : _buildSavingView(text),
      ),
    );
  }

  Widget _buildNameForm(TextTheme text) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.face_retouching_natural_rounded,
              size: 72, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'Daftarkan Wajah Kamu',
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Setelah terdaftar, presensi akan mengenali wajahmu dan '
            'mengisi nama otomatis. Pendaftaran ulang dengan nama sama '
            'akan menimpa data lama.',
            style: text.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nama Lengkap',
              prefixIcon: Icon(Icons.person_rounded),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _startScan,
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('Lanjut Scan Wajah'),
          ),
        ],
      ),
    );
  }

  // ---------- Pemindaian pose ----------

  List<String> get _stepLabels => _poseGuideSupported
      ? const ['Hadap Depan', 'Hadap Samping', 'Hadap Samping Lainnya']
      : const ['Foto Wajah Depan', 'Foto Tambahan', 'Foto Tambahan Lagi'];

  Future<void> _startScan() async {
    // Dari form nama.
    if (_name.isEmpty) {
      final nama = _nameController.text.trim();
      if (nama.isEmpty) {
        _showSnack('Nama wajib diisi.', Icons.warning_amber_rounded);
        return;
      }
      _name = nama;
    }

    // Hapus profil lama dengan nama sama (best-effort) agar tidak menumpuk.
    _isDeletingOldProfile = true;
    final oldUuids = await FaceProfileStore.loadUuidsForName(_name);
    for (final uuid in oldUuids) {
      await FaceRecognitionService.instance.deletePerson(uuid);
    }
    _isDeletingOldProfile = false;

    final cameras = await availableCameras();
    if (cameras.isEmpty || !mounted) return;
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      frontCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _controller = controller;
    _isCameraReady = false;

    try {
      await controller.initialize();
    } catch (e) {
      debugPrint('Gagal inisialisasi kamera enrollment: $e');
      if (!mounted) return;
      setState(() {
        _cameraFailed = true;
        _phase = 1;
      });
      _showSnack('Gagal membuka kamera.', Icons.error_outline);
      return;
    }
    if (!mounted) return;
    setState(() {
      _isCameraReady = true;
      _phase = 1;
    });
    _startAutoCapture();
  }

  void _startAutoCapture() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(const Duration(milliseconds: 2200), (_) {
      _attemptCapture();
    });
  }

  Widget _buildScanView(TextTheme text) {
    final scheme = Theme.of(context).colorScheme;
    final controller = _controller;

    // Kamera gagal dibuka (mis. izin ditolak di browser) -> tawarkan retry.
    if (_cameraFailed) {
      return EmptyState(
        icon: Icons.videocam_off_rounded,
        title: 'Kamera Gagal Dibuka',
        message:
            'Izinkan akses kamera pada browser/perangkat ini, '
            'lalu coba lagi.',
        actionLabel: 'Coba Lagi',
        onAction: () {
          setState(() => _cameraFailed = false);
          _startScan();
        },
      );
    }

    // Kamera masih dalam persiapan (Firestore + availableCameras +
    // initialize) -> jangan akses _controller sebelum benar-benar siap.
    if (controller == null || !_isCameraReady) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Menyiapkan kamera...'),
          ],
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(child: CameraPreview(controller)),
        Positioned.fill(
          child: DecoratedBox(
            decoration:
                BoxDecoration(color: Colors.black.withValues(alpha: 0.25)),
          ),
        ),
        const Center(child: IgnorePointer(child: FaceScanFrame())),

        // Progres 3 foto di atas layar.
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _totalSteps; i++) ...[
                  _stepChip(i),
                  if (i < _totalSteps - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),

        // Instruksi pose + feedback.
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 72),
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _stepLabels[_step.clamp(0, _totalSteps - 1)],
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  constraints: const BoxConstraints(maxWidth: 320),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _feedback,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Tombol tangkap manual + indikator pemindaian.
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 36),
            child: _busy
                ? const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                : GestureDetector(
                    onTap: _attemptCapture,
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: scheme.primary,
                          ),
                          child: const Icon(Icons.camera_alt,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _stepChip(int index) {
    final done = index < _step;
    final active = index == _step;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: done
            ? Colors.green.withValues(alpha: 0.8)
            : active
                ? Colors.white.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 13,
            color: Colors.white,
          ),
          const SizedBox(width: 5),
          Text(
            _stepLabels[index],
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ---------- Penangkapan & pengiriman ----------

  Timer? _autoTimer;

  /// Menangkap foto, memvalidasi pose (bila didukung), lalu mengirim foto
  /// ke Luxand. Dipanggil otomatis oleh timer dan bisa dipicu manual.
  Future<void> _attemptCapture() async {
    final controller = _controller;
    if (_busy || _isSaving || _isDeletingOldProfile) return;
    if (!mounted || _step >= _totalSteps) return;
    if (controller == null || !_isCameraReady) return;

    _busy = true;
    if (mounted) setState(() {});

    try {
      final file = await controller.takePicture();
      if (!mounted) return;

      // Validasi pose lokal hanya di Android/iOS (butuh ML Kit).
      if (_poseGuideSupported) {
        final face = await _detectFace(file);
        if (!mounted) return;
        if (face == null) {
          _setFeedback('Wajah tidak terlihat — pastikan wajah jelas di bingkai.');
          return;
        }
        if (!_poseMatches(face)) {
          _setFeedback(_poseHint());
          return;
        }
        if (face.headEulerAngleY != null &&
            face.headEulerAngleY!.abs() >= 12) {
          _firstSideSign ??= face.headEulerAngleY!.sign.toInt();
        }
      }

      // Kirim foto ke Luxand Cloud.
      final sent = await _sendToLuxand(file);
      if (!mounted) return;
      if (!sent) {
        _setFeedback(_poseGuideSupported
            ? 'Gagal mengirim ke server — periksa internet lalu coba lagi.'
            : 'Wajah tidak terdeteksi di foto, atau koneksi bermasalah — '
                'posisikan wajah jelas di bingkai lalu coba lagi.');
        return;
      }

      setState(() {
        _step++;
        _feedback = 'Bagus! Foto tersimpan.';
      });

      if (_step >= _totalSteps) {
        _autoTimer?.cancel();
        await _finishEnrollment();
      }
    } catch (e) {
      debugPrint('Gagal menangkap foto enrollment: $e');
      _setFeedback('Terjadi kendala saat mengambil foto — coba lagi.');
    } finally {
      _busy = false;
      if (mounted) setState(() {});
    }
  }

  /// Mengirim foto ke Luxand: foto pertama membuat orang baru,
  /// foto berikutnya menempel ke orang yang sama.
  Future<bool> _sendToLuxand(XFile file) async {
    final service = FaceRecognitionService.instance;
    if (_luxandUuid == null) {
      _luxandUuid = await service.enrollPerson(file, _name);
      return _luxandUuid != null;
    }
    return service.addFaceToPerson(file, _luxandUuid!);
  }

  Future<Face?> _detectFace(XFile file) async {
    try {
      final inputImage = InputImage.fromFilePath(file.path);
      final faces = await faceDetector.processImage(inputImage);
      if (faces.isEmpty) return null;
      // Wajah terbesar diasumsikan wajah si pendaftar.
      return faces.reduce((a, b) =>
              a.boundingBox.width * a.boundingBox.height >=
                      b.boundingBox.width * b.boundingBox.height
                  ? a
                  : b);
    } catch (e) {
      debugPrint('Gagal deteksi wajah enrollment: $e');
      return null;
    }
  }

  bool _poseMatches(Face face) {
    final y = face.headEulerAngleY ?? 0;
    final z = face.headEulerAngleZ ?? 0;
    switch (_step) {
      case 0:
        // Hadap tegak: sedikit toleransi miring/putar.
        return y.abs() <= 10 && z.abs() <= 20;
      case 1:
        // Samping pertama: arah bebas, disimpan sebagai acuan pose kedua.
        return y.abs() >= 12 && z.abs() <= 30;
      case 2:
        // Samping kedua: harus arah sebaliknya dari pose pertama.
        return y.abs() >= 12 &&
            z.abs() <= 30 &&
            _firstSideSign != null &&
            y.sign.toInt() != _firstSideSign;
      default:
        return false;
    }
  }

  String _poseHint() {
    switch (_step) {
      case 0:
        return 'Luruskan kepala — hadap tegak lurus ke depan.';
      case 1:
        return 'Putar kepala ke samping sampai profil wajah terlihat.';
      case 2:
        return 'Sekarang putar ke arah sebaliknya dari sebelumnya.';
      default:
        return _feedback;
    }
  }

  void _setFeedback(String message) {
    if (!mounted) return;
    setState(() => _feedback = message);
  }

  // ---------- Penyimpanan ----------

  Widget _buildSavingView(TextTheme text) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            _isSaving
                ? 'Menyimpan profil wajah...'
                : 'Menyelesaikan pendaftaran...',
            style: text.bodyMedium,
          ),
        ],
      ),
    );
  }

  /// Menyimpan bookkeeping nama -> uuid ke Firestore, menampilkan dialog
  /// sukses, lalu menutup layar dengan hasil `true`.
  Future<void> _finishEnrollment() async {
    if (!mounted) return;
    setState(() {
      _phase = 2;
      _isSaving = true;
    });

    try {
      final uuids = [?_luxandUuid];
      final kelas = await _resolveClass();
      await FaceProfileStore.save(name: _name, uuids: uuids, kelas: kelas);
      if (!mounted) return;

      await showSuccessDialog(
        context,
        title: 'Wajah Terdaftar!',
        message:
            'Presensi berikutnya akan mengenali wajahmu dan mengisi nama '
            'otomatis.',
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Gagal menyimpan profil wajah: $e');
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _phase = 1;
        _step = _totalSteps - 1;
        _feedback = 'Gagal menyimpan — coba tangkap foto terakhir lagi.';
      });
    }
  }

  /// Kelas yang disimpan bersama profil wajah: dari form sertifikasi,
  /// atau dari data yang sudah ada di perangkat.
  Future<String?> _resolveClass() async {
    if (widget.presetClass != null && widget.presetClass!.trim().isNotEmpty) {
      return widget.presetClass!.trim();
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(kUserClassKey);
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
