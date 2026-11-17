# Kebijakan backup perangkat Routina

Isi planner ditulis ke SQLite lokal. Backup manual memakai file v1 terenkripsi. Kebijakan platform berikut mengatur penyimpanan internal dan salinan sementara. File yang sengaja disimpan pengguna mengikuti kebijakan lokasi tujuan.

| Area | Android | iOS |
| --- | --- | --- |
| SQLite utama dan sidecar | `sqflite_android` memakai direktori database internal aplikasi. Manifest menetapkan `allowBackup=false`. `fullBackupContent` mengecualikan domain aplikasi pada API 24–30. `dataExtractionRules` mengecualikan domain aplikasi pada cloud backup dan transfer perangkat API 31+. | Database baru berada di `Library/Application Support/RoutinaPlanner/routina.db`. Routina menetapkan `isExcludedFromBackup` pada direktori itu sebelum SQLite membukanya, termasuk untuk sidecar di dalamnya. |
| Upgrade database | Lokasi Android mengikuti jalur internal sebelumnya. | Database lama `Documents/routina.db` dipindahkan hanya ketika tidak ada sidecar SQLite. Bila ada sidecar, aplikasi mempertahankan jalur lama, memberi penanda pengecualian pada database beserta sidecar yang ada, dan membiarkan SQLite membukanya. Jalur dapat dievaluasi kembali ketika aplikasi dibuka ulang. Dua database sekaligus, sidecar tanpa database, atau kegagalan akses memunculkan error penyimpanan agar aplikasi tidak membuka dataset kosong secara diam-diam. |
| Profil dan pengingat | Preferensi pengguna ada di SQLite. SharedPreferences untuk keadaan pengingat perangkat tercakup oleh aturan pengecualian. | Preferensi pengguna dalam SQLite mengikuti kebijakan direktori planner. `UserDefaults` untuk antrean pengingat dan Jam Tenang masih mengikuti kebijakan backup iOS. Antrean berisi ID dan waktu pengiriman, tanpa password. |
| Impor | Storage Access Framework membuka dokumen yang dipilih pengguna. Adaptor memeriksa ukuran yang diketahui dan membatasi jumlah byte yang dibaca. Routina tidak membuat salinan input di cache. | Document Picker membuka URL dari penyedia dokumen. `NSFileCoordinator` dan akses URL security-scoped membatasi pembacaan hingga 32 MiB. Implementasi aplikasi tidak membuat salinan input di `Documents`, cache, atau temp. |
| Ekspor dan Share Sheet | `file_picker` untuk penyimpanan dan `share_plus` untuk berbagi menerima byte yang sudah terenkripsi. Library, OS, dan aplikasi tujuan dapat membuat salinan ciphertext. | Operasi ekspor mengirim ciphertext ke pemilih tujuan atau Share Sheet. Routina mengecualikan direktori planner dan berkas internal legacy yang dikenal. File yang dipilih pengguna di Files atau iCloud Drive mengikuti kebijakan penyedia. |

Android mengatur cloud backup dan transfer perangkat secara terpisah karena `allowBackup=false` saja dapat diperlakukan berbeda pada transfer perangkat oleh sebagian produsen. Cache internal dirancang untuk data sementara. File yang dipilih melalui penyedia bisa memerlukan pengambilan data oleh penyedia sebelum stream tersedia. [Android Auto Backup](https://developer.android.com/identity/data/autobackup) · [Storage Access Framework](https://developer.android.com/training/data-storage/shared/documents-files)

Pada iOS, direktori `tmp` dan `Library/Caches` bersifat sementara dan dapat dibersihkan oleh OS. Apple mendeskripsikan `isExcludedFromBackup` sebagai petunjuk kepada sistem. Kebenaran migrasi, pemulihan setelah interupsi, dan perilaku iCloud Backup atau transfer perangkat harus diverifikasi di perangkat. Snapshot OS lama yang telah dibuat berada di bawah retensi layanan masing-masing. [Dokumentasi penyimpanan Apple](https://developer.apple.com/documentation/foundation/using-the-file-system-effectively) · [Panduan iCloud Backup](https://developer.apple.com/documentation/foundation/optimizing-your-app-s-data-for-icloud-backup)

Runner iOS tidak mendeklarasikan entitlement iCloud/CloudKit atau `UIFileSharingEnabled` dalam konfigurasi repo. Akses Files dan Share Sheet memakai penyedia sistem, sedangkan backup perangkat mengikuti kebijakan penyimpanan dan penanda direktori. Penyedia cloud mengendalikan cache di luar direktori aplikasi.

## Gerbang perangkat

- Android. Manifest APK debug dan kedua aturan XML diverifikasi. Paket mendapat hasil `Backup is not allowed` ketika Backup Manager aktif dan memakai LocalTransport pada emulator API 36 offline. Pemilih dokumen menerima fixture v1, menolak 33.554.433 byte, dan menangani pembatalan. Transfer OEM, API 24–30, dan penyedia cloud memerlukan perangkat tambahan.
- **PENDING iOS.** Uji fresh install, upgrade database lama dengan dan tanpa WAL/journal, kegagalan relokasi, dan kondisi dua database. Verifikasi penanda pengecualian di perangkat dan keberlangsungan data setelah upgrade. Uji ekspor dan impor lewat Files/iCloud Drive serta Share Sheet. Lakukan pertukaran file yang sama Android → iOS dan iOS → Android. Host Fase 17 memakai Windows.

### Mengulang uji Android

Jalankan tes native SQLite dengan `flutter test integration_test/backup_integrity_test.dart -d <device-id>`. Tes menggunakan database sintetis sementara.

Untuk uji pemilih Android, isi Downloads emulator dengan `routina-v1-test.routina` dari byte hasil dekode Base64 konstanta `legacyV1` di `test/support/backup_vectors.dart`, serta `routina-oversize-test.routina` berukuran 33.554.433 byte. Jalankan perintah berikut. Pilih file v1, pilih file berukuran besar pada dialog kedua, lalu batalkan dialog ketiga.

```sh
flutter drive --driver=test_driver/offline_journey_driver.dart --target=integration_test/backup_integrity_test.dart -d <device-id> --dart-define=ROUTINA_SYSTEM_BACKUP_PICKER=true
```
