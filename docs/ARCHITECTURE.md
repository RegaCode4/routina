# Arsitektur Routina

## Cakupan Fase 01

Proyek Flutter stable 3.41.2 dan Dart 3.11.0 melanjutkan scaffold Android/iOS yang sudah ada. Shell menyediakan lima tab dan navigasi Home → Statistik → kembali. Home menampilkan tanggal perangkat dalam bahasa Indonesia. Layar yang belum memiliki implementasi menampilkan pesan sementara. KPI, onboarding, kategori, database, pengingat, timer, dan formulir masuk ke fase yang relevan pada [rencana implementasi](IMPLEMENTATION_PLAN.md).

Baseline platform Windows membangun Android. Validasi iOS memerlukan macOS/Xcode. Identitas platform bawaan `com.example.routina`, ikon aplikasi dan signing rilis masih **OPEN**. Tidak ada kebutuhan konfigurasi flavor atau environment terpisah pada fondasi offline ini.

## Batas dependensi

```text
lib/
  main.dart                      Composition root dan pelaporan error framework
  presentation/                  Aplikasi, tema, shell, routing dan state widget
  application/                   Use case dan koordinasi operasi
  domain/                        Kontrak murni Dart dan Result
  data/                          Adaptor konkret untuk sumber data lokal/perangkat
test/
  application/                   Uji use case dengan dependency palsu
  widget_test.dart               Uji shell, navigasi, kegagalan dan lifecycle
```

```text
main → presentation + application + data
presentation → application + domain
application → domain
data → domain
domain → Dart SDK
```

- **Presentation** mengubah hasil use case menjadi tampilan. Ia dapat membaca value object domain, dan tidak mengimpor adaptor data, database, atau plugin dari fitur lain.
- **Application** menjalankan use case dan mengoordinasikan kontrak repository/layanan domain. Ia tidak membutuhkan Flutter, widget, adaptor data, atau plugin platform.
- **Domain** memegang aturan, kontrak, dan hasil yang independen dari Flutter dan storage. Model persisten atau DTO menjadi milik lapisan data.
- **Data** mengimplementasikan kontrak domain. Validasi di batas file atau plugin, pemetaan model persisten, query, dan migrasi tinggal di sini.
- **Composition root** di `main.dart` merangkai `DeviceClock → ReadToday → RoutinaApp`. Uji dapat mengganti `Clock` melalui konstruktor. Saat modul bisnis tumbuh, kelompokkan file berdasarkan fitur di tiap lapisan dan pertahankan arah impor.

## Keputusan teknis

