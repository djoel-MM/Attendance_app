/// Konfigurasi Face Recognition API (Luxand Cloud).
///
/// Catatan keamanan: token di aplikasi client dapat terlihat oleh orang
/// yang membongkar aplikasi. Untuk project belajar ini hal tersebut
/// dapat diterima — token bisa di-regenerate kapan saja dari
/// https://dashboard.luxand.cloud
library;

const String kLuxandApiToken = '9967370981384e8b97edf274263d08fd';

const String kLuxandBaseUrl = 'https://api.luxand.cloud';

/// Ambang probability dari API untuk menganggap wajah cocok.
/// Naikkan bila sering salah-kenal (false accept), turunkan bila sering
/// gagal-kenal wajah sendiri. Rentang nyaman: 0.70 - 0.90.
const double kLuxandMatchThreshold = 0.80;
