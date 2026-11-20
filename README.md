# Eling Sholat

Aplikasi Android (Flutter) pengingat waktu sholat + checklist harian.

## Fitur
- Jadwal 5 waktu dihitung **offline** (metode Kemenag RI: Subuh 20°, Isya 18°, Ashar Syafi'i, ihtiyat 2 menit).
- Lokasi dari GPS atau pilih kota.
- Notifikasi saat masuk waktu sholat (dijadwalkan 7 hari ke depan, tetap aktif setelah HP restart).
- Checklist per sholat; hanya bisa dicentang setelah waktunya masuk.
- Jika belum dicentang, ada pengingat ulang 30 menit setelah adzan.
- Lihat & isi checklist hari-hari sebelumnya, progress x/5.

## Cara menjalankan
1. Install Flutter: `brew install --cask flutter` (atau lihat https://docs.flutter.dev/get-started/install/macos)
2. Install Android Studio (untuk Android SDK + emulator), lalu jalankan `flutter doctor --android-licenses`.
3. Di folder ini: `bash setup.sh`
4. `flutter run` (HP dengan USB debugging atau emulator)

Build APK: `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`

## Struktur
- `lib/prayer_calc.dart` — perhitungan waktu sholat
- `lib/notification_service.dart` — penjadwalan notifikasi
- `lib/storage.dart` — simpan lokasi & checklist (shared_preferences)
- `lib/home_page.dart` — UI utama
