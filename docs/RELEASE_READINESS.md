# Kesiapan rilis Routina · Fase 15–19

**Belum siap untuk distribusi publik.** Kanal Android Fase 19 adalah universal signed APK dari landing page resmi, dengan update manual; Google Play/AAB bukan target fase ini. Audit menggunakan [PRD](../PRD.md), [DESIGN](../DESIGN.md), [referensi FigCraft](FIGCRAFT_SCREEN_MAP.md), dan [rencana fase](IMPLEMENTATION_PLAN.md). Status “Ada” menunjukkan jalur produksi yang terhubung ke data lokal. Batas verifikasi perangkat dicatat terpisah.

## Cakupan FR

| FR | Status implementasi dan bukti |
| --- | --- |
| FR-01 Home dan KPI | Ada. Home membaca ringkasan SQLite dari domain produktivitas. Lima KPI, agenda, kewajiban terhubung, hasil Ditunda/Dilewatkan, hari kosong, serta antrean konfirmasi tercakup di `productivity_test` dan `widget_test`. |
| FR-02 Kalender | Ada. `PlannerCalendar` memuat hari, minggu, bulan, event lintas hari, deadline, sesi kerja, dan blok rutin. `activity_calendar_test`, `task_workspace_test`, dan `routine_workspace_test` menguji sumber data kalender. |
| FR-03 Kegiatan dan recurrence | Ada. `EventEditor` dan `ActivityCalendar` mendukung Quick Add, draft, field lengkap, recurrence, exception dan split, all-day Sibuk/Tersedia, bentrok dan buffer. `activity_calendar_test` serta `widget_test` meliputi scope, lintas hari dan warning. |
| FR-04 Status dan pengganti | Ada. `EventDetail` dan Home menawarkan konfirmasi eksplisit dan pengganti manual/slot. Catatan lama bertahan. `activity_calendar_test`, `smart_scheduling_test` dan `local_reminders_test` meliputi histori, review pengganti dan pengingat. |
| FR-05 Tugas dan subtugas | Ada. Checklist, siklus tugas, tenggat, sesi rencana dan durasi aktual terpisah. Input aktual manual tersedia. `task_workspace_test` dan `task_screens_test` mencakup konfirmasi tugas dan sesi mendatang. Pilihan timer untuk sesi tugas masih OPEN. |
| FR-06 Rutinitas dan timer | Ada. Empat bentuk target, timer dan input manual. Fase 18 menyimpan acuan jam monotonik Android dalam satu boot dan menguji pemulihan, loncatan jam, Jeda/Lanjut/Hentikan, log tunggal, dan status eksplisit. Verifikasi lock screen aman dan kebijakan pemulihan lintas boot tetap terbuka. [Matriks perangkat](ANDROID_DEVICE_QA.md) |
| FR-07 Smart Scheduling | Ada. `SchedulingEngine` dan `SmartScheduling` menerapkan slot tunggal/split, batas sesi, preferensi, buffer, zona, review, stale dan persetujuan atomik. Uji engine, workspace, dan layar meliputi bentrok, scope dan selisih sisa durasi. |
| FR-08 Notifikasi | Ada. Home dan Pengaturan mencakup izin, Jam Tenang, snooze dan fallback. Fase 18 memperkuat pemulihan antrean Android dan mengecek ulang izin saat alarm tiba. Suite host menguji perubahan izin, zonasi dan rekonsiliasi. Pengiriman Android tetap bergantung pada OS dan pengujian native iOS masih PENDING. [Batas OS](NOTIFICATIONS.md) |
| FR-09 Kategori, pencarian dan filter | **COMPLETE (Fase 16).** CRUD kategori dan pemindahan referensi teruji. Pencarian judul, filter gabungan, pengurutan yang relevan, dan state kosong tersedia di Tugas, Kalender, dan Rutinitas pada jalur SQLite produksi. |
| FR-10 Statistik | Ada. `ProductivityStatistics` membaca data lokal dari Home dan Profil. Uji menghitung dua rasio, periode kosong, pembanding setara/otomatis/manual dan riwayat. |
| FR-11 Zona dan awal minggu | Ada. `CalendarZones` menerapkan waktu lokal/instant ke kalender, recurrence, tenggat, rutin, statistik dan scheduler. Pengujian mencakup DST dengan jam berulang/hilang dan hitung ulang minggu tanpa mutasi histori. Refresh OS, termasuk pengingat ketika zona perangkat berubah, perlu validasi perangkat lintas OS. |
| FR-12 Tempat Sampah | Ada. Soft-delete, retensi, restore dengan cek relasi/kategori/bentrok dan penghapusan permanen eksplisit teruji di `trash_workspace_test` dan `trash_screens_test`. Jadwal purge otomatis dan kebijakan statistik setelah purge masih OPEN. |
| FR-13 Backup dan restore | Ada. Fase 17 mempertahankan format v1 dan memperkuat batas input, integritas profil, status Trash dan Merge berulang. Rollback SQLite, restore v1, dan pemilih dokumen diuji pada Android. Verifikasi iOS serta pertukaran native antarplatform masih PENDING. [Format dan transaksi](BACKUP.md) |