| Area | Pilihan fase ini dan alasan |
| --- | --- |
| State | Gunakan state Flutter lokal (`StatefulWidget` dan `setState`) karena shell memiliki dua input tampilan, tab aktif dan hasil pembacaan tanggal. Gunakan state turunan dari use case dan stream repository bila fitur membutuhkan data reaktif. Jika koordinasi lintas widget dibutuhkan, evaluasi `ChangeNotifier`/`Listenable` sebelum menambah package. [Rekomendasi arsitektur Flutter](https://docs.flutter.dev/app-architecture/recommendations) |
| Routing | Gunakan `IndexedStack` dan `RoutinaBottomNavigation` untuk menjaga pohon widget lima tab. Statistik adalah `MaterialPageRoute` dari Home dan Back mengembalikan pengguna ke Home. `/statistik` adalah identitas route internal dan belum menjadi deep link. Tinjau router deklaratif kalau alur notifikasi, deep link atau stack per tab muncul pada fase berikutnya. [Navigasi Flutter](https://docs.flutter.dev/ui/navigation) |
| Dependency injection | Gunakan injeksi konstruktor dan satu composition root. Dependency terlihat di API dan mudah diganti dalam unit/widget test. Objek dibuat sedekat mungkin dengan pemilik lifecycle. |
| Penyimpanan | Fase 01 mengusulkan SQLite melalui Drift. Fase 05 memilih SQLite lewat `sqflite` karena API paket sudah mencakup transaksi, migrasi, query berparameter, dan lokasi database internal Android/iOS. Skema SQL langsung mencakup relasi yang diperlukan tanpa generator kode. [Dokumentasi sqflite](https://pub.dev/packages/sqflite) |
| Dependency storage | `sqflite` adalah adaptor aplikasi. Tes host memakai `sqflite_common_ffi` untuk membuka SQLite nyata melalui kontrak yang sama. Versi yang diselesaikan oleh Flutter 3.41.2 ada di `pubspec.lock`. [Dokumentasi adaptor FFI](https://pub.dev/packages/sqflite_common_ffi) |
| Tema dan bahasa | Gunakan palet FigCraft untuk shell light dan font Bricolage Grotesque yang tersedia lokal. SDK `flutter_localizations` memberi locale `id` untuk tanggal, tooltip Back dan semantik widget standar. App icon, pilihan font final dan rincian visual masih mengikuti review desain. |

Pilihan teknis ditinjau pada fase yang menggunakannya. Aturan produk yang **CONFIRMED**, rincian yang **PROPOSED**, dan keputusan bisnis yang **OPEN** tetap tercatat di [PRD.md](../PRD.md) dan rencana implementasi.

## Penyimpanan lokal Fase 05

- **CONFIRMED** · `PlannerStore` adalah kontrak sumber data offline. Model murni Dart ada di `lib/domain/planner_records.dart`. Adaptor `SqlitePlannerStore` membuka `routina.db` pada direktori database internal aplikasi, mengaktifkan foreign key per koneksi, dan menutup koneksi melalui `close()` untuk pengujian atau pemilik yang berumur terbatas.
- **CONFIRMED** · `records` menyimpan identitas UUID v4 lintas jenis, relasi kepemilikan, revisi, dan waktu perubahan. Tabel bertipe menyimpan relasi dan constraint domain. Penulisan item baru menghasilkan revisi 1. Pembaruan meminta revisi terkini. Tanggal saja disimpan sebagai ISO lokal dan waktu terjadwal sebagai instant UTC plus zona asal/mode. Mode lokal juga membawa waktu dinding.
- **CONFIRMED** · Deadline task adalah titik. Durasi rencana berasal dari interval sesi. Durasi aktual berasal dari `TimeLog`. Estimasi sisa dan waktu konfirmasinya disimpan berpasangan. Checklist disimpan terpisah dan tidak memicu status selesai. Perubahan status menulis histori dalam transaksi yang sama. Jadwal kejadian berstatus final atau sudah memiliki time log dilindungi dari perubahan interval.
- **CONFIRMED** · `calendar(from, until)` mengambil interval yang tumpang tindih dengan rentang `[from, until)` dan deadline yang jatuh di dalamnya. Query memakai indeks batas waktu. Representasi menyertakan ID kewajiban untuk deduplikasi oleh statistik. Sesi tetap mereferensikan Task walaupun blok kalender lain dapat menampilkan kewajiban yang sama.
- **CONFIRMED** · Soft-delete menyimpan tombstone dan menyembunyikan item berikut turunan yang dimilikinya dari query aktif. Pemulihan menyimpan waktu restore pada tombstone. `includeDeleted` memberi akses ke snapshot yang diperlukan saat membandingkan data backup. Kategori yang masih dipakai item aktif harus dipindahkan dalam transaksi sebelum dihapus.
- **PROPOSED** · Skema v1 memuat tabel inti. Migrasi v2 menambah pasangan estimasi terkonfirmasi, indeks kalender, dan trigger perlindungan riwayat. Pembuatan serta migrasi berjalan dalam transaksi bawaan sqflite. Versi yang lebih baru ditolak tanpa downgrade destruktif. Tambahkan migrasi maju dan uji fixture versi sebelumnya untuk perubahan berikutnya.
- **PROPOSED** · `transaction` memberi scope repository kepada pemanggil untuk satu transaksi SQLite. Bila salah satu penulisan gagal, scope dibatalkan termasuk jika callback menangkap error tersebut. Pemanggil Smart Scheduling dapat memakai scope ini setelah persetujuan serta validasi ulang.
- **PROPOSED** · Startup normal memuat dan menyimpan profil beserta jam aktif, awal minggu, preferensi belajar/workout, dan toggle pengingat melalui SQLite. Rute fixture `ROUTINA_PREVIEW` memakai data memori. Layar kegiatan, tugas, rutinitas, dan fitur demo lain masih memakai adaptor pratinjau Fase 04. Data fixture tidak diimpor ke database.
- **OPEN** · Input serta koreksi durasi aktual sesi tugas, keputusan detail recurrence dan zona waktu, kebijakan konflik merge, dan batas purge tetap mengikuti PRD. Struktur menyimpan banyak time log per sesi, kunci asal occurrence, relasi split/pengganti, dan tombstone. Backup file, notifikasi OS, serta keputusan penyelesaian konflik belum digerakkan oleh adaptor ini.

Tes `test/data/sqlite_planner_store_test.dart` memakai file database sementara untuk menguji reopen ke-13 model, foreign key, transaksi gagal, rentang kalender, perlindungan riwayat, dan migrasi maju.

## Result, exception, dan lifecycle

- Use case mengekspresikan hasil yang dapat ditangani sebagai `Success<T>` atau `Failure<T>`. `ReadToday` mempertahankan exception dan stack untuk diagnosis bila port gagal. Tampilan Home memakai pesan Indonesia yang aman dan aksi Coba lagi. Error pemrograman merambat ke handler framework.
- Error framework memakai pelaporan lokal Flutter. Error async yang tidak tertangani dari root isolate diteruskan ke mekanisme yang sama. Ketika build widget gagal, fallback memberi pesan aman tanpa detail teknis di layar. Adaptor fitur yang kelak menangani data pengguna perlu menjaga data sensitif keluar dari detail exception dan log.
- Shell membaca tanggal saat dibuat dan ketika aplikasi resume melalui `AppLifecycleListener`. Pemilik widget melepas listener saat dispose, dan resume mempertahankan tab terpilih. Ini merupakan pembaruan tanggal tampilan. Mekanisme durable timer, notifikasi, dan pemulihan proses akan mengikuti aturan PRD di fase terkait.
- Untuk operasi asinkron mendatang, presentation mengelola loading dan empty state sesuai kebutuhan layar, lalu membaca hasil use case. Operasi tanggal pada shell bersifat sinkron.

## Pemeriksaan perubahan

```sh
flutter pub get
dart format lib test
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Uji unit memeriksa normalisasi tanggal lokal dan pemisahan exception yang dapat ditangani dari error pemrograman. Uji widget mencakup lima tab, akses dan Back Statistik, retry, resume dengan tab tetap, dan layout sempit pada skala teks 200%. Jalankan pemeriksaan perangkat dengan `flutter run -d <device-id>`. Cek palet, kontras aksen, label, dan komposisi terhadap frame shell pada [peta FigCraft](FIGCRAFT_SCREEN_MAP.md), termasuk `SC04_Home_Default` (175).
