import 'dart:convert';

import 'package:camera/camera.dart' show XFile;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:attendance_app/config/luxand_config.dart';

/// Hasil pencocokan wajah selfie dengan database wajah di Luxand Cloud.
class FaceMatchResult {
  final String? name;
  final double score;

  const FaceMatchResult._(this.name, this.score);

  bool get isMatch => name != null;
}

/// Pengenalan wajah via Luxand Cloud API (https://luxand.cloud).
///
/// Alur:
/// 1. Enrollment : foto dikirim ke `POST /v2/person` -> dapat `uuid`.
/// 2. Verifikasi : selfie dikirim ke `POST /photo/search/v2` -> nama +
///    probability orang yang dikenali.
///
/// Karena murni HTTP, fitur ini jalan di Android, iOS, DAN Web.
/// Wajah tersimpan di server Luxand sebagai template (bukan foto).
/// Aplikasi membutuhkan koneksi internet untuk verifikasi.
class FaceRecognitionService {
  FaceRecognitionService._();

  static final FaceRecognitionService instance = FaceRecognitionService._();

  /// Aktif selama token tersedia. Verifikasi sendiri tetap butuh internet;
  /// bila request gagal, hasilnya "tidak dikenali" -> presensi lanjut
  /// dengan nama manual (tidak pernah memblokir total).
  bool get isSupported => kLuxandApiToken.isNotEmpty;

  Map<String, String> get _headers => {'token': kLuxandApiToken};

  /// Tidak ada lagi model lokal yang perlu dimuat lebih awal.
  /// Method dipertahankan agar pemanggil lama tetap kompatibel.
  Future<void> warmUp() async {}

  /// Mendaftarkan orang baru beserta satu foto wajahnya.
  /// Return `uuid` orang di Luxand, atau null bila gagal.
  Future<String?> enrollPerson(XFile file, String name) async {
    try {
      final bytes = await file.readAsBytes();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$kLuxandBaseUrl/v2/person'),
      )
        ..headers.addAll(_headers)
        ..fields['name'] = name
        ..fields['store'] = '1'
        ..files.addAll(_photoFields(bytes));

      final response = await http.Response.fromStream(
        await request.send().timeout(const Duration(seconds: 30)),
      );
      final body = _decodeJson(response);

      if (response.statusCode == 200 && body is Map) {
        final uuid = body['uuid']?.toString();
        if (uuid != null && uuid.isNotEmpty) return uuid;
      }
      debugPrint(
          'Luxand enroll gagal (${response.statusCode}): ${response.body}');
    } catch (e) {
      debugPrint('Luxand enroll error: $e');
    }
    return null;
  }

  /// Menambahkan foto tambahan untuk orang yang sudah terdaftar.
  /// Semakin banyak sudut/foto, akurasi pengenalan makin baik.
  Future<bool> addFaceToPerson(XFile file, String uuid) async {
    try {
      final bytes = await file.readAsBytes();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$kLuxandBaseUrl/v2/person/$uuid'),
      )
        ..headers.addAll(_headers)
        ..fields['store'] = '1'
        ..files.addAll(_photoFields(bytes));

      final response = await http.Response.fromStream(
        await request.send().timeout(const Duration(seconds: 30)),
      );
      if (response.statusCode == 200) return true;
      debugPrint(
          'Luxand add-face gagal (${response.statusCode}): ${response.body}');
    } catch (e) {
      debugPrint('Luxand add-face error: $e');
    }
    return false;
  }

  /// Mengenali wajah pada [file]: mencocokkan ke seluruh database wajah
  /// di Luxand. Return nama + score bila cocok di atas threshold.
  Future<FaceMatchResult> matchFromXFile(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$kLuxandBaseUrl/photo/search/v2'),
      )
        ..headers.addAll(_headers)
        ..files.add(http.MultipartFile.fromBytes('photo', bytes,
            filename: 'selfie.jpg'));

      final response = await http.Response.fromStream(
        await request.send().timeout(const Duration(seconds: 30)),
      );
      if (response.statusCode != 200) {
        debugPrint(
            'Luxand search gagal (${response.statusCode}): ${response.body}');
        return const FaceMatchResult._(null, 0);
      }

      final best = _bestFace(_extractFaces(_decodeJson(response)));
      if (best == null) return const FaceMatchResult._(null, 0);

      final name = best['name']?.toString();
      final score = _probabilityOf(best);
      if (name != null && name.isNotEmpty && score >= kLuxandMatchThreshold) {
        return FaceMatchResult._(name, score);
      }
      return FaceMatchResult._(null, score);
    } catch (e) {
      debugPrint('Luxand search error: $e');
      return const FaceMatchResult._(null, 0);
    }
  }

  /// Menghapus orang terdaftar dari database wajah Luxand.
  Future<bool> deletePerson(String uuid) async {
    try {
      final response = await http
          .delete(Uri.parse('$kLuxandBaseUrl/v2/person/$uuid'),
              headers: _headers)
          .timeout(const Duration(seconds: 30));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Luxand delete error: $e');
      return false;
    }
  }

  // ---------- Helper ----------

  /// Luxand menerima field `photos` pada /v2/person dan `photo` pada
  /// endpoint lain. Keduanya dikirim agar kompatibel dengan semua versi API.
  List<http.MultipartFile> _photoFields(Uint8List bytes) => [
        http.MultipartFile.fromBytes('photos', bytes, filename: 'face.jpg'),
        http.MultipartFile.fromBytes('photo', bytes, filename: 'face.jpg'),
      ];

  dynamic _decodeJson(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  /// Bentuk response /photo/search/v2 bisa berupa list langsung atau
  /// map dengan key `faces` — ditangani keduanya.
  List<dynamic> _extractFaces(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map) {
      final faces = decoded['faces'];
      if (faces is List) return faces;
    }
    return const [];
  }

  Map<String, dynamic>? _bestFace(List<dynamic> faces) {
    Map<String, dynamic>? best;
    double bestScore = -1;
    for (final face in faces) {
      if (face is! Map) continue;
      final score = _probabilityOf(face);
      if (score > bestScore) {
        bestScore = score;
        best = Map<String, dynamic>.from(face);
      }
    }
    return best;
  }

  /// Probability kadang berbentuk 0-1, kadang persen 0-100.
  double _probabilityOf(Map face) {
    final raw = face['probability'] ?? face['confidence'] ?? face['score'];
    if (raw is num) {
      final value = raw.toDouble();
      return value > 1 ? value / 100 : value;
    }
    return 0;
  }
}