## Cakupan layar SC-01–SC-30

Metadata satu frame 390×844 per kelompok diperiksa melalui FigCraft MCP. Entri mencatat jalur produksi dan varian yang ditinjau di kode atau tes. Peta FigCraft memuat indeks seluruh 315 artboard. Artefak desain tetap utuh.

| SC · ID FigCraft | Jalur Flutter dan state |
| --- | --- |
| SC-01 · 950 | `PlannerStartup`. Splash, pengguna kembali, loading dan retry error. |
| SC-02 · 1008 | `PlannerOnboarding`. Tiga langkah dan resume yang disimpan. |
| SC-03 · 1287 | Penyiapan profil, tujuh hari jam aktif, validasi, sukses dan izin opsional. |
| SC-04 · 175 | `PlannerHome`. KPI, kosong, loading, error, agenda, konfirmasi dan fallback pengingat. |
| SC-05 · 1535 | `PlannerCalendar` bulanan. Tanggal, all-day, lintas hari, daftar aktivitas, dan pencarian/filter. |
| SC-06 · 1695 | Kalender mingguan. Zona tampilan, rentang minggu, blok bertumpuk, dan pencarian/filter. |
| SC-07 · 1792 | Kalender harian. Linimasa, deadline, all-day, blok di luar jam aktif, pencarian/filter, loading dan kosong. |
| SC-08 · 3996 | `EventDetail`. Status temporal/hasil, edit, hapus, scope dan pengganti. Pemulihan melalui Tempat Sampah. |
| SC-09 · 4033 | `EventEditor` Quick Add. Field wajib, validasi waktu dan konfirmasi warning. |
| SC-10 · 4069 | Form Lengkap `EventEditor`. Draft, zona, recurrence, all-day dan reminder multipel. |
| SC-11 · 5428 | `TaskList`. Cari, filter, urut, overdue, kosong, hasil kosong dan retry. |
| SC-12 · 5495 | `TaskDetail`. Checklist, rencana, aktual, sesi manual, status dan ringkasan sisa. |
| SC-13 · 5550 | `TaskEditor`. Quick Add, form lengkap, draft, zona tenggat dan reminder. |
| SC-14 · 6958 | `RoutineBoard`. Progres, target menunggu status, timer, pencarian/filter, kosong dan histori. |
| SC-15 · 7021 | `RoutineEditor`. Draft, bentuk target, frekuensi dan validasi. |
| SC-16 · 7053 | `RoutineDetail` dan `RoutineHistory`. Timer, pemulihan, status, input manual dan riwayat. |
| SC-17 · 8138 | `SmartSchedulePage`. Review estimasi, tenggat, batas sesi dan kekurangan input. |
| SC-18 · 8181 | Hasil tunggal/split, review, simpan, batal dan stale. |
| SC-19 · 8221 | Penjelasan batasan dan alternatif untuk proposal tanpa solusi. |
| SC-20 · 8265 | Konflik dan scope sesi bentrok atau seluruh sesi mendatang. |
| SC-21 · 8303 | Sisa durasi kurang/lebih/sesuai, tambah/kurangi sesi, optimasi, pertahankan dan review. |
| SC-22 · 9438 | `ProductivityStatistics`. Periode, grafik, pembanding, filter, riwayat, kosong/loading/error dan awal minggu. |
| SC-23 · 10115 | Profil dan pengaturan. Entri Statistik memakai pembaca produksi yang sama dengan Home. |
| SC-24 · 10188 | Editor jam aktif dan waktu pilihan. Tujuh hari dan validasi rentang. |
| SC-25 · 10242 | `NotificationSettings`. Izin, App Settings, fallback, Jam Tenang, pengecualian dan error. |
| SC-26 · 10285 | Kategori. Ikon/warna, kosong, dan pemindahan item saat hapus. |
| SC-27 · 11689 | `BackupScreen`. Status backup, password, enkripsi, pemilih tujuan dan reminder. |
| SC-28 · 11793 | `backup_restore_page.dart`. Pemilih file, sandi, kesalahan, mode, konflik dan persetujuan. |
| SC-29 · 11840 | `TrashScreen`. Daftar/detail, peringatan retensi, konflik dan hapus permanen. |
| SC-30 · 13262 | `NeoBottomSheet` dan dialog alur tambah, status, scope, stale, restore, trash dan izin. |

