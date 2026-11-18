# QA branding dan identitas · Fase 20A

18 November 2026. **COMPLETE untuk lingkup Fase 20A**, dengan batas verifikasi di bawah. Persetujuan pemilik diberikan secara eksplisit melalui jawaban **“Setujui seluruh paket branding”** setelah review ikon, adaptive mask, Ember dan splash ditampilkan. Signing produksi, release candidate, publikasi dan Fase 20B tidak dijalankan.

## Identitas, sumber dan integrasi

| Area | Hasil |
| --- | --- |
| ApplicationId / namespace | `com.regacode.routina` pada Gradle, package Kotlin, MainActivity, backup/import dan receiver. |
| Manifest APK aktual | MainActivity/ReminderReceiver berada pada package final; authority Share Plus `com.regacode.routina.flutter.share_provider` dan AndroidX Startup `com.regacode.routina.androidx-startup`. |
| Kanal native | Nama `routina/device_clock`, `routina/device_time_zone`, `routina/notifications` dan `routina/backup_storage` dipertahankan. |
| Sumber desain | [Personal Planner - Flutter UI Design.figcraft](../Personal%20Planner%20-%20Flutter%20UI%20Design.figcraft), halaman 12, 18 frame branding. Frame SC-01–SC-30 tidak diubah. |
| Ikon | `BRAND_Icon_Final` (14762), adaptive foreground/background (14771/14774), monochrome (14791). Lima PNG legacy diekspor langsung pada 48/72/96/144/192 px. |
| Splash | `BRAND_Splash_Final` (14756) dan aset native `BRAND_Splash_Android12_Icon` (14821). Ember #EE613E, cream #F5F2E9, ink #171717, tanpa wordmark. |
| Metode | SVG FigCraft menjadi VectorDrawable melalui [generator](../tool/prepare_android_branding.ps1); adaptive XML API 26/33; splash layer-list API 24–30 dan SplashScreen API 31+. Flutter memakai PNG alpha dari frame native yang sama. |
| First frame | PNG dipramuat sebelum frame pertama dilepas. Tidak ada timer tambahan. State loading semantik, Mulai/Lanjutkan, retry dan logika onboarding tetap tersedia. |
| Dependency / iOS | Tidak ada package baru dan pubspec.lock tidak berubah. Bundle identifier iOS tidak diubah; native iOS belum diuji. |

