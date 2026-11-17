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

## Onboarding dan pengaturan Fase 06

- **CONFIRMED** · Startup memuat profil dan kategori dari SQLite. Langkah 1–3 onboarding disimpan terpisah dari tanda selesai. Setelah pengguna menyimpan profil dan jam aktif, startup berikutnya langsung membuka Home. Pilihan pengingat di Home bersifat opsional. Migrasi v2 → v3 menandai profil Fase 05 sebagai selesai karena versi tersebut menyimpan profil setelah penyiapan jam aktif.
- **CONFIRMED** · Jam aktif Senin–Minggu dapat diubah satu per satu. Editor meminta waktu mulai dan selesai pada hari yang sama dengan interval positif. Preferensi Belajar, Workout, Kegiatan lain, dan kategori tambahan disimpan secara terpisah. Preferensi per kategori mengikuti ID stabil ketika kategori berganti nama.
- **CONFIRMED** · Pilihan Senin/Minggu memengaruhi pengelompokan kalender dan Statistik tanpa menulis ulang aktivitas. Preferensi zona tampilan menyimpan pilihan zona perangkat atau ID IANA. Mode untuk kegiatan, rutinitas, dan deadline tersimpan terpisah serta menjadi pilihan awal formulir terkait. Mode asal tetap merupakan default deadline tugas.
- **CONFIRMED** · Kategori menyimpan nama, ikon, dan warna. Penghapusan meminta kategori tujuan atau Tanpa Kategori serta konfirmasi. Satu transaksi memindahkan referensi seri, occurrence, tugas, dan rutinitas, termasuk referensi pada item yang sedang di Tempat Sampah. Operasi mempertahankan ID, riwayat, dan status masing-masing aktivitas. Preferensi waktu kategori lama tersimpan dengan ID lama dan tidak dipindahkan otomatis.
- **PROPOSED** · Nama tampilan tetap opsional. Tampilan awal menggunakan Senin, preferensi waktu Fleksibel, dan zona perangkat jika belum dipilih. Draft kegiatan menggunakan mode zona asal dan draft rutinitas menggunakan mode jam lokal saat pengaturan belum diubah. Tombol contoh jam aktif hanya mengisi draf setelah ditekan, dengan 08.00–21.00 hari kerja dan 08.00–20.00 akhir pekan. Buffer kosong memakai 0 menit pada pratinjau. Jam Tenang nonaktif bila belum dikonfigurasi, dengan contoh 22.00–07.00 saat pertama diaktifkan. Jenis pengingat tampil aktif bila belum ada pilihan tersimpan, mengikuti toggle global lokal. Pengingat backup nonaktif sampai pengguna memilih interval.
- **PROPOSED** · Nama kategori aktif dibandingkan sesudah trim dan tanpa membedakan kapitalisasi. Label Tanpa Kategori disediakan untuk referensi kosong. Palet ikon dan warna awal mengikuti katalog UI. Database baru memulai daftar kategori kosong.
- **OPEN** · Kebijakan lewati onboarding, default produk final, pencocokan kategori lintas file, serta aturan final DST/perjalanan tetap mengikuti PRD. Preferensi notifikasi dan backup disimpan lokal. Pengiriman notifikasi sistem dan operasi berkas backup mengikuti fase masing-masing.

## Kalender dan kegiatan lokal (Fase 07)

