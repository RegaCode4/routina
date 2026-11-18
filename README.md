# Routina

Perencana aktivitas personal offline untuk Android dan iOS. Profil, kalender, tugas, rutinitas, preferensi, dan riwayat menggunakan SQLite lokal. Pemilihan tujuan cloud untuk file backup tersedia melalui pemilih file/Share Sheet perangkat. Status tiap fitur dan batas verifikasi tercatat dalam [audit kesiapan rilis](docs/RELEASE_READINESS.md).

## Instalasi dan pengembangan

- Gunakan Flutter stable 3.41.2 dengan Dart 3.11.0 sebagai baseline yang diuji.
- Untuk Android, pasang Android SDK platform 36, Java 17 atau JDK bawaan Android Studio yang kompatibel, serta emulator atau perangkat. Minimum Android yang dikonfigurasi adalah API 24.
- Untuk iOS, gunakan macOS, Xcode dan CocoaPods yang kompatibel. Runner saat ini menargetkan iOS 13.0 ke atas. Verifikasi versi alat yang diterima App Store Connect sebelum pengiriman. [Persyaratan Apple](https://developer.apple.com/news/upcoming-requirements/)
- Jalankan perintah dari root repositori. Instalasi SDK dan resolusi paket awal memerlukan cache terisi atau akses jaringan. Aplikasi yang terpasang dapat dipakai offline.

```sh
flutter doctor -v
flutter pub get --enforce-lockfile
flutter devices
flutter run -d <device-id>
```

Peluncuran biasa membuka Splash dan onboarding untuk instalasi baru. Pratinjau fixture dan galeri dapat dijalankan dalam build pengembangan.

```sh
flutter run --dart-define=ROUTINA_PREVIEW=returning
flutter run -t lib/presentation/design_system/widget_gallery.dart
```

## Pengujian

```sh
dart format --output=none --set-exit-if-changed lib test integration_test test_driver
flutter analyze
flutter test --concurrency=1
flutter test integration_test -d <device-id>
```

Untuk smoke test offline, jalankan integrasi dengan Wi-Fi dan data seluler perangkat uji dimatikan. Tes membuat database lokal sementara dan memulai penyiapan dari awal. Gunakan emulator khusus saat mengubah konektivitas atau izin perangkat.

Gunakan [checklist verifikasi perangkat](docs/ANDROID_DEVICE_QA.md) untuk skenario reboot, lock screen, penghentian proses, izin OS, dan pembaca layar.

Tangkapan layar Flutter dapat dibuat pada Android dengan driver integrasi. Hasilnya tersimpan di `build/visual-audit/`.

```sh
flutter drive --driver=test_driver/offline_journey_driver.dart --target=integration_test/offline_journey_test.dart -d <device-id> --dart-define=ROUTINA_CAPTURE=true
```

## Build

```sh
flutter build apk --debug
flutter build apk --release
```

Jalankan perintah build release dengan resolusi paket bawaan Flutter agar registrasi plugin dibuat ulang untuk mode release.

Distribusi Android ditujukan melalui **landing page resmi dengan universal signed APK**. Release tanpa kredensial signing pemilik sekarang gagal; gunakan satu sumber lengkap dari `android/key.properties` atau environment variables. Path relatif `storeFile` dibaca dari `android/`. Lihat [pengelolaan key](docs/ANDROID_SIGNING.md) dan [pipeline APK](docs/ANDROID_DISTRIBUTION.md). Identitas publik masih **DECISION REQUIRED** (`com.example.routina`), key pemilik belum tersedia, ikon/splash final serta upgrade APK masih PENDING. APK unsigned hanya untuk audit lokal dan tidak siap dipublikasikan. AAB dan Google Play bukan target Fase 19.

```powershell
# Build dan pemeriksaan lokal unsigned yang eksplisit; tidak untuk publikasi.
./tool/prepare_android_apk.ps1 -AndroidSdk C:/Android/Sdk -AuditUnsigned
```

[Spesifikasi landing page](docs/LANDING_PAGE_DISTRIBUTION.md) dan [status Android Developer Verification](docs/ANDROID_DEVELOPER_VERIFICATION.md) melengkapi gerbang rilis. Tidak ada APK yang diterbitkan pada fase persiapan ini.

Pada macOS, gunakan `flutter build ios --release --no-codesign` untuk validasi kompilasi tanpa signing. Untuk distribusi, tetapkan bundle identifier, team dan provisioning melalui workspace Runner, lalu jalankan `flutter build ipa --release`. [Panduan distribusi iOS](https://docs.flutter.dev/deployment/ios)

## Referensi proyek

- [PRD](PRD.md), [DESIGN](DESIGN.md), dan [peta FigCraft](docs/FIGCRAFT_SCREEN_MAP.md)
- [Arsitektur](docs/ARCHITECTURE.md) dan [rencana fase](docs/IMPLEMENTATION_PLAN.md)
- [Format backup dan restore](docs/BACKUP.md), [kebijakan backup platform](docs/BACKUP_PLATFORM_POLICY.md), dan [batasan notifikasi OS](docs/NOTIFICATIONS.md)