### Perbandingan visual dan aksesibilitas

- Raster FigCraft ditinjau untuk Home (175, 649), Statistik (9438), Profil (10115), ekspor dengan password (11729), retensi berakhir (13118), dan pemilih tambah (13262). Acuan memakai Bricolage Grotesque untuk label, Space Mono untuk angka, serta outline dan shadow keras pada komponen utama.
- Banner izin Home dan panel keamanan SC-27 memakai kuning dengan ikon di sisi label. Panel retensi SC-29 memakai susunan yang sama dengan koral. Keduanya memakai `NeoCard`, token spasi, outline serta tipografi yang sama, dan dapat membungkus teks.
- Render Android yang diperiksa mencakup Home, Statistik mingguan, Profil, formulir ekspor, dan pemilih Tambah aktivitas. Panel KPI, chip periode, outline, shadow dan palet dasar mengikuti acuan. Profil masih memakai kartu biru muda dengan ikon generik. Form ekspor mengikuti struktur Flutter dengan tombol kembali pada header. Tangkapan layar tersedia di folder build/visual-audit/ setelah menjalankan driver.
- Galeri menguji kontras teks, target sentuh 48 dp, label semantik dan fokus input. Statistik dan scheduling memiliki uji teks besar. TalkBack/VoiceOver, keyboard fisik, landscape, tablet dan semua varian visual belum tercakup.


## Dependency dan konfigurasi platform