- **CONFIRMED** · Home dan Kalender Hari, Minggu, serta Bulan membaca SQLite. Tampilan kalender menerapkan awal minggu yang tersimpan dan menampilkan kegiatan lintas hari pada setiap tanggal yang relevan. Kegiatan sepanjang hari menyimpan rentang tanggal dengan batas akhir eksklusif. Sibuk memblokir slot dan Tersedia membiarkan slot terbuka. Sesi kerja, jadwal rutinitas, dan penanda deadline dari database ikut diproyeksikan ke kalender.
- **CONFIRMED** · Quick Add dan Form Lengkap berbagi draf. Penyimpanan mengecek overlap, buffer, dan jam aktif di dalam transaksi. Pengguna mengonfirmasi peringatan untuk melanjutkan. Status temporal dihitung saat dibaca. Selesai, Ditunda, dan Dilewatkan hanya tersimpan setelah konfirmasi, bersama riwayat perubahan. Pengganti ditautkan ke kejadian asal dan baru ditulis setelah form disimpan.
- **PROPOSED** · Skema SQLite versi 4 menambahkan templat seri, batas pemisahan, dan detail kejadian. Pembacaan menghasilkan occurrence hanya untuk rentang yang diperlukan. ID deterministik terdiri dari ID seri dan tanggal asal. Penyuntingan satu kejadian menyimpan pengecualian. Penyuntingan cakupan berikut atau seluruh rangkaian membuat cabang mendatang dan mempertahankan kejadian lama beserta pengecualian yang sudah tersimpan. Penghapusan kejadian memakai tombstone agar recurrence tidak membangkitkannya kembali. Tanggal akhir pengulangan inklusif. Pengulangan bulanan melewati bulan yang tidak memiliki tanggal asal.
- **PROPOSED** · Seri berulang diperiksa terhadap konflik dalam 90 hari kalender pertama. Home mula-mula memuat antrean 30 hari terakhir dan memberi akses ke rentang sebelumnya. Pencarian slot pengganti meninjau tujuh hari dari hari ini dan menyediakan draf yang dapat ditinjau serta disunting.
- **PROPOSED** · Android dan iOS menyediakan ID zona perangkat melalui platform channel. Paket `timezone` menghitung konversi dari data IANA yang dibundel. Zona tampilan mengubah proyeksi Kalender. Jam aktif mengikuti zona perangkat. Mode zona asal mempertahankan jadwal sesuai zona seri, sedangkan mode jam lokal mengikuti perangkat sampai hasil kejadian dikonfirmasi dan waktu absolutnya disimpan. Untuk jam yang hilang saat DST, resolusi IANA menentukan waktu mulai dan interval tetap berurutan.
- **OPEN** · Aturan produk final untuk tanggal bulanan yang tidak tersedia, DST, dan horizon peringatan seri belum ditetapkan. Pengiriman serta batas pengingat sistem Menunggu Konfirmasi mengikuti fase notifikasi. UI perubahan tugas dan rutinitas, pemulihan Tempat Sampah, serta Smart Scheduling lengkap mengikuti fase terkait.

## Tugas dan sesi pengerjaan (Fase 08)

- **CONFIRMED** · To-Do List, Quick Add, Form Lengkap, dan Detail Tugas memakai SQLite. Tugas, subtugas, dan perubahan pengingat dalam satu form disimpan atomik. Checklist menghitung progres dari subtugas yang dicentang. Status tugas selesai memerlukan tindakan dan konfirmasi pengguna.
- **CONFIRMED** · Tenggat adalah titik kalender dan sesi merupakan interval tersendiri. Mengubah salah satunya tidak mengubah yang lain. Pindah atau batal hanya tersedia untuk sesi yang belum dimulai dan belum memiliki TimeLog. Konfirmasi penyelesaian tugas meninjau ulang sesi mendatang di transaksi yang sama, lalu membatalkan atau mempertahankannya sesuai pilihan. Riwayat sesi dan TimeLog tetap tersimpan. Soft-delete tugas menyembunyikan relasinya dari daftar aktif dan Kalender.
- **CONFIRMED** · Tenggat zona asal mempertahankan instant. Tenggat jam lokal dihitung ulang mengikuti zona perangkat dan ditampilkan dalam zona Kalender. Overdue memakai tanggal dan jam tenggat. KPI Home menghitung identitas tugas dari tenggat dan mengecualikan sesi pengerjaan sebagai kewajiban tambahan.
- **PROPOSED** · Pilihan prioritas mengikuti pratinjau FigCraft, yaitu Tinggi, Sedang, Rendah, dan Tanpa prioritas. Checklist kosong tidak menampilkan persentase. Penyelesaian tugas menyimpan instant efektif tenggat jam lokal saat dikonfirmasi. Kegiatan sesi baru dan pindah sesi memakai zona tampilan saat disimpan. Tindakan Tandai sesi terlaksana hanya menyimpan status sesi.
- **CONFIRMED** · Opsi pengingat tenggat yang dipilih disimpan sebagai `ReminderRule`. KPI Home membaca tenggat terkini.
- **OPEN** · Nilai dan default prioritas final, status tambahan tugas, frekuensi dan waktu pengingat default, serta kebijakan histori KPI setelah tenggat digeser menunggu keputusan. Pengiriman pengingat sistem, statistik historis, dan pemulihan Tempat Sampah mengikuti fase terkait.

