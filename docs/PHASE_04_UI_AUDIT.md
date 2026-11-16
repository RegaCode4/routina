# Fase 04 · Pratinjau layar dan audit visual

UI SC-11–30 memakai fixture di `lib/presentation/demo/demo_session.dart`. Tugas, rutinitas, opsi pengaturan, dan hasil contoh hidup selama proses berjalan. Deadline dan sesi yang disetujui memakai entri terpisah di repository kalender dalam memori dari Fase 03.

Jalankan `flutter run --dart-define=ROUTINA_PREVIEW=standard` untuk langsung membuka Home. Tanpa argumen, aplikasi membuka alur penyiapan lokal. Gunakan lima tab, tombol tambah, dan Statistik dari Home atau Profil.

| Layar | Frame FigCraft | Cara memeriksa state |
|---|---|---|
| SC-11 | 5428 | Buka To-Do List. Cari judul, ubah kategori, tanggal, status, prioritas, atau urutan. Pilih Selesai untuk daftar tugas selesai. |
| SC-12 | 5495 | Buka Laporan E-Commerce. Centang subtugas terakhir, periksa durasi aktual di riwayat, dan konfirmasi nasib sesi mendatang dari CTA selesai. |
| SC-13 | 5550, 5582 | Tombol tambah → Tugas → Form lengkap. Periksa draft, form wajib, deadline lampau, zona waktu, pengingat, dan editor subtugas. |
| SC-14 | 6958 | Tab Rutinitas menampilkan mingguan dan riwayat. Gunakan `routine-missed` untuk penanda terlewat. |
| SC-15 | 7021, 7087 | Tombol tambah → Rutinitas → Form lengkap. Pilih jenis target, ubah frekuensi dan nilai target, atau tambahkan item checklist. |
| SC-16 | 7053 | Buka Belajar Flutter. Mulai, jeda, lanjutkan, akhiri, atau catat manual. `routine-restored` membuka contoh timer yang dipulihkan dalam proses. Target tercapai dan Selesai diperiksa terpisah. |
| SC-17 | 8138 | Detail tugas → Cari slot. Isi estimasi, minimum, maksimum, dan preferensi. Konfirmasi estimasi sebelum pencarian. |
| SC-18 | 8181 | Tinjau usulan satu/split sesi dan dialog persetujuan. `smart-stale` memicu perhitungan ulang sebelum penyimpanan. |
| SC-19 | 8221 | Jalankan `smart-no-slot`, atau beri minimum lebih besar dari estimasi. Periksa alasan dan opsi ubah batas atau tambah sesi manual. |
| SC-20 | 8265 | `smart-conflict` dan `smart-multi-conflict` menampilkan konflik satu/beberapa sesi pada detail tugas. Pilih sesi terdampak, semua sesi mendatang, atau pertahankan rencana. |
| SC-21 | 8303 | Tinjau Selisih Durasi dari detail tugas. Fixture standar menunjukkan kekurangan. Gunakan `smart-balanced` atau `smart-surplus` untuk alokasi pas atau berlebih. |
| SC-22 | 9438 | Statistik → Hari/Minggu/Bulan, filter kategori, tanggal, pembanding, dan rincian. `stats-empty` menunjukkan periode kosong dan hari tanpa aktivitas. |
| SC-23 | 10115 | Tab Profil → edit nama dan pilih pengaturan. Gunakan `backup-due` atau `notifications-off` untuk banner contoh. |
| SC-24 | 10188 | Profil → Jam aktif & preferensi. Pilih hari, coba interval tidak valid, simpan preferensi belajar/workout. Zona waktu tersedia di Kalender & zona waktu. |
| SC-25 | 10242 | Profil → Notifikasi & Quiet Hours. Pilih izin simulasi, ubah jam senyap dan pengecualian. Gunakan `notifications-error` untuk kegagalan penjadwalan contoh. |
| SC-26 | 10285 | Profil → Kategori. Tambah, edit warna/ikon, coba nama duplikat, atau hapus dengan pemindahan kategori. |
| SC-27 | 11689, 11729 | Profil → Backup & Restore → Ekspor. Isi dua password contoh, pilih tujuan dan periksa status. `backup-write-error`, `backup-picker-unavailable`, dan `backup-share-cancel` menampilkan hasil alternatif. |
| SC-28 | 11762, 11793 | Profil → Backup & Restore → Pulihkan. Gunakan password contoh `routina` dan pilih fixture tanpa konflik, satu/beberapa konflik, berkas invalid, versi skema, integritas, atau rollback. Ganti Semua dan Gabungkan memiliki konfirmasi. |
| SC-29 | 11840 | Profil → Tempat Sampah. Uji pulihkan/hapus permanen. `trash-conflict` atau `trash-expired` menampilkan skenario batas. |
| SC-30 | 13800, 13890, 13986, 14026, 14062, 14152, 14206, 14233 | Dialog tugas, persetujuan usulan, Q80, perubahan awal minggu, pemindahan kategori, Replace, hapus permanen, dan izin. Dialog kegiatan berulang, bentrok, dan hasil kegiatan tetap tersedia dari Fase 03. |

Feed `tasks`, `routines`, `stats`, `categories`, dan `trash` menerima akhiran `-empty`, `-loading`, atau `-error` sebagai nilai `ROUTINA_PREVIEW`. Tombol lanjut/coba lagi membuka data contoh dari state muat atau gagal.

## Keputusan dan batas

- **CONFIRMED** · Smart Scheduling membutuhkan konfirmasi estimasi dan persetujuan jadwal. Draft usulan terpisah dari entri kalender. Batas dan bentrok diperiksa ulang saat persetujuan.
- **CONFIRMED** · Deadline, sesi pengerjaan, estimasi sisa, durasi aktual, progres checklist, dan status selesai mempunyai tampilan terpisah.
- **PROPOSED** · Sampel memori, interval pencarian demo, warna ikon kategori, dan deteksi duplikat tanpa membedakan huruf besar/kecil dipakai untuk validasi UI.
- **OPEN** · Cara pencatatan durasi aktual sesi tugas tetap terbuka. Detail menampilkan catatan dari fixture. Kebijakan jadwal, statistik final, duplikat kategori, dan purge mengikuti fase implementasi terkait.
- **OPEN** · Izin OS, notifikasi perangkat, data persisten, migrasi, enkripsi, pemilih berkas native, dan transaksi restore berada di luar Fase 04. Pemulihan memakai file dan password contoh. Simulasi Replace/Merge menampilkan hasil pilihan dan skenario rollback.

Audit membandingkan 31 render Flutter 390 × 844 dengan frame FigCraft pada tabel. Isi fixture, posisi beberapa kontrol, ikon Material, dan pembungkusan teks mengikuti kebutuhan pratinjau dan layout responsif.