- `flutter pub outdated --show-all --json` melaporkan 91 paket terkunci dan nol flag advisory, retracted atau discontinued dalam metadata Pub. Versi utama terkunci mencakup `cryptography` 2.9.0, `file_picker` 11.0.3, `share_plus` 11.1.0, `sqflite` 2.4.2+1, dan `timezone` 0.10.1. Mayor baru file picker dan share perlu evaluasi iOS minimum dan AGP. Audit native serta review kriptografi tetap diperlukan.
- Android memakai AGP 8.11.1, Gradle 8.14, Java target 17, SDK minimum 24 serta compile/target 36. Release memuat data produksi dan sejak Fase 19 mewajibkan signing pemilik melalui file lokal atau environment; unsigned hanya diizinkan untuk audit eksplisit. Manifest mengatur `allowBackup=false`, dengan pengecualian semua domain untuk cloud backup dan device transfer. Pemilih file tetap mendukung ekspor manual. [Android Auto Backup](https://developer.android.com/identity/data/autobackup)
- iOS menargetkan iOS 13.0. Host audit Windows. Build distribusi memerlukan toolchain yang diterima App Store Connect, identitas, dan signing proyek. [Persyaratan Apple](https://developer.apple.com/news/upcoming-requirements/)
- Flutter 3.41.2 masih dapat meregistrasi plugin khusus pengembangan pada iOS. Periksa apakah plugin integrasi masih ikut di build publik saat memvalidasi paket iOS. [Flutter issue 163874](https://github.com/flutter/flutter/issues/163874)
- `sqflite_darwin` memakai Documents sebagai path default. SQLite iOS belum memiliki pengecualian backup OS yang diverifikasi. Perubahan lokasi database perlu migrasi yang mempertahankan data lama beserta jurnal/sidecar dan pengujian rollback pada perangkat. [Dokumentasi backup Apple](https://developer.apple.com/documentation/foundation/optimizing-your-app-s-data-for-icloud-backup)

## Hasil pengujian · Fase 15

- Format Dart seluruh `lib`, `test`, `integration_test`, dan `test_driver`, serta `flutter analyze --no-pub` lulus. Lockfile berhasil diresolusi dengan `flutter pub get --offline --enforce-lockfile`.
- `flutter test --no-pub --concurrency=1 --reporter=expanded` lulus **144 unit/widget test**. Cakupan meliputi recurrence, zona asal/device-local, DST gap dan fold, lintas tengah malam, konflik/buffer, proposal stale, timer lifecycle dengan clock terkontrol, izin palsu/Jam Tenang, dua rasio dan deduplikasi KPI, perubahan awal minggu, retensi, password salah, korupsi dan rollback kegagalan penulisan.
- `flutter drive` lulus **1 tes integrasi** pada Android 16/API 36 x86_64. Wi-Fi dan data seluler mati dan `ip route` kosong. Uji melalui onboarding, profil dan jam aktif tanpa permintaan izin, input dengan keyboard layar, Quick Add ke Form Lengkap, simpan SQLite, buka ulang SQLite, Statistik dari Home dan Profil dengan satu tugas yang sama, serta akses form ekspor. Lima tangkapan layar diperiksa.
- Run awal menemukan selektor tes gulir Android terlalu luas dan asumsi label status yang memakai teks fixture. Keduanya diperbaiki. Assertion semantik banner memakai label yang dapat digabung Flutter dan handle ditutup sebelum verifikasi akhir. Satu run host paralel dihentikan saat worker FFI tertahan. Percobaan Flutter yang tumpang tindih juga mengunci aset SQLite Windows. Run host terakhir dilakukan berurutan dan lulus.
- iOS build dan integrasi belum dijalankan karena macOS/Xcode serta perangkat iOS tidak tersedia. Uji host menjalankan domain Flutter dan SQLite FFI. Hasil itu tidak menguji perilaku iOS native.
- `flutter build apk --release` lulus. Build awal dengan `--no-pub` membaca registrasi plugin Android dari mode debug dan gagal pada referensi `IntegrationTestPlugin`. Build ulang dengan resolusi paket bawaan meregenerasi registrasi untuk mode release.
- APK release berada di `build/app/outputs/flutter-apk/app-release.apk` (63.831.566 byte) dan unsigned sesuai verifikasi `apksigner`. Manifest APK menetapkan minimum API 24 dan target API 36, tanpa izin INTERNET, dengan `allowBackup=false` dan aturan transfer. APK mencakup arm64-v8a, armeabi-v7a, dan x86_64. `zipalign -c -P 16 4` lulus. Seluruh segmen ELF LOAD arm64-v8a dan x86_64 ter-align minimal 16 KiB. Runtime 16 KiB dan AAB bertanda tangan masih perlu diverifikasi.

## Audit FR-09 · Fase 16

| Ketentuan | Implementasi |
| --- | --- |
| Kategori bersama | CRUD nama, ikon, warna, serta pemindahan referensi ke kategori pengganti atau Tanpa Kategori sudah ada. Uji transaksi dan rollback tetap berada di `local_settings_test`. Pencarian Kalender dan Rutinitas memakai ID kategori. |
| Tugas | Pencarian judul, filter tanggal tenggat/kategori/status/prioritas, urut tenggat/prioritas, dan state kosong sudah tersedia pada `TaskList`. |
| Kalender · SC-05–SC-07 | Cari judul di periode hari/minggu/bulan atau persempit ke satu tanggal. Filter kategori dan status mengikuti proyeksi kalender, termasuk Overdue pada penanda tenggat. Sortir waktu awal/akhir berdasarkan instant aktual. Tanggal memakai zona tampilan dan mencakup aktivitas yang melintasi tanggal terpilih. Tutup pencarian untuk kembali ke kalender. |
| Rutinitas · SC-14 | Cari judul, filter kategori dan status dari progres/kejadian yang sudah dipakai oleh kartu. Filter tanggal mencakup kejadian aktif dan rutinitas yang ditargetkan oleh cadence yang berlaku pada tanggal itu. Rutinitas tanpa jam muncul terakhir saat hasil diurutkan menurut jam jadwal. |
| Gabungan dan hasil kosong | Judul dicocokkan tanpa membedakan kapital dan mengabaikan spasi tepi. Filter digabung dengan AND. Pengurutan berlaku pada hasil yang cocok. State kosong menyediakan Bersihkan filter. Item terhapus dikecualikan dari hasil aktif. |

Jalur produksi membaca proyeksi SQLite yang sama dengan kalender dan daftar rutinitas. Filter judul, kategori, status, dan pengurutan bekerja pada data yang telah dibaca. Penentuan cadence dibagi dengan agregasi rutinitas melalui fungsi yang sama. Rumus KPI dan logika Smart Scheduling tetap sama.

- `flutter analyze --no-pub` bersih. Regresi penuh lulus **151 unit/widget test**, termasuk Smart Scheduling, KPI, recurrence, zona waktu dan status. Widget test baru memverifikasi kombinasi filter, empty/reset, dan tampilan 320 dp dengan teks 200%.
- Satu tes integrasi Fase 16 lulus pada Android 16/API 36 menggunakan SQLite native, dengan Wi-Fi dan data seluler mati serta tanpa rute default. Tes mencakup kombinasi filter di Kalender dan Rutinitas, urutan, hasil kosong, pengecualian Tempat Sampah, dan pembukaan detail.
- Tiga tangkapan layar di `build/visual-audit/f16-*.png` diperiksa terhadap kerangka FigCraft SC-05/07 (1535, 1792), SC-14 (6958), dan varian pencarian/filter/kosong SC-11 (6035, 6092, 5929). Field outline, chip aktif kuning, kartu kosong berbayang dan aksi reset memakai token DESIGN. Uji ukuran kecil juga menemukan dan memverifikasi perbaikan tata letak aksi Lihat hari di Kalender bulanan.
- Uji native iOS masih terbuka karena host Windows. Kebijakan nama kategori duplikat tercatat OPEN pada DESIGN SC-26.

## Audit backup dan integritas · Fase 17

| Keparahan | Temuan dan tindakan |
| --- | --- |
| Tinggi | Merge dapat menggabungkan entri Tempat Sampah terpisah untuk target bersama. Backup dapat mengubah visibilitas target meskipun pengguna mempertahankan versi lokal. Review sekarang menolak state Trash yang berbeda untuk ID bersama dan memberi jalur ke tinjauan Ganti Semua. |
| Tinggi | Snapshot yang lolos autentikasi dapat berisi tombstone yang menyembunyikan profil tunggal. Validasi SQLite sekarang memastikan profil tetap terlihat sebelum data aktif dapat diganti. |
| Sedang | Pemilih file sebelumnya bisa menyalin seluruh input sebelum batas Dart diperiksa. Pembaca dokumen native membatasi pembacaan dan menghindari salinan aplikasi. Encoder ekspor juga menerapkan batas byte saat serialisasi. |
| Sedang | Merge berulang dapat menulis ulang snapshot identik dan menghapus progres pengingat. Konfirmasi masih memeriksa snapshot terkini. Penulisan dan rekonsiliasi dilewati jika hasil identik. |
| Tinggi untuk rilis iOS · PENDING | Database sebelumnya di Documents berpotensi ikut backup OS. Implementasi memakai Application Support yang diberi pengecualian dan relokasi konservatif untuk database lama. Build, migrasi native, dan transfer iCloud/perangkat perlu verifikasi macOS dan perangkat. |

- Audit model mencakup seluruh tabel record, relasi bertipe, status dan revisi, signature jadwal, zona/instant/waktu dinding, template/exception recurrence, subtree tugas dan rutinitas, timer, log, snapshot tujuan, serta Trash dan pengaturan. Skema lokal tetap 9. Migrasi lokal 1→9 mempertahankan guard riwayat v2, profil v3, recurrence v4, goal/timer v5, parameter sesi v6, progres pengingat v7, cadence v8 dan metadata Trash v9. Restore menerima file v1 skema 9. Migrasi skema file lain tetap OPEN-05.
- `flutter pub outdated --show-all --json` memeriksa 91 paket terkunci. `cryptography` 2.9.0 dan `crypto` 3.0.8 tidak memiliki flag advisory, retracted, atau discontinued pada metadata Pub yang diperiksa. Keputusan keamanan produk OPEN-11 tetap terbuka. [Kontrak format dan risiko](BACKUP.md)
- APK debug yang diuji memuat ketiga atribut backup Android. XML API 31+ memuat cloud dan device transfer, serta XML legacy mengecualikan domain database dan SharedPreferences. Dengan Backup Manager aktif dan transport lokal, hasil untuk paket Routina adalah `Backup is not allowed` pada emulator API 36. Uji transfer OEM dan API 24–30 secara fisik masih terbuka. [Kebijakan perangkat](BACKUP_PLATFORM_POLICY.md)
- Native Android offline menguji fixture v1, modifikasi tag, rollback saat penulisan sengaja digagalkan, restore sukses, ekspor ulang dan Merge berulang. Pemilih Android membaca file valid, menolak file 32 MiB + 1 byte, dan menangani pembatalan. Fault penulisan diuji melalui trigger SQLite. Kondisi perangkat benar-benar kehabisan ruang belum disimulasikan.
- Format Dart dan `flutter analyze --no-pub` lulus. `flutter test --no-pub --concurrency=1 --reporter=expanded` lulus **158 unit/widget test**. Terdapat 20 tes terarah backup dan 2 skenario integrasi Android. Regresi Kalender, Tugas, Rutinitas, Smart Scheduling, dan Statistik lulus. Tiga fixture independen dapat dihasilkan kembali byte-for-byte.
- **PENDING Android ↔ iOS.** Vektor independen dan pengujian Dart memverifikasi format portable. macOS, Xcode, perangkat iOS, serta transfer silang native tidak tersedia pada host ini.

## Lifecycle, notifikasi, dan aksesibilitas · Fase 18

- Timer Android menyimpan acuan boot dan jam monotonik bersama timer aktif. Pengujian mencakup loncatan jam, pergantian tanggal/zona, pemulihan, akumulasi Jeda/Lanjut/Hentikan, dan log tunggal. Target tetap meminta konfirmasi. Skema SQLite lokal 10 menambah metadata tersebut. Skema pertukaran v1 tetap 9 dan timer aktif diekspor sebagai timer yang dijeda.
- Receiver Android memulihkan pengingat valid setelah interupsi pemasangan alarm. Pencabutan izin diperiksa saat pengiriman. Estimasi target timer yang stale diblokir sampai dihitung ulang, dan alarm yang datang terlalu awal diperiksa untuk pemasangan kembali.
- Metadata dan struktur satu frame per kelompok SC-01 sampai SC-30 diperiksa kembali lewat FigCraft, termasuk varian Timer dan Notifikasi. Pengujian 320 dp/200% menjalankan tab produksi dan detail timer. Durasi memiliki nilai semantik dalam jam, menit dan detik. Status timer memakai live region. Uji galeri, form, dialog, search/filter, Statistik dan modal Trash menambah sampel komponen dan state.
- Format Dart dan `flutter analyze --no-pub` lulus. Suite host lulus **117 unit dan 45 widget test**, termasuk regresi Kalender, To-Do, Rutinitas, Smart Scheduling, Statistik/KPI, Backup, Search dan Tempat Sampah. Widget test To-Do diulang setelah harness diperbaiki untuk menghindari lock akibat antrean frame.
- Emulator Android API 36 memverifikasi pergantian zona yang melintasi tanggal, perubahan jam, rekreasi proses, sleep/wake, swipe dari recent apps, force-stop/relaunch, rearm sesudah reboot, dan integritas SQLite. Izin diminta melalui tindakan eksplisit dan dapat diubah melalui Settings. Jam Tenang dan pengecualian mengubah antrean native. Android mencatat pengiriman kegiatan, tenggat dan backup. [Hasil perangkat dan batas pengujian](ANDROID_DEVICE_QA.md)
- Empat tes integrasi Android lulus melalui alur offline, pencarian/filter, backup dan rollback, serta timer dengan clock Android dan pembukaan ulang SQLite. APK debug berhasil dibangun dan dipasang.
- Perangkat fisik Android, lock screen aman, TalkBack, dan keyboard fisik tetap **MANUAL PENDING**. iOS native dan VoiceOver tetap **PENDING**. Kebijakan pemulihan durasi ketika perangkat mati tetap OPEN-08 dan kebijakan nama kategori duplikat tetap OPEN-03. [Matriks bukti dan checklist perangkat](ANDROID_DEVICE_QA.md)

## Persiapan distribusi APK langsung · Fase 19

Audit dimulai dari `4bb8fed` pada `main`, working tree bersih. Instruksi root, PRD/DESIGN, rencana/peta FigCraft, dependency terkunci, konfigurasi Android dan hasil Fase 18 diperiksa. FigCraft dibuka read-only dan SC-01 (950) diperiksa; tidak ada perubahan widget produksi atau artefak desain, sehingga tidak ada perbandingan render UI baru pada fase ini.

| Area | Bukti / status |
| --- | --- |
| Kanal | **CONFIRMED:** download universal signed APK melalui landing page resmi, update manual. Catatan AAB Fase 15 bersifat historis dan bukan deliverable/gerbang Android fase ini. |
| Identitas | Label `Routina`; applicationId/namespace/native package masih `com.example.routina`. **DECISION REQUIRED:** ID publik pemilik, ikon/adaptive icon dan splash native final. Template launcher mdpi identik dengan SDK Flutter; tidak ditetapkan identitas pengganti sepihak. |
| Signing | **Pipeline tersedia, key pemilik PENDING.** Release tanpa kredensial ditolak pada percobaan nyata. File lokal atau empat environment variables harus lengkap, tidak dicampur. Alias debug standar ditolak, tidak ada fallback debug. Pipeline signed memerlukan ID publik, fingerprint pemilik dan versionCode yang meningkat. Tidak dibuat key produksi. |
| Rahasia | Tidak ada `android/key.properties` atau environment signing dalam sesi. Pencarian nama file key/keystore pada riwayat Git lokal dan marker private key pada file terlacak tidak menemukan hasil. Template hanya placeholder; ignore diperluas dan diperiksa. Ini pemeriksaan lokal terarah, bukan jaminan audit seluruh rahasia historis/remote. |
| Artefak audit | `build/app/outputs/flutter-apk/app-release.apk`, salinan berlabel `build/distribution/audit-unsigned/routina-1.0.0-1-universal-UNSIGNED-AUDIT.apk`, **63.914.078 byte (60,95 MiB)**. VersionName `1.0.0`, versionCode `1`, minimum API 24, target 36, ABI ARM32/ARM64/x86_64. |
| Integritas / signature | SHA-256 APK `9f5be9e53a00bbc30ebb463c5c4bebef3a79b2aacf64e1a274a6aad1d4ab0498`. `apksigner verify --verbose --print-certs` menghasilkan **DOES NOT VERIFY / Missing META-INF/MANIFEST.MF**, sesuai artefak unsigned. **Bukan signed release siap publikasi.** Fingerprint pemilik belum tersedia. |
| Alignment | `zipalign -c -P 16 -v 4` lulus; seluruh LOAD pada delapan library ELF64 arm64/x86_64 lolos pemeriksaan alignment 16 KiB. **Runtime 16 KiB PENDING**, emulator tersedia memakai halaman 4096 byte. |
| Manifest / file | Tidak ada INTERNET, storage luas atau REQUEST_INSTALL_PACKAGES; tidak debuggable; `allowBackup=false`. Dua izin sistem notifikasi/boot dan satu izin signature internal AndroidX. Launcher exported; receiver planner/share serta provider share/startup tidak exported; profile installer exported dilindungi `DUMP`. Kedua XML backup mengecualikan seluruh domain dan Share Plus dibatasi ke cache `share_plus/`. |
| Update dan data | Lokasi SQLite, skema lokal **10**, backup v1/skema pertukaran **9** dipertahankan. Uji baru 9→10 memastikan seluruh baris tabel lama, timer aktif, task/deadline, reminder progress, integrity dan foreign key tetap utuh. **Upgrade APK PENDING:** pasangan lama/baru dengan sertifikat pemilik kompatibel tidak tersedia. |
| Website / verification | [Spesifikasi website](LANDING_PAGE_DISTRIBUTION.md), [signing dan backup key](ANDROID_SIGNING.md), [checklist upgrade](ANDROID_DISTRIBUTION.md#upgrade-manual-dan-integritas-data), dan [verification terkini](ANDROID_DEVELOPER_VERIFICATION.md) tersedia. Status Routina **PENDING / belum diverifikasi dari konsol**. Tidak ada website/backend/domain/hosting dibuat atau APK diterbitkan. |

Pipeline audit unsigned dijalankan end-to-end; jalur signed dengan key pemilik belum dapat diuji karena kredensial tidak tersedia. Percobaan awal menemukan nama ZIP XML yang dipendekkan resource shrinking; resolver kini memakai resource table APK final. Pipeline juga menolak public applicationId contoh sebelum build. Metadata JSON, checksum, badging, manifest, XML backup/share, signature dan laporan zipalign disimpan di direktori artefak audit yang diabaikan Git.

- `flutter pub get --offline --enforce-lockfile` dan pemeriksaan format 111 file Dart lulus; lockfile tidak berubah.
- `flutter analyze` awal dan setelah perubahan tes lulus. Tes terarah lulus **13 tes**. Run host awal mencatat 161 lulus dan satu kegagalan timer tunggu SQLite saat teardown widget notifikasi. Harness kini memompa frame sambil menunggu SQLite serta melepas listener sebelum menguras pekerjaan tertunda; perilaku aplikasi tidak diubah.
- Regresi host penuh terakhir lulus **163 unit/widget test** dengan concurrency 1, setelah build Android selesai. Cakupan mencakup Kalender, Tugas, Rutinitas, Smart Scheduling, KPI/Statistik, pencarian, Trash, backup v1, rollback dan migrasi.
- **Empat integrasi Android lulus**, masing-masing per berkas pada emulator Android 16/API 36 x86_64 dengan build debug: `offline_journey_test`, `activity_search_test`, `backup_integrity_test` dan `device_lifecycle_test`. Cakupan meliputi penyiapan/input/reload/statistik, filter pada SQLite native, backup v1/rollback kegagalan penulisan, serta jam monotonik dan timer setelah reopen SQLite. Wi-Fi/data seluler tercatat 0 dan `ip route` kosong selama uji, lalu kedua pengaturan dipulihkan ke nilai awal 1. Pemilih dokumen sistem tidak diulang pada Fase 19. Ini bukan uji upgrade atau pemasangan APK release unsigned.
- Sintaks PowerShell, penolakan ID contoh, pemetaan/tautan dokumen relatif dan `git diff --check` lulus. Hanya file Fase 19 masuk stage; artefak build serta seluruh materi signing lokal tetap di luar Git.
- Android fisik, TalkBack/secure lock screen, runtime 16 KiB serta native iOS/VoiceOver dan pertukaran backup antarplatform tetap **PENDING**, bukan PASS. Semua keputusan OPEN dan blocker Fase 15–18 dipertahankan. Berhenti setelah Fase 19.

## Checklist sebelum distribusi publik

- [x] Pencarian dan filter Kalender serta Rutinitas lulus validasi FR-09 Fase 16.
- [x] Audit backup dan verifikasi pada Windows serta Android API 36 lulus untuk lingkup Fase 17.
- [ ] Verifikasi kebijakan backup OS iOS untuk SQLite lokal pada perangkat, termasuk upgrade dan sidecar, data transfer, serta restore perangkat.
- [ ] Finalisasi keputusan keamanan OPEN-11. Uji file terenkripsi yang sama lintas Android/iOS, pemilih file, Share Sheet, pembatalan, korupsi dan rollback pada perangkat.
- [ ] Uji perubahan izin saat aplikasi kembali dari Settings, delivery saat reboot, DND/Focus, lock screen, pergantian zona dan penghentian proses pada perangkat. Ketepatan pengiriman mengikuti pembatasan OS.
- [ ] Tetapkan application/bundle ID publik, app signing key pemilik untuk APK langsung, Apple Team, ikon/adaptive icon/splash final dan metadata privasi/penyimpanan. Verifikasi artefak distribusi bertanda tangan di kedua platform, termasuk kompatibilitas 16 KiB Android. [Panduan Android 16 KiB](https://developer.android.com/guide/practices/page-sizes)
- [ ] Validasi TalkBack/VoiceOver, keyboard perangkat, layar kecil fisik, landscape dan tablet. Perluas sampling visual ke varian FigCraft berisiko tinggi.
- [ ] Putuskan isu OPEN PRD §14 yang memengaruhi rilis, termasuk purge, retensi statistik, reminder dalam Jam Tenang, backup skema lama, DST/all-day lintas zona, dan default profil. Review parameter implementasi sekarang sebelum menjadikannya kebijakan produk.
