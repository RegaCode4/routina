# Kesiapan rilis Routina · Fase 15–16

**Belum siap untuk distribusi publik.** Audit menggunakan [PRD](../PRD.md), [DESIGN](../DESIGN.md), [referensi FigCraft](FIGCRAFT_SCREEN_MAP.md), dan [rencana fase](IMPLEMENTATION_PLAN.md). Status “Ada” menunjukkan jalur produksi yang terhubung ke data lokal. Batas verifikasi perangkat dicatat terpisah.

## Cakupan FR

| FR | Status implementasi dan bukti |
| --- | --- |
| FR-01 Home dan KPI | Ada. Home membaca ringkasan SQLite dari domain produktivitas. Lima KPI, agenda, kewajiban terhubung, hasil Ditunda/Dilewatkan, hari kosong, serta antrean konfirmasi tercakup di `productivity_test` dan `widget_test`. |
| FR-02 Kalender | Ada. `PlannerCalendar` memuat hari, minggu, bulan, event lintas hari, deadline, sesi kerja, dan blok rutin. `activity_calendar_test`, `task_workspace_test`, dan `routine_workspace_test` menguji sumber data kalender. |
| FR-03 Kegiatan dan recurrence | Ada. `EventEditor` dan `ActivityCalendar` mendukung Quick Add, draft, field lengkap, recurrence, exception dan split, all-day Sibuk/Tersedia, bentrok dan buffer. `activity_calendar_test` serta `widget_test` meliputi scope, lintas hari dan warning. |
| FR-04 Status dan pengganti | Ada. `EventDetail` dan Home menawarkan konfirmasi eksplisit dan pengganti manual/slot. Catatan lama bertahan. `activity_calendar_test`, `smart_scheduling_test` dan `local_reminders_test` meliputi histori, review pengganti dan pengingat. |
| FR-05 Tugas dan subtugas | Ada. Checklist, siklus tugas, tenggat, sesi rencana dan durasi aktual terpisah. Input aktual manual tersedia. `task_workspace_test` dan `task_screens_test` mencakup konfirmasi tugas dan sesi mendatang. Pilihan timer untuk sesi tugas masih OPEN. |
| FR-06 Rutinitas dan timer | Ada. Empat bentuk target, timer dan input manual. `routine_workspace_test` memverifikasi pemulihan setelah membuka kembali SQLite, segmen aktif, Pause/Resume/Stop dan status eksplisit. Lock screen, reboot, force stop, serta perubahan jam OS memerlukan validasi perangkat. |
| FR-07 Smart Scheduling | Ada. `SchedulingEngine` dan `SmartScheduling` menerapkan slot tunggal/split, batas sesi, preferensi, buffer, zona, review, stale dan persetujuan atomik. Uji engine, workspace, dan layar meliputi bentrok, scope dan selisih sisa durasi. |
| FR-08 Notifikasi | Ada. `LocalReminders`, adaptor native, Home dan Pengaturan mencakup izin, Jam Tenang, reminder, snooze dan fallback. Uji domain/widget menggunakan adaptor palsu untuk pergantian izin dan pembaruan antrean. Delivery setelah reboot, DND/Focus, perubahan Settings, dan background iOS perlu validasi perangkat. [Batas OS](NOTIFICATIONS.md) |
| FR-09 Kategori, pencarian dan filter | **COMPLETE (Fase 16).** CRUD kategori dan pemindahan referensi teruji. Pencarian judul, filter gabungan, pengurutan yang relevan, dan state kosong tersedia di Tugas, Kalender, dan Rutinitas pada jalur SQLite produksi. |
| FR-10 Statistik | Ada. `ProductivityStatistics` membaca data lokal dari Home dan Profil. Uji menghitung dua rasio, periode kosong, pembanding setara/otomatis/manual dan riwayat. |
| FR-11 Zona dan awal minggu | Ada. `CalendarZones` menerapkan waktu lokal/instant ke kalender, recurrence, tenggat, rutin, statistik dan scheduler. Pengujian mencakup DST dengan jam berulang/hilang dan hitung ulang minggu tanpa mutasi histori. Refresh OS, termasuk pengingat ketika zona perangkat berubah, perlu validasi perangkat lintas OS. |
| FR-12 Tempat Sampah | Ada. Soft-delete, retensi, restore dengan cek relasi/kategori/bentrok dan penghapusan permanen eksplisit teruji di `trash_workspace_test` dan `trash_screens_test`. Jadwal purge otomatis dan kebijakan statistik setelah purge masih OPEN. |
| FR-13 Backup dan restore | Ada. Ekspor terenkripsi, validasi, Ganti Semua, Gabungkan berdasarkan ID dan keputusan per konflik. Uji cipher, workspace dan UI mencakup sandi salah, korupsi, relasi, stale dan abort SQLite saat penulisan. Fase 14 menguji ekspor/restore melalui pemilih file Android dan membuka Share Sheet. Review keamanan dan kompatibilitas native lintas OS masih terbuka. [Format dan transaksi](BACKUP.md) |


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
- Android memakai AGP 8.11.1, Gradle 8.14, Java target 17, SDK minimum 24 serta compile/target 36. Release memuat data produksi dan memakai konfigurasi signing lokal bila tersedia. Manifest mengatur `allowBackup=false`, dengan pengecualian semua domain untuk cloud backup dan device transfer. Pemilih file tetap mendukung ekspor manual. [Android Auto Backup](https://developer.android.com/identity/data/autobackup)
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

## Checklist sebelum distribusi publik

- [x] Pencarian dan filter Kalender serta Rutinitas lulus validasi FR-09 Fase 16.
- [ ] Tentukan kebijakan backup OS iOS untuk SQLite lokal. Uji upgrade, data transfer dan restore perangkat tanpa kehilangan riwayat.
- [ ] Selesaikan review keamanan format, algoritma, iterasi dan batas pembacaan backup. Uji file terenkripsi yang sama lintas Android/iOS, pemilih file, Share Sheet, pembatalan, korupsi dan rollback pada perangkat.
- [ ] Uji perubahan izin saat aplikasi kembali dari Settings, delivery saat reboot, DND/Focus, lock screen, pergantian zona dan penghentian proses pada perangkat. Ketepatan pengiriman mengikuti pembatasan OS.
- [ ] Tetapkan application/bundle ID publik, upload key, Apple Team, ikon/splash final dan metadata privasi/penyimpanan. Verifikasi artefak distribusi bertanda tangan di kedua platform, termasuk kompatibilitas 16 KiB Android. [Panduan Android 16 KiB](https://developer.android.com/guide/practices/page-sizes)
- [ ] Validasi TalkBack/VoiceOver, keyboard perangkat, layar kecil fisik, landscape dan tablet. Perluas sampling visual ke varian FigCraft berisiko tinggi.
- [ ] Putuskan isu OPEN PRD §14 yang memengaruhi rilis, termasuk purge, retensi statistik, reminder dalam Jam Tenang, backup skema lama, DST/all-day lintas zona, dan default profil. Review parameter implementasi sekarang sebelum menjadikannya kebijakan produk.
