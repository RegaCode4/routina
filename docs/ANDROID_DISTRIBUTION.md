# Distribusi Android melalui APK langsung

Fase 19 · audit 18 November 2026 · baseline `4bb8fed`. **Persiapan teknis tersedia; distribusi publik PENDING.** Kanal yang dikonfirmasi pemilik adalah landing page resmi dengan satu universal signed APK melalui HTTPS. Google Play, AAB, backend, domain, hosting, dan publikasi berada di luar fase ini. Aplikasi tetap offline-first.

## Identitas aplikasi

| Pemeriksaan | Hasil audit dan status |
| --- | --- |
| Nama aplikasi | Manifest menampilkan `Routina`; package Dart `routina`. |
| Android applicationId / namespace | Keduanya `com.example.routina`. **DECISION REQUIRED:** pemilik menentukan ID publik. Tidak diubah pada fase ini. |
| Native package dan bridge | `MainActivity`, `BackupImport`, `LocalReminders`, `ReminderReceiver` berada di `com.example.routina`. Kanal `routina/device_clock`, `routina/device_time_zone`, `routina/notifications`, `routina/backup_storage` konsisten dengan Dart. |
| Ikon | Lima PNG density `ic_launcher` masih ikon template Flutter; hash mdpi identik dengan template SDK. Tidak ada adaptive icon/monochrome resource. **DECISION REQUIRED / OPEN-10:** aset final milik pemilik dan varian adaptive perlu disetujui serta diuji sebelum publikasi. |
| Splash | Native `launch_background.xml` masih background template putih, tanpa aset brand dan konfigurasi khusus Android 12+. Flutter memakai Splash Routina. FigCraft SC-01 (950) diperiksa read-only melalui MCP; nama visual bukan persetujuan ikon final. **PENDING:** splash native final dan validasi perangkat. |
| Versi | `pubspec.yaml`: `1.0.0+1`, versionName `1.0.0`, versionCode `1`. Nomor belum dinaikkan karena tidak ada versi publik/upgrade kompatibel yang diberikan. |
| Toolchain | Baseline Flutter 3.41.2 stable / Dart 3.11.0, AGP 8.11.1, Gradle 8.14, Kotlin 2.2.20, target Java 17. Minimum API 24 (Android 7.0), compile/target API 36. |