## Rutinitas, progres aktual, dan timer (Fase 09)

- **CONFIRMED** · Rutinitas mendukung checklist, durasi, jumlah, dan target frekuensi mingguan. Progres, target, durasi jadwal, dan status dicatat terpisah. Status rutinitas berubah sesudah konfirmasi. Riwayat tanggal serta TimeLog tersimpan di SQLite. Batas agregasi mingguan mengikuti awal minggu tanpa memindahkan catatan.
- **CONFIRMED** · Start, Jeda, Lanjutkan, dan Hentikan menyimpan perubahan timer secara atomik. Waktu berjalan dihitung dari waktu mulai segmen dan jumlah waktu yang sudah terkumpul. Jeda menghentikan akumulasi lewat perubahan data. Hentikan menulis satu TimeLog dengan ID sesi, lalu membersihkan state timer di transaksi yang sama. Pengulangan perintah Hentikan tidak menambah log.
- **PROPOSED** · Migrasi SQLite versi 5 menambahkan snapshot target kejadian, waktu pilihan, mode waktu, state timer, dan event pencapaian. Perubahan target berlaku pada tanggal yang belum memiliki kejadian tersimpan. Frekuensi mingguan dijumlahkan dari jumlah aktual yang dicatat per tanggal. Kalender memakai jadwal yang disimpan eksplisit atau penanda progres sepanjang hari tanpa memblokir slot. Frekuensi pada form menyimpan pola yang dipilih dan tanggal kalender dijadwalkan satu per satu. Jika rutinitas dan blok terkait berada dalam KPI tanggal yang sama, identitas serta status kejadian rutinitas dipakai untuk satu kewajiban.
- **PROPOSED** · Timer baru dimulai untuk tanggal hari ini dan timer yang berlanjut tetap terkait dengan tanggal mulainya. Durasi dihitung memakai selisih timestamp UTC. Menutup atau mengunci layar tidak memerlukan callback timer Dart yang aktif. Penghapusan rutinitas menyimpan durasi sesi aktif sebagai TimeLog sebelum arsip disembunyikan.
- **PROPOSED** · `RoutineGoalEvent` menyediakan ID kejadian, perkiraan waktu mencapai ambang saat timer berjalan, dan waktu rekonsiliasi ketika ambang tercapai. Jeda di bawah target menghapus perkiraan dan Lanjutkan menghitungnya ulang. Event yang sudah tercapai disimpan sekali per kejadian. Fase 11 akan menangani pengiriman, izin, dan Jam Tenang.
- **OPEN** · Perilaku produk pada perubahan jam manual, reboot, dan force stop, serta hubungan final target mingguan dengan beberapa kejadian harian perlu diputuskan. Durasi aktual sesi tugas tetap mengikuti OPEN-01. Validasi di perangkat Android/iOS fisik tetap diperlukan.

## Fase 10 · Smart Scheduling