/// Bookkeeping lokal (Firestore) untuk memetakan nama -> daftar uuid
/// Luxand. Matching TIDAK lewat sini — hanya agar pendaftaran ulang tahu
/// uuid mana yang harus dihapus dari server.
///
/// Struktur dokumen (koleksi `face_profiles`):
/// ```js
/// { name: "Budi", uuids: ["..."], created_at: <serverTimestamp> }
/// ```
class FaceProfileStore {
  FaceProfileStore._();

  static CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection('face_profiles');

  /// Daftar uuid Luxand milik [name]. Gagal koneksi -> list kosong.
  static Future<List<String>> loadUuidsForName(String name) async {
    try {
      final snapshot =
          await _collection.where('name', isEqualTo: name).limit(1).get();
      if (snapshot.docs.isEmpty) return [];
      final raw = snapshot.docs.first.data()['uuids'];
      if (raw is List) {
        return raw.map((v) => v.toString()).where((s) => s.isNotEmpty).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Gagal memuat profil wajah: $e');
      return [];
    }
  }

  /// Menyimpan mapping nama -> uuids (menimpa doc lama dengan nama sama).
  /// [kelas] ikut disimpan agar login via wajah di perangkat lain tetap
  /// bisa memulihkan data diri lengkap.
  static Future<void> save({
    required String name,
    required List<String> uuids,
    String? kelas,
  }) async {
    try {
      final existing = await _collection.where('name', isEqualTo: name).get();
      for (final doc in existing.docs) {
        await doc.reference.delete();
      }
      await _collection.add({
        'name': name,
        'uuids': uuids,
        if (kelas != null && kelas.isNotEmpty) 'kelas': kelas,
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Gagal menyimpan profil wajah: $e');
    }
  }

  /// Memuat kelas milik [name] dari profil wajah — dipakai saat masuk
  /// via verifikasi wajah agar data diri terpulihkan tanpa daftar ulang.
  /// Return null bila profil tidak ada / kelas belum pernah disimpan.
  static Future<String?> loadClassForName(String name) async {
    try {
      final snapshot =
          await _collection.where('name', isEqualTo: name).limit(1).get();
      if (snapshot.docs.isEmpty) return null;
      final kelas = snapshot.docs.first.data()['kelas']?.toString();
      return (kelas == null || kelas.isEmpty) ? null : kelas;
    } catch (e) {
      debugPrint('Gagal memuat kelas profil wajah: $e');
      return null;
    }
  }
}