Mengubah applicationId menciptakan aplikasi berbeda dengan sandbox baru. Namespace dan package native harus tetap terhubung jika identitas difinalkan. Tentukan jalur ekspor/restore terenkripsi untuk pengguna build percobaan sebelum mengganti ID. APK debug dengan sertifikat berbeda tidak dapat ditimpa APK produksi. Jangan menyarankan uninstall karena menghapus data internal. [Identitas aplikasi Android](https://developer.android.com/build/configure-app-module#set-application-id)

## Pipeline build dan pemeriksaan

Konfigurasi [release signing](ANDROID_SIGNING.md) menerima satu sumber kredensial lengkap, menolak alias debug standar, dan gagal jika release tanpa signing. Tidak ada key produksi dibuat. Build unsigned hanya dibuka melalui opsi audit yang eksplisit.

Jalankan dari root pada PowerShell, dengan JDK dan Android SDK di lingkungan build:

```powershell
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test integration_test test_driver
flutter analyze
flutter test --concurrency=1

# Audit lokal saat key pemilik belum tersedia; BUKAN artefak publik.
./tool/prepare_android_apk.ps1 -AndroidSdk C:/Android/Sdk -AuditUnsigned

# Setelah identitas publik dan key tersedia, isi nilai dari register pemilik:
./tool/prepare_android_apk.ps1 -AndroidSdk C:/Android/Sdk `
  -ExpectedApplicationId '<ID-publik-disetujui>' `
  -ExpectedCertificateSha256 '<64-hex-sertifikat-pemilik-tanpa-titik-dua>' `
  -PreviousVersionCode <kode-versi-publik-sebelumnya>
```

Gunakan `PreviousVersionCode 0` hanya untuk rilis publik pertama. Untuk update naikkan `pubspec.yaml` atau version code build secara terkontrol sebelum pipeline. Pipeline memakai `flutter build apk --release`, tanpa `--split-per-abi`, tanpa target pengujian/preview dan dengan regenerasi registrasi plugin release. [Panduan build Flutter](https://docs.flutter.dev/deployment/android#build-an-apk)

Output build Flutter: `build/app/outputs/flutter-apk/app-release.apk`. Setelah seluruh pemeriksaan berhasil, pipeline menyalin ke `build/distribution/audit-unsigned/` atau `build/distribution/signed-candidate/`, dilengkapi JSON metadata, `.sha256`, badging, manifest/XML backup, signature dan alignment. Output tidak terlacak Git. Label `signed-candidate` masih memerlukan checklist publikasi.

Gerbang otomatis memeriksa package yang diharapkan, version code yang meningkat, sertifikat pemilik, minimum/target SDK, ketiga ABI (`armeabi-v7a`, `arm64-v8a`, `x86_64`), larangan INTERNET/debuggable, `allowBackup=false`, `zipalign -c -P 16 -v 4`, dan seluruh segmen ELF64 LOAD dalam library arm64/x86_64 minimal 16 KiB. Pemeriksaan statis bukan pengujian runtime perangkat 16 KiB. Manifest lengkap, komponen exported dan kedua aturan backup tetap perlu ditinjau untuk setiap versi. [16 KiB Android](https://developer.android.com/guide/practices/page-sizes)

## Audit keamanan platform

- Manifest sumber hanya meminta `POST_NOTIFICATIONS` dan `RECEIVE_BOOT_COMPLETED`. Debug/profile meminta INTERNET untuk alat pengembangan. Manifest release gabungan harus diperiksa agar tidak ada akses jaringan tak diperlukan atau izin tambahan dari plugin.
- APK audit Fase 19 juga memuat izin signature internal `${applicationId}.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` dari AndroidX. `ShareFileProvider`, receiver Share Plus dan `InitializationProvider` tidak exported. Receiver `androidx.profileinstaller.ProfileInstallReceiver` exported dengan pengamanan permission sistem `android.permission.DUMP`; ia bukan komponen yang bebas dipanggil aplikasi biasa. XML Share Plus hanya menunjuk `cache/share_plus/`, tanpa root/external path luas. [Permission DUMP Android](https://developer.android.com/reference/android/Manifest.permission#DUMP)
- `MainActivity` exported untuk launcher; `ReminderReceiver` tidak exported dan menerima boot, penggantian paket, perubahan jam/zona. Alarm dan tautan notifikasi memakai intent eksplisit dan immutable. Tidak ada installer/update otomatis atau izin `REQUEST_INSTALL_PACKAGES` pada aplikasi.
- SQLite berada di sandbox aplikasi; bukan database terenkripsi. Isi planner dapat dibaca pada perangkat yang perlindungannya telah dikompromikan. Android menolak backup OS dengan `allowBackup=false` serta XML pengecualian cloud/device transfer. [Kebijakan backup](BACKUP_PLATFORM_POLICY.md) tetap berlaku; transfer OEM/fisik belum teruji.
- Impor memakai Storage Access Framework, pilihan pengguna dan pembacaan maksimal 32 MiB; ekspor/Share Sheet membawa ciphertext. Tidak ada permintaan izin storage luas dari kode aplikasi. Native bridges mempertahankan kanal lama dan tidak menambahkan akses jaringan.
- Pencarian kode produksi tidak menemukan `print`, `debugPrint`, Android `Log.*`, HTTP client atau socket aplikasi. Pelaporan exception Flutter tetap ada; operator tidak boleh mengunggah diagnostik yang berisi data pribadi. Ini audit kode/artefak lokal, bukan penetration test atau jaminan absennya setiap rahasia historis.
- [Backup v1](BACKUP.md), OPEN-05/06/08/10/11/12 dan seluruh blocker pada [kesiapan rilis](RELEASE_READINESS.md) dipertahankan.

## Upgrade manual dan integritas data

Kontrak update adalah applicationId yang sama, sertifikat kompatibel dan versionCode lebih tinggi. Lokasi SQLite tidak diubah pada fase ini. Skema lokal tetap **10**, skema pertukaran backup v1 tetap **9**; ekspor timer aktif menjadi jeda. Migrasi terdahulu dan reopen diperiksa oleh suite host/native. Kelulusan itu tidak membuktikan upgrade APK Android.

**PENDING upgrade APK:** belum ada pasangan APK lama/baru dengan signing identity pemilik yang kompatibel. APK release lama yang tersedia unsigned dan APK debug memakai identitas debug. Tidak mengklaim upgrade in-place berhasil.

Checklist berikut wajib pada emulator terisolasi dan perangkat fisik sebelum update publik:

- [ ] Arsipkan APK lama, checksum, fingerprint, package, code/name dan bukti pemasangan. Cocokkan signature kedua APK dan pastikan versionCode baru lebih besar.
- [ ] Pasang APK lama. Buat data sintetis melalui UI: profil/preferensi, kategori, kegiatan berulang beserta exception/lintas hari/hasil, tugas/subtugas/sesi/aktual, rutinitas/progres/timer aktif, riwayat, Trash dan pengingat dengan izin/Jam Tenang. Catat ID, relasi, jumlah, status, jadwal dan durasi.
- [ ] Ekspor backup v1 sebelum update ke lokasi di luar sandbox, simpan password secara terpisah dan verifikasi file dapat dibuka pada alur review tanpa mutasi. Jangan mengandalkan backup OS.
- [ ] Hentikan aplikasi secara wajar, pertahankan data, lalu pasang APK baru melalui installer Android sebagai **update**. Untuk uji teknis gunakan `adb install -r <apk-baru>` tanpa `-d`; jangan uninstall, clear data, atau memakai opsi pelonggaran signature/version.
- [ ] Cold start dan cocokkan seluruh data/ID/relasi termasuk WAL yang sudah diproses, skema 10, recurrence, KPI, histori dan Trash. Periksa timer aktif/jeda/hentikan dan log tunggal; target tetap memerlukan status eksplisit. Ukur durasi terhadap jam pembanding.
- [ ] Verifikasi `MY_PACKAGE_REPLACED` dan rekonsiliasi saat buka kembali, izin/kanal, alarm tidak ganda, Jam Tenang, notifikasi nyata serta akses SQLite. Ulangi saat proses direkreasi dan perangkat reboot sesuai [QA perangkat](ANDROID_DEVICE_QA.md).
- [ ] Buka backup v1 lama, tinjau restore pada instalasi uji terpisah dan verifikasi ekspor/restore baru. Periksa kegagalan migrasi tetap menjaga data lama; jangan downgrade database produksi.
- [ ] Catat model/API, versi kedua APK, fingerprint/checksum, hasil tiap baris, waktu dan bukti tanpa data pribadi. Jika installer menolak update, berhenti dan periksa ID/key/code; jangan menghapus aplikasi pengguna sebagai solusi.

Pemulihan kegagalan rilis memerlukan investigasi dan build perbaikan dengan code lebih tinggi serta key sama. Backup planner dapat dipulihkan setelah review eksplisit; backup tidak membuat downgrade skema atau pergantian sertifikat menjadi kompatibel.

## Gerbang publikasi

- [ ] ID publik, ikon/adaptive icon/splash disetujui; identitas contoh dihilangkan dengan rencana data lokal.
- [ ] Key pemilik, backup key teruji, sertifikat tercatat dan signed universal APK diverifikasi.
- [ ] Upgrade APK, runtime 16 KiB, minimum API 24 dan matriks perangkat fisik dituntaskan.
- [ ] Keputusan OPEN dan blocker Fase 15–18 yang berlaku pada rilis ditutup dengan bukti; iOS tetap dilacak PENDING tersendiri.
- [ ] Cakupan verification diperiksa ulang sebelum publikasi; jika diwajibkan untuk kanal/perangkat target, konfirmasi bukti `Registered` melalui konsol resmi. [Persyaratan website](LANDING_PAGE_DISTRIBUTION.md), kebijakan privasi, kontak dan metadata rilis nyata disetujui.
- [ ] Semua uji dan checksum artefak final dicatat; belum ada upload website pada Fase 19.

Lihat [status Android Developer Verification](ANDROID_DEVELOPER_VERIFICATION.md) dan hasil aktual Fase 19 pada [kesiapan rilis](RELEASE_READINESS.md).