- **CONFIRMED** · Proposal dibentuk dari kalender dan jam aktif terkini hingga tenggat yang berlaku. Mesin memilih satu sesi bila cukup, atau membagi durasi tepat ke beberapa sesi. Event Sibuk, recurrence, sesi lain, rutinitas terjadwal, serta buffer di kedua sisi membatasi slot. Persetujuan memeriksa ulang usulan yang sama di transaksi SQLite, lalu menyimpan semua perubahan atau membatalkan transaksi. Sesi yang diganti dibatalkan dengan riwayat tetap tersedia dan sesi pengganti mencatat relasi asal jika dapat dipasangkan. Tenggat dan sesi terlaksana tetap tercatat.
- **PROPOSED** · Jam aktif memakai zona perangkat, termasuk pembacaan jam yang hilang atau berulang saat DST. Kandidat mulai pada menit berikutnya atau sesudahnya. Pengaturan kategori diprioritaskan, lalu preferensi Belajar, Workout, atau Kegiatan lain sesuai kategori tugas. Rentang preferensi memakai Pagi 06.00–12.00, Siang 12.00–15.00, Sore 15.00–18.00, dan Malam 18.00–24.00 sebagai urutan pilihan di dalam jam aktif.
- **PROPOSED** · SQLite v6 menyimpan batas per tugas dan durasi aktual saat estimasi sisa dikonfirmasi. Batas maksimum menghitung sesi yang masih mendatang, termasuk sesi yang dipertahankan. Batas profil dapat diisi dari pengaturan kalender. Jika batas profil dan tugas belum ada, pengguna memasukkan batas di pencarian. Batas khusus tugas tersimpan ketika perubahan jadwal disetujui. Angka contoh FigCraft tetap menjadi referensi visual.
- **PROPOSED** · Input aktual minimal memakai catatan manual dalam menit setelah sesi berakhir. Beberapa `TimeLog` per sesi dijumlahkan, dan catatan baru meminta konfirmasi ulang estimasi sisa. OPEN-01 masih mencakup timer tugas dan kebijakan koreksi log. Notifikasi sistem untuk konflik tetap mengikuti fase pengingat. Pencarian slot pengganti kegiatan memakai jendela tujuh hari.

## Fase 11 · Notifikasi lokal

Post-commit SQLite memicu rekonsiliasi pengingat dengan agenda yang memakai aturan zona, pengulangan, status, dan Tempat Sampah yang sama. Kesalahan pengiriman sistem tampil di Home dan pengaturan, sementara perubahan jadwal yang sudah tersimpan tetap berlaku. Adaptor Android dan iOS menjadwalkan pengiriman lewat layanan OS. Lihat [keputusan Jam Tenang dan batasan perangkat](NOTIFICATIONS.md).

## Fase 12 · Statistik produktivitas

- **CONFIRMED** · Home dan Statistik memakai proyeksi kalender SQLite yang sama. Kegiatan dihitung pada tanggal mulai di zona tampilan, tugas pada tanggal tenggat, dan rutinitas pada tanggal target. Status Selesai hanya berasal dari konfirmasi tersimpan. Ditunda dan Dilewatkan tetap masuk total, sedangkan item yang dibatalkan atau masuk Tempat Sampah dikeluarkan. Hari dengan nol kewajiban tidak memiliki persentase. KPI total membagi seluruh kewajiban selesai dengan seluruh kewajiban pada rentang. Rata-rata harian memberi bobot yang sama pada setiap tanggal dengan kewajiban.
- **CONFIRMED** · Sesi pengerjaan menggunakan identitas tugas. Identitas dan status kejadian rutinitas dipakai untuk blok kalender yang terhubung langsung. Pengganti mempertahankan relasi asal dan dihitung pada tanggal baru, kecuali rutinitas yang sama sudah ditargetkan pada tanggal itu. Hasil kegiatan asal tetap terlihat di riwayat. Pengubahan awal minggu mengelompokkan ulang tanggal pada pembacaan, tanpa memutasi kegiatan.
- **PROPOSED** · Tanggal hari ini diukur penuh dalam zona tampilan. Pembanding otomatis memilih periode kalender sebelumnya. Pemilihan manual mengikuti granularitas yang dipilih. Jika salah satu periode sedang berjalan, dua rentang pembanding memakai jumlah tanggal pertama yang sama, dibatasi oleh rentang yang lebih pendek. Periode bulanan yang sudah berakhir memakai panjang kalender masing-masing. UI menunjukkan kedua rentang aktual.
- **PROPOSED** · Rutinitas dengan pola harian atau hari tertentu menjadi kewajiban pada tanggal yang sesuai meski belum memiliki blok atau catatan progres. Target mingguan tanpa hari yang dipilih memakai kejadian bertanggal yang sudah dicatat. Migrasi SQLite v8 menambahkan riwayat pola yang berlaku sejak tanggal simpan, dengan kejadian tersimpan sebagai sumber utama status. Untuk rutinitas lama tanpa riwayat pola, laporan memakai pola tersimpan sejak tanggal pembuatan.
- **OPEN** · Laporan saat ini membaca tenggat dan kategori yang berlaku, termasuk setelah pemindahan kategori. Data yang sudah dihapus permanen tidak dapat ditampilkan kembali oleh laporan. Kebijakan histori saat tenggat dipindah, kategori diganti, atau item dihapus permanen, serta batas periode berjalan dan pembanding bulan dengan panjang berbeda, tetap menunggu keputusan produk.