[Sumber, inventory lengkap dan lokasi aset](BRANDING.md) · [Manifest ekspor](../design/branding/manifest.json) · [Panduan perpindahan data lintas ID](BRANDING.md#pergantian-identitas-dan-data-uji).

## Pengujian yang teramati

| Pemeriksaan | Hasil dan cakupan |
| --- | --- |
| Format Dart | 10 file Dart yang berubah/terkait diperiksa; hasil akhir tidak mengubah format lagi. |
| Flutter analyze | `flutter analyze --no-pub` bersih setelah perubahan akhir. |
| Unit/widget | **164 tes lulus** pada run akhir dengan concurrency 1. Termasuk 13 tes widget terarah, loading/error/retry, posisi mark, tanpa wordmark dan startup 320 dp/200%. |
| Offline journey | **Lulus**: onboarding, profil/jam aktif, Quick Add → Form Lengkap, simpan tugas SQLite, buka ulang, Home dan Statistik dari dua entry point. |
| Search | **Lulus**: filter Kalender dan Rutinitas pada SQLite native. |
| Lifecycle | **Lulus**: bridge clock Android, timer, perubahan waktu/zona simulasi, reopen SQLite dan log tunggal. |
| Backup integritas | **Lulus**: fixture v1, input rusak, rollback kegagalan tulis, restore, ekspor ulang dan Merge berulang. |
| Pemilih dokumen | **Lulus**: fixture valid 1.455 byte dibaca oleh bridge Android, input 32 MiB + 1 byte ditolak, pembatalan menghasilkan null. File dipilih melalui UI DocumentsUI aktual. |
| Identity/receiver | **Lulus**: path database berada dalam sandbox ID baru, clock dan zona native merespons, permission/sync bekerja, receiver menandai pengiriman. NotificationManager mencatat notifikasi sintetis dengan tag `f20a-native-identity`, package `com.regacode.routina`, kanal `planner_reminders`, judul `Routina F20A`. |
| Build/run | APK **debug**, entry point `lib/main.dart`, berhasil dibangun dan dipasang pada Android 16/API 36 x86_64. Tidak ada build release/RC. |

Jumlah integrasi adalah **enam skenario pada lima file**, tidak menghitung callback teardown sebagai tes tambahan:

- `offline_journey_test.dart`
- `activity_search_test.dart`
- `device_lifecycle_test.dart`
- `backup_integrity_test.dart` (dua skenario, termasuk opsi system picker)
- `application_identity_test.dart` (opsi native reminder probe)

Probe notifikasi memerlukan izin pada aplikasi uji yang sudah terpasang. Saat menjalankannya, berikan `adb -s emulator-5556 shell pm grant com.regacode.routina android.permission.POST_NOTIFICATIONS` setelah pemasangan APK; probe menunggu izin sampai 30 detik. Waktu tunggu pengamatan notifikasi hanya ada pada integration test.

Harness startup kini menunggu semantik loading selesai karena splash statis tidak lagi menyediakan animasi yang dapat ditunggu oleh `pumpAndSettle`. Perubahan ini menangani load dan relaunch SQLite; aplikasi tidak ditambah animasi atau delay untuk memenuhi harness.

## Verifikasi visual aktual

Perangkat uji memakai **1080×2400, density 420**, Android API 36. Render dibandingkan dengan frame FigCraft serta geometri asetnya.

| Area visual | Observasi |
| --- | --- |
| Launcher circle | R terlihat utuh, counter terbuka, outline dan shadow tetap terbaca. Latar Ember penuh tanpa radius yang dibakar ke sumber. Screenshot app drawer dipakai agar ring “predicted app” launcher tidak dianggap bagian ikon. |
| Native → Flutter | Latar sampel adalah **#EE613E**. Pusat mark pada perbandingan pixel sampel sama, sekitar **(539,5; 1199,5)**. Tepi vector/native dan PNG/Flutter berbeda sekitar 1 px karena rasterisasi. |
| Proporsi dan margin | Mark mempertahankan proporsi, outline, shadow kiri bawah dan ruang kosong sesuai aset FigCraft. Viewport splash 288 dp dipakai bersama. |
| Startup siap | Flutter mempertahankan mark terpusat; tombol Mulai muncul saat data siap, sesuai gate first-run yang sudah ada. Splash tidak menambahkan wordmark. |
| Onboarding/Home | Layar onboarding dan Home aktual tersedia pada bukti. Alur profil tersimpan dan reload diuji oleh integrasi. |
| Batas kesetaraan | Kesetaraan inti mark/latar/posisi diverifikasi lewat render aktual. Status/navigation bar dikelola OS, ukuran viewport berbeda dari artboard, dan state siap Flutter menampilkan aksi. Tidak ada klaim pixel-perfect seluruh layar. |

Bukti screenshot yang disimpan di repo:

- [Launcher circle](../design/branding/qa/android36-launcher-circle.png)
- [Native splash Android 12+](../design/branding/qa/android36-native-splash.png)
- [Flutter startup](../design/branding/qa/android36-flutter-startup.png)
- [Onboarding](../design/branding/qa/android36-onboarding.png)
- [Home dengan data sintetis](../design/branding/qa/android36-home.png)
- [Pemilih backup Android](../design/branding/qa/android36-backup-picker.png)

## Lingkungan, hambatan dan batas verifikasi

- Emulator awal `emulator-5554` memiliki sekitar 454 MiB kosong dan menolak pemasangan ulang. Pemangkasan cache tidak cukup. Pengujian diteruskan pada AVD **Routina_F20A_API36**, `emulator-5556`, di `build/artifacts/f20a/avds`, dengan sekitar 4,8 GiB kosong. Data aplikasi pada emulator lama dipertahankan; Wi-Fi/data lamanya dipulihkan ke nilai awal 1 sebelum ditutup secara normal untuk mengurangi beban RAM host 8 GB. Pada pemeriksaan akhir setelah pekerjaan dilanjutkan, ADB tidak melaporkan emulator aktif; tidak ada perangkat lain yang dihentikan oleh langkah cleanup.
- AVD terisolasi menjalankan integrasi dengan Wi-Fi/data seluler 0 dan tanpa rute default. Semua fixture sintetis ditempatkan pada Downloads/Routina-F20A.
- Build debug awal tertahan mengunduh ABI tambahan; build pengujian dibatasi ke target x86_64 yang tersedia. Konfigurasi distribusi universal tidak diubah.
- Cold start debug yang direkam pada AVD terisolasi melaporkan 11.402 ms; pengulangan berikutnya 6.220 ms. Host memakai RAM terbatas dan renderer software. Angka ini merupakan observasi debug, bukan benchmark release atau perangkat fisik. Source tidak menambahkan minimum durasi splash.
- Circle diverifikasi pada launcher. Rounded square/squircle diperiksa lewat preview FigCraft dan geometri safe zone; kontrol mask tambahan tidak tersedia pada overlay emulator yang diperiksa. Render themed/monochrome pada launcher belum diverifikasi. Resource monochrome API 33 sudah terpasang dan dikompilasi.
- Runtime API 24–30, Android fisik, mask OEM lain, themed icon, TalkBack, secure lock screen dan native iOS tetap **MANUAL PENDING**.
- Eksplorasi transisi ke onboarding lama pada 320 dp/200% menunjukkan RenderFlex overflow. Layout/logika onboarding tersebut tidak diubah pada Fase 20A; temuan dicatat untuk hardening terpisah. State startup/error/retry yang berubah pada fase ini lulus uji ukuran tersebut.
- Pengujian fixture backup v1 pada ID baru tidak membuktikan upgrade in-place signed APK atau pemindahan otomatis data pengguna dari ID lama. Ikuti panduan ekspor/restore dengan review eksplisit.

Log, rekaman cold start dan output build berada pada `build/artifacts/f20a` yang diabaikan Git. Screenshot terpilih di atas adalah artefak QA sintetis. Key, secrets, APK dan image AVD tidak masuk commit. Gerbang publikasi tetap mengikuti [RELEASE_READINESS.md](RELEASE_READINESS.md).
