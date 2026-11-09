import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:attendance_app/ui/dashboard_screen.dart';
import 'package:attendance_app/ui/home_screen.dart';
import 'package:attendance_app/ui/widgets/empty_state.dart';
import 'package:attendance_app/ui/widgets/face_scan_frame.dart';
import 'package:attendance_app/ui/widgets/success_dialog.dart';
import 'package:attendance_app/utils/face_detection/google_ml_kit.dart';
import 'package:attendance_app/utils/face_recognition/face_recognition_service.dart';

/// Layar masuk dengan verifikasi wajah — untuk yang sudah punya akun
/// (mis. ganti perangkat, install ulang, atau setelah reset data).
///
/// Alur: selfie -> dicocokkan ke database wajah (Luxand Cloud) ->
/// bila dikenali, data diri (nama + kelas) dipulihkan ke perangkat
/// dan user langsung masuk dashboard tanpa mendaftar ulang.
///
/// - Android/iOS : wajah divalidasi lokal via ML Kit sebelum dikirim.
/// - Web         : foto dikirim apa adanya, divalidasi server Luxand.
class FaceLoginScreen extends StatefulWidget {
  const FaceLoginScreen({super.key});

  @override
  State<FaceLoginScreen> createState() => _FaceLoginScreenState();
}

class _FaceLoginScreenState extends State<FaceLoginScreen> {
  final faceDetector = GoogleMlKit.vision.faceDetector();

  CameraController? _controller;
  bool _isCameraReady = false;
  bool _cameraFailed = false;

  /// ML Kit (validasi wajah lokal) hanya ada di Android & iOS.
  late final bool _faceCheckSupported =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// 0 = pemindaian, 1 = memverifikasi/masuk.
  int _phase = 0;

  bool _busy = false;
  String _feedback = 'Posisikan wajah di dalam bingkai untuk masuk';

  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _startCamera();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _controller?.dispose();
    // close() bisa melempar MissingPluginException di platform tak didukung.
    try {
      faceDetector.close();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Masuk dengan Wajah')),
      body: SafeArea(
        child: !FaceRecognitionService.instance.isSupported
            ? const EmptyState(
                icon: Icons.face_retouching_off_rounded,
                title: 'Konfigurasi Belum Lengkap',
                message:
                    'API token face recognition belum diatur.\n'
                    'Hubungi pengembang aplikasi.',
              )
            : _phase == 1
                ? _buildVerifyingView(text)
                : _buildScanView(),
      ),
    );
  }

  // ---------- Kamera & pemindaian ----------

  Future<void> _startCamera() async {
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
      debugPrint('Gagal inisialisasi kamera login: $e');
      if (!mounted) return;
      setState(() {
        _cameraFailed = true;
        _isCameraReady = false;
      });
      return;
    }
    if (!mounted) return;
    setState(() => _isCameraReady = true);
    _startAutoCapture();
  }

  void _startAutoCapture() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      _attemptVerify();
    });
  }

  Widget _buildScanView() {
    final scheme = Theme.of(context).colorScheme;
    final controller = _controller;

    // Kamera gagal dibuka (mis. izin ditolak) -> tawarkan retry.
    if (_cameraFailed) {
      return EmptyState(
        icon: Icons.videocam_off_rounded,
        title: 'Kamera Gagal Dibuka',
        message:
            'Izinkan akses kamera pada perangkat ini, lalu coba lagi.',
        actionLabel: 'Coba Lagi',
        onAction: () {
          setState(() => _cameraFailed = false);
          _startCamera();
        },
      );
    }

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

        // Judul + feedback.
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Verifikasi Wajah',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
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

        // Tombol verifikasi manual + indikator pemindaian.
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
                    onTap: _attemptVerify,
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
                          child: const Icon(Icons.face_retouching_natural,
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

  Widget _buildVerifyingView(TextTheme text) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('Wajah dikenali — masuk ke akun...', style: text.bodyMedium),
        ],
      ),
    );
  }

  // ---------- Verifikasi & masuk ----------

  /// Menangkap selfie lalu mencocokkannya ke database wajah.
  /// Dipanggil otomatis oleh timer dan bisa dipicu manual.
  Future<void> _attemptVerify() async {
    final controller = _controller;
    if (_busy || _phase != 0) return;
    if (!mounted) return;
    if (controller == null || !_isCameraReady) return;

    _busy = true;
    if (mounted) setState(() {});

    try {
      final file = await controller.takePicture();
      if (!mounted) return;

      // Validasi keberadaan wajah hanya di Android/iOS (butuh ML Kit).
      if (_faceCheckSupported) {
        final hasFace = await _hasVisibleFace(file);
        if (!mounted) return;
        if (!hasFace) {
          _setFeedback(
              'Wajah tidak terlihat — pastikan wajah jelas di bingkai.');
          return;
        }
      }

      // Cocokkan selfie ke seluruh database wajah di Luxand.
      final match = await FaceRecognitionService.instance.matchFromXFile(file);
      if (!mounted) return;
      if (!match.isMatch) {
        _setFeedback(
            'Wajah tidak dikenali — pastikan wajah ini sudah pernah '
            'didaftarkan sebelumnya.');
        return;
      }

      // Dikenali -> pulihkan akun dan masuk dashboard.
      await _loginAs(match.name!);
    } catch (e) {
      debugPrint('Gagal verifikasi wajah login: $e');
      _setFeedback('Terjadi kendala saat mengambil foto — coba lagi.');
    } finally {
      _busy = false;
      if (mounted && _phase == 0) setState(() {});
    }
  }

  Future<bool> _hasVisibleFace(XFile file) async {
    try {
      final inputImage = InputImage.fromFilePath(file.path);
      final faces = await faceDetector.processImage(inputImage);
      return faces.isNotEmpty;
    } catch (e) {
      debugPrint('Gagal deteksi wajah login: $e');
      return false;
    }
  }

  /// Memulihkan data akun atas nama [name] ke perangkat ini lalu masuk.
  Future<void> _loginAs(String name) async {
    _autoTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _phase = 1;
      _feedback = '';
    });

    // Pulihkan kelas dari profil wajah (best-effort; boleh kosong).
    final kelas = await FaceProfileStore.loadClassForName(name);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kUserNameKey, name);
    if (kelas != null) await prefs.setString(kUserClassKey, kelas);
    await prefs.setBool(kUserRegisteredKey, true);

    if (!mounted) return;
    await showSuccessDialog(
      context,
      title: 'Berhasil Masuk!',
      message: 'Selamat datang kembali, $name.'
          '${kelas != null ? '\nKelas: $kelas' : ''}',
    );
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const DashboardScreen()),
    );
  }

  void _setFeedback(String message) {
    if (!mounted) return;
    setState(() => _feedback = message);
  }
}