## Fase 13 · Tempat Sampah dan pemulihan

- **CONFIRMED** · Soft-delete mempertahankan ID, isi, dan catatan turunan di SQLite. Agenda, Smart Scheduling, pengingat, daftar aktif, dan KPI memakai data yang terlihat setelah penyaringan. Setelah commit, layanan pengingat menghitung ulang antrean perangkat. Daftar dan detail SC-29 menampilkan waktu penghapusan, batas pemulihan, serta konfirmasi pemulihan dan penghapusan permanen.
- **PROPOSED (OPEN-06)** · Retensi memakai 30 × 24 jam sejak instant UTC penghapusan. SQLite menyimpan waktu penghapusan dan kedaluwarsa. Migrasi mengisi batas tersebut untuk item lama. Pada instant kedaluwarsa pemulihan ditolak. Item kedaluwarsa tetap dapat dilihat dan dihapus permanen secara manual dengan konfirmasi. Operasi berulang saat item masih di Tempat Sampah mempertahankan waktu penghapusannya. Penghapusan sesudah pemulihan mendapat periode retensi baru.
- **PROPOSED (OPEN-06)** · Pemulihan induk mengaktifkan kembali data yang disembunyikan oleh induk, termasuk blok yang memerlukan kejadian rutinitas. Item yang memiliki penghapusan sendiri tetap tersembunyi. Pemulihan anak menunggu induk yang dibutuhkannya. Referensi kategori yang sudah dipindahkan memakai pilihan terkini. Jika kategori lama masih dirujuk dan telah dihapus, tinjauan menjelaskan bahwa kategori akan dikosongkan pada item yang kembali. Penghapusan permanen menghapus data milik item dan ditolak jika aktivitas atau riwayat lain masih merujuknya. Pemutusan hubungan lintas entitas menunggu keputusan produk.
- **PROPOSED** · Tinjauan menjalankan pemulihan di transaksi yang di-rollback. Persetujuan memeriksa ulang masukan, retensi, dan konflik pada transaksi penyimpanan. Pemeriksaan mencakup jadwal eksplisit yang masih berjalan atau akan datang serta 90 hari kalender dari kejadian virtual pertama yang kembali. Pengguna dapat membatalkan, memulihkan dengan bentrok, atau memilih tanggal lain untuk kegiatan berjam yang belum punya hasil maupun durasi aktual. Kegiatan lain tidak diubah.
- **PROPOSED** · Skema v9 mengarsipkan cakupan seri mendatang sebagai satu item, menyimpan batas lama serta kejadian tersimpan yang ikut dipindahkan. Pemulihan cakupan mengaktifkan kembali kejadian virtual dan tersimpan. Penghapusan permanen mempertahankan batas seri dan pengecualian tanggal yang diperlukan agar recurrence tidak membangkitkan item. Seri memiliki satu cakupan yang dapat dipulihkan pada satu waktu. Jika versi sebelumnya sudah memotong seri, hanya kejadian yang memiliki arsip tersimpan dapat dipulihkan karena batas lama belum tercatat.
- **OPEN** · Purge otomatis, definisi bisnis final untuk batas 30 hari, aturan final pemulihan parsial dan penghapusan referensi lintas entitas, serta retensi snapshot statistik setelah penghapusan permanen masih menunggu keputusan. Fase ini membiarkan purge otomatis nonaktif. Statistik memakai data aktif terkini dan menghitung ulang setelah pemulihan.

## Fase 14 · Backup terenkripsi

Ekspor dan pemulihan memakai snapshot SQLite berversi dengan pilihan penggabungan per ID serta commit atomik. Pemilih file dan Share Sheet memberi akses ke penyimpanan yang tersedia di perangkat. Parameter keamanan, aturan kombinasi data, batas aplikasi, serta keputusan yang masih terbuka dicatat untuk review. [Format dan kebijakan backup](BACKUP.md)

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
