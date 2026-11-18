# PRD.md

# Product Requirements Document: Aplikasi Perencana Aktivitas Personal

> **Status:** Draf kerja v0.1, berdasarkan keputusan wawancara pertanyaan 1–80 (15 November 2026).  
> **Target:** Flutter untuk Android dan iOS.  
> **Pendekatan:** Offline-first MVP, **design-first**; prototipe layar dan state sebelum implementasi fungsional dengan Codex + FigCraft.  
> **Pasangan dokumen:** [`DESIGN.md`](./DESIGN.md).  
> **Aturan perubahan:** Keputusan yang sudah dikonfirmasi ditulis sebagai persyaratan. Hal yang belum diputuskan ditandai **OPEN** atau **PROPOSED** dan **tidak boleh diasumsikan sudah disetujui**.

## 1. Ringkasan eksekutif

Aplikasi membantu pengguna mengatur kegiatan terjadwal, deadline to-do, dan rutinitas dalam satu sistem, menghindari bentrokan, menerima pengingat, dan mengevaluasi produktivitas. Kekuatan utama produk adalah kalender terintegrasi dengan Smart Scheduling yang **memberikan saran tetapi tidak memodifikasi jadwal secara diam-diam**.

MVP menyimpan data di perangkat dan dapat digunakan tanpa akun maupun internet. Pengguna dapat mengekspor dan memulihkan file backup manual yang terenkripsi password. Akun email/password, backend terkelola, dan sinkronisasi lintas perangkat merupakan **fase setelah MVP** dan tidak termasuk rilis offline awal.

Produk **bukan** sistem yang menghitung keberhasilan berdasarkan waktu berlalu saja: kegiatan harus dikonfirmasi Selesai/Ditunda/Dilewatkan; tugas utama juga harus diselesaikan secara eksplisit meskipun subtugas mencapai 100%.

## 2. Sasaran, pengguna, dan ukuran keberhasilan

### 2.1 Sasaran produk

1. Membuat kegiatan, tugas, dan rutinitas mudah ditangkap, dilihat, dicari, dan dikelola.
2. Mengurangi risiko jadwal tumpang tindih dengan peringatan bentrok dan buffer.
3. Mengubah waktu kosong sebelum deadline menjadi rekomendasi sesi pengerjaan yang dapat ditinjau.
4. Membantu mempertahankan kebiasaan melalui target, timer, pengingat, dan riwayat progres aktual.
5. Menghasilkan statistik harian/mingguan/bulanan yang konsisten tanpa double-counting.
6. Memberikan kepemilikan data melalui penggunaan offline serta backup/restore terenkripsi.

### 2.2 Pengguna

- Pemilik jadwal individual, termasuk pelajar/mahasiswa dan pengguna umum dengan kegiatan, tugas, dan rutinitas.
- Tiap instalasi MVP berisi profil lokal perangkat; **bukan** produk kolaborasi tim dan **bukan** kalender multiakun di fase ini.

### 2.3 Indikator evaluasi produk (PROPOSED, bukan keputusan wawancara)

- Pengguna mampu menambah kegiatan/tugas/rutinitas dari Quick Add tanpa harus membuka formulir panjang.
- Bentrok dan pelanggaran buffer terlihat sebelum konfirmasi simpan.
- Setiap perubahan jadwal hasil Smart Scheduling dapat dilacak melalui aksi persetujuan.
- Backup berhasil diuji dengan putaran ekspor → impor → verifikasi data.
- Persentase KPI dapat dihitung ulang deterministik dari riwayat yang sama.

Tidak ada target numerik penggunaan/retensi yang disepakati.

## 3. Ruang lingkup dan strategi rilis

### 3.1 Dalam spesifikasi MVP offline-first

- Splash, onboarding, profil lokal, preferensi jam aktif per hari dan per tipe kegiatan.
- Home dengan KPI hari ini, daftar aktivitas, aktivitas terdekat, dan antrean konfirmasi.
- Kalender harian, mingguan, bulanan dengan kegiatan, deadline, rutinitas/sesi terkait.
- To-Do List lengkap dengan prioritas, subtask, deadline, overdue, pencarian/filter/sort.
- Rutinitas dengan target fleksibel, riwayat dan timer Start/Pause/Stop.
- Smart Scheduling: saran slot, pembagian sesi, batas minimum/maksimum, penyelesaian konflik, validasi dan konfirmasi pengguna.
- Pengulangan kegiatan dengan edit/hapus per kejadian/kejadian ini dan berikutnya/semua.
- Pengingat lokal, jam tenang, izin notifikasi, indikator fallback di dalam aplikasi.
- Statistik harian/mingguan/bulanan dengan filter kategori dan perbandingan periode.
- Kategori bersama, Tempat Sampah 30 hari, backup/restore manual terenkripsi.
- Seluruh layar, formulir, dialog, empty/loading/error/permission/conflict states harus diprototipe sebelum tahap implementasi fitur.

> **Catatan prioritas:** Seluruh fitur di atas telah dipilih untuk spesifikasi produk; **urutan pengembangan dan batas rilis pertama belum dikunci**. Implementasi dapat dilakukan bertahap tanpa menghapus requirement dari dokumen ini.

### 3.2 Tidak termasuk MVP offline

- Login/registrasi online dan sinkronisasi antarperangkat.
- Backend milik sendiri atau kebutuhan server yang dikelola sendiri.
- Integrasi API cloud untuk sinkronisasi otomatis; ekspor ke Drive/iCloud lewat fasilitas sistem **bukan sinkronisasi**.
- Kolaborasi jadwal dan berbagi akun.
- Lampiran file/gambar pada kegiatan.
- Input Quick Add dengan bahasa alami.
- Mode gelap sebagai variasi tema desain.
- Streak dan tren durasi rutinitas tingkat lanjut (belum dipilih).
- Tugas berulang sebagai entitas To-Do berulang (belum dipilih pada wawancara fitur tugas).

### 3.3 Fase sesudah MVP

- Akun email dan password, backend terkelola, sinkronisasi cloud, strategi migrasi database lokal, penyelesaian konflik perangkat, kebijakan keamanan dan privasi produksi. Pemilihan vendor/backend masih **OPEN**.

### 3.4 Kanal distribusi Android (CONFIRMED · Fase 19)

Routina didistribusikan melalui landing page resmi dengan download universal signed APK secara langsung dan pembaruan manual. Google Play bukan target fase persiapan ini. Aplikasi tetap offline-first. Identitas publik, signing key pemilik, ikon/splash final, metadata privasi dan kontak tetap memerlukan keputusan atau bukti sebelum rilis; persiapan teknis tidak mengizinkan publikasi. Lihat [persyaratan distribusi](docs/ANDROID_DISTRIBUTION.md).

## 4. Alur utama dan arsitektur informasi

### 4.1 Pertama kali memakai aplikasi

`Splash → Onboarding → Profil lokal & preferensi jam aktif → Dashboard Home`.

Tidak ada login atau kewajiban koneksi internet. Profil dan preferensi disimpan lokal. Pengguna dapat mengatur jam aktif berbeda pada setiap hari, waktu pilihan untuk workout (mis. pagi/sore), belajar (mis. siang/malam), dan kategori kegiatan lain.

### 4.2 Navigasi

Bottom navigation tetap **lima tab**: **Home, Kalender, To-Do List, Rutinitas, Profil**. Tombol tambah `(+)` mengambang membuka **Tambah Kegiatan / Tambah Tugas / Tambah Rutinitas**; masing-masing menawarkan Quick Add dan Form Lengkap. **Halaman Statistik** dituju dari Home, **bukan tab keenam**.

### 4.3 Alur menambah item

1. Tap `(+)` → pilih jenis item.
2. Pilih Quick Add atau Form Lengkap.
3. Pertahankan data yang sudah dimasukkan bila beralih dari Quick Add ke Form Lengkap.
4. Validasi field, waktu, bentrok dan buffer; tampilkan warning dan konfirmasi jika diperbolehkan.
5. Simpan lokal, jadwalkan ulang reminder yang relevan, perbarui tampilan dan agregasi.

**Field Quick Add wajib:**

| Jenis | Input minimal |
|---|---|
| Kegiatan | Judul, tanggal, waktu mulai, waktu selesai |
| Tugas | Judul, deadline |
| Rutinitas | Nama, jenis target, frekuensi |

Tidak ada default otomatis untuk field Quick Add yang belum diisi dan tidak ada parsing teks alami. Nilai baku/rentang validasi lebih rinci masih **OPEN**.

## 5. Model domain dan istilah

### 5.1 Entitas inti

| Entitas | Fungsi | Catatan |
|---|---|---|
| `LocalProfile` | Identitas tampilan lokal dan preferensi | Tidak membutuhkan akun |
| `Category` | Kategori bersama, ikon, warna | Referensi dari event/task/routine |
| `EventSeries` | Pola kegiatan berulang | Aturan recurrence dan zona waktu |
| `EventOccurrence` | Kejadian konkret, status hasil | Bisa memiliki pengecualian/override |
| `Task` | Pekerjaan dengan deadline dan prioritas | Deadline berbeda dari sesi pengerjaan |
| `Subtask` | Checklist tugas | Persentase otomatis, status utama manual |
| `WorkSession` | Blok kalender untuk mengerjakan Task | Mendukung durasi rencana dan durasi aktual terpisah |
| `Routine` | Kebiasaan dan definisi target | Checklist/durasi/jumlah/frekuensi |
| `RoutineOccurrence` | Target/kejadian rutin pada tanggal tertentu | Menghindari double-count dengan blok kalender |
| `TimeLog` | Durasi aktual input manual atau timer | Detail pencatatan tugas masih **OPEN** |
| `ReminderRule` | Jadwal pengingat | Menghormati izin dan Jam Tenang |
| `ActivityStatusHistory` | Rekam status dan keputusan | Menjaga riwayat kejadian asli |
| `TrashEntry` | Item yang dihapus secara lunak | Retensi 30 hari |
| `BackupManifest` | Metadata backup, versi skema | Tanpa membocorkan data sensitif |

Entitas merupakan *model konseptual*, bukan perintah menggunakan tabel/ORM tertentu. Identitas internal stabil dan unik wajib untuk merge backup, pengecualian recurring, serta deduplikasi KPI. Jangan mencocokkan identitas hanya berdasarkan judul.

### 5.2 Perbedaan penting

- **Deadline tugas** = batas waktu; **sesi pengerjaan** = waktu dialokasikan untuk bekerja.
- **Durasi terjadwal** ≠ **durasi aktual** ≠ **progres subtugas** ≠ **estimasi sisa pengerjaan**.
- **Berlangsung** = indikator jam, **Selesai/Ditunda/Dilewatkan** = hasil yang dikonfirmasi pengguna.
- **Jam aktif** = batas rekomendasi Smart Scheduling; **Jam Tenang** = kebijakan notifikasi.
- **Kegiatan all-day Sibuk** = memblokir hari; **all-day Tersedia** = informasi saja.
- **Item di Tempat Sampah** ≠ item aktif.

## 6. Requirement fungsional

Setiap item berlabel **CONFIRMED**, kecuali yang ditandai **PROPOSED/OPEN**.

### FR-01: Home & KPI harian (CONFIRMED)

Home menunjukkan lima informasi: total aktivitas hari ini, aktivitas selesai, aktivitas belum selesai, persentase penyelesaian, kegiatan terdekat. Di bawahnya tampil daftar kegiatan hari ini. Sediakan daftar **Menunggu Konfirmasi** untuk event yang telah berakhir tetapi belum dikonfirmasi, serta entry point ke halaman Statistik.

**Aturan KPI harian:**

- Penyebut = seluruh aktivitas yang menjadi kewajiban hari tersebut: event terjadwal, task dengan deadline hari itu, dan rutinitas yang ditargetkan pada hari itu.
- Pembilang = hanya aktivitas berstatus **Selesai**.
- Ditunda dan Dilewatkan tetap ada dalam penyebut, tidak dianggap selesai.
- Dedup item terhubung: rutinitas yang muncul sebagai blok kalender dan task yang memiliki sesi kerja tidak boleh terhitung dua kali untuk kewajiban yang sama.
- Event lintas tengah malam dihitung **satu kali pada tanggal mulai**, meskipun tampak pada kedua tanggal kalender.
- Event yang ditunda tetap tercatat pada tanggal asal sebagai Ditunda dan dihitung dalam total hari asal. Sesi pengganti yang disetujui dihitung pada tanggal pelaksanaan baru, dengan deduplikasi bila terkait rutinitas yang sudah menjadi kewajiban hari tersebut. Riwayat asli tidak ditimpa.
- Hari dengan penyebut nol ditampilkan **Tidak Ada Aktivitas**, bukan 0% atau 100%.

**Penerimaan:** Dua representasi dari satu kewajiban tidak menaikkan total KPI; status berubah setelah konfirmasi; dashboard berfungsi offline.

### FR-02: Kalender (CONFIRMED)

- Tampilan **hari, minggu, bulan**, navigasi tanggal dan detail kegiatan.
- Menampilkan event, kegiatan sepanjang hari, rutinitas yang dijadwalkan, sesi pengerjaan, serta tanda deadline task.
- Event lintas tengah malam ditampilkan pada masing-masing tanggal yang dilintasi; KPI tetap pada tanggal mulai.
- Pengguna memilih hari pertama minggu **Senin atau Minggu**; ini juga memengaruhi batas target rutinitas dan statistik mingguan.
- Jika awal minggu diubah, **hitung ulang agregat historis** menurut pengaturan baru, tetapi jangan mengubah waktu, status, catatan, atau durasi aktual aktivitas.

### FR-03: Kegiatan & recurrence (CONFIRMED)

**Form lengkap kegiatan:** judul, deskripsi, tanggal/waktu mulai dan selesai, kategori/warna, lokasi opsional, pengulangan, pengingat, catatan tambahan, tautan opsional. Tidak perlu lampiran.

Pengulangan: harian, mingguan, bulanan, interval khusus seperti setiap dua minggu; dapat menetapkan tanggal mulai, tanggal akhir, atau tanpa akhir. Edit dan hapus kegiatan berulang memiliki cakupan:

1. Hanya kejadian ini.
2. Kejadian ini dan seluruh kejadian berikutnya.
3. Seluruh rangkaian.

Model harus mendukung pengecualian occurrence individual dan pemisahan series pada pilihan kedua. Perubahan harus menegaskan cakupan sebelum menyimpan. Event sepanjang hari dapat memiliki status ketersediaan **Sibuk** atau **Tersedia**; Sibuk memblokir seluruh hari pada conflict checking/Smart Scheduling, Tersedia tidak memblokir.

**Deteksi bentrok:** tampilkan penjelasan dan peringatan; penjadwalan manual yang bertabrakan dapat tetap disimpan setelah pengguna menyetujui. Setiap kegiatan bisa memiliki buffer sebelum/sesudah, plus default global yang bisa diubah. Smart Scheduling **wajib** mematuhi buffer; pelanggaran buffer dalam penjadwalan manual menghasilkan warning dan butuh konfirmasi.

### FR-04: Status kegiatan (CONFIRMED)

Status/indikator: **Belum Dimulai, Sedang Berlangsung, Selesai, Ditunda, Dilewatkan**. Sedang Berlangsung mengikuti jam mulai/selesai sebagai indikasi temporal; setelah selesai waktu, hasil kegiatan **tidak ditentukan otomatis**. Sistem meminta pengguna memilih Selesai/Ditunda/Dilewatkan.

Jika jam berakhir dan belum ada konfirmasi: tampilkan **Menunggu Konfirmasi** pada Home dan kirim pengingat dengan jumlah terbatas sesuai pengaturan. Jumlah pengulangan/interval default masih **OPEN**.

- **Ditunda:** tawarkan tanggal baru manual, Smart Scheduling, atau jadwalkan nanti. Tidak menghapus kejadian semula.
- **Dilewatkan:** pertahankan riwayat; tawarkan sesi pengganti manual/Smart Scheduling. Kejadian rutin berikutnya tidak berubah secara otomatis.
- Penjadwalan pengganti selalu dengan persetujuan pengguna.

### FR-05: To-Do List & subtugas (CONFIRMED)

Form lengkap: judul, deskripsi, deadline tanggal+jam, reminder, prioritas, kategori/daftar tugas, subtask/checklist, penanda overdue, serta integrasi deadline di kalender. Tugas tidak otomatis selesai hanya karena semua subtugas telah dicentang.

- Persentase subtask dihitung dari jumlah subtugas yang selesai dibanding total subtugas ketika total >0; kasus tanpa subtugas harus ditangani sebagai tidak ada persentase checklist (PROPOSED).
- **Tugas utama memerlukan konfirmasi Selesai** bahkan jika subtask 100%.
- Task dengan deadline terlewati dan belum selesai ditandai **Overdue**; reminder lanjut terbatas; opsi ubah deadline atau menjadwalkan sesi manual/Smart Scheduling, semuanya dengan persetujuan.
- **Ubah deadline** tidak otomatis memindahkan sesi pengerjaan, dan **pindah sesi** tidak otomatis mengubah deadline.
- Bila tugas utama selesai sementara masih ada sesi mendatang: tawarkan **Batalkan** atau **Pertahankan** sesi. Sesi yang sudah berlangsung dan riwayat sebelumnya tetap utuh.
- Sesi kerja dapat dibuat manual maupun melalui rekomendasi slot sebelum deadline.

**OPEN:** himpunan nilai prioritas, status lengkap tugas selain selesai/overdue, kebijakan task deadline dalam KPI apabila tanggal deadline diubah, waktu reminder default.

### FR-06: Rutinitas & timer (CONFIRMED)

- Rutinitas menampung target fleksibel: checklist, durasi, jumlah, dan frekuensi mingguan.
- Halaman Rutinitas menampilkan progres aktual, target, dan riwayat.
- Progres dapat dimasukkan **manual** atau melalui timer **Start/Pause/Stop**, khususnya belajar dan workout.
- Timer terus menghitung durasi meskipun aplikasi berada di background atau layar terkunci; state sesi/durasi harus dapat dipulihkan ketika aplikasi dibuka kembali.
- Ketika target durasi tercapai, kirim pemberitahuan sesuai izin dan aturan Quiet Hours; **jangan otomatis mengubah status aktivitas menjadi Selesai**.
- Durasi rencana tidak boleh langsung menjadi durasi aktual.
- Rutinitas dan blok kalender yang merepresentasikan kewajiban sama dideduplikasi saat KPI.

**OPEN:** perincian recovery timer setelah reboot/force stop, pencatatan durasi aktual khusus task work session (lihat pertanyaan wawancara berikutnya), hubungan satu target mingguan dengan beberapa kejadian harian.

### FR-07: Smart Scheduling (CONFIRMED)

**Tujuan:** merekomendasikan slot pekerjaan sebelum deadline berdasarkan (a) waktu kosong, (b) preferensi waktu pengguna menurut jenis aktivitas, (c) estimasi durasi, (d) deadline, (e) jam aktif harian, (f) buffer dan konflik, (g) all-day busy/free, (h) batas sesi.

**Aturan tak boleh dilanggar oleh rekomendasi:**

- Slot hanya berada dalam **jam aktif** hari bersangkutan.
- Slot tidak bertumpang tindih dengan interval Sibuk termasuk buffer.
- Slot pengerjaan task berakhir paling lambat sebelum deadline yang berlaku sesuai mode zona waktu task.
- Perubahan kalender terkini harus diperhitungkan ulang; jangan mengandalkan validitas rekomendasi lama.
- **Tidak ada penambahan/pemindahan/pembatalan jadwal otomatis tanpa persetujuan eksplisit.**
- Penjadwalan manual di luar jam aktif, berbenturan, atau melanggar buffer dapat dilakukan setelah warning dan konfirmasi, namun aturan pengecualian manual tidak mengizinkan Smart Scheduling menyarankan slot tak valid.

**Pembagian sesi:** Jika tidak ada satu slot cukup panjang, tawarkan beberapa sesi yang mencukupi total estimasi. Durasi minimum tiap sesi dan jumlah maksimum sesi dapat diubah per tugas, dengan nilai default global yang dapat diubah. Angka default belum diputuskan. Semua sesi disajikan untuk ditinjau sebelum simpan.

**Kegagalan rekomendasi:** jelaskan kendala spesifik, tawarkan memperkecil durasi minimum, meningkatkan jumlah maksimum sesi, atau penjadwalan manual. Perubahan batasan tidak otomatis; deadline tidak boleh bergeser diam-diam.

**Konflik muncul setelah sesi disimpan:** deteksi dan tandai; tawarkan rekomendasi baru atau edit manual. Pengguna dapat memilih menjadwalkan ulang **hanya sesi bentrok** atau **seluruh sesi mendatang**. Sesi terlaksana beserta riwayat tidak berubah.

**Estimasi sisa pengerjaan:** Setelah sebagian pengerjaan dicatat, usulkan estimasi awal dikurangi durasi aktual, lalu pengguna boleh mengoreksi dan **wajib mengonfirmasi** sisa estimasi sebelum rekomendasi berikutnya. Angka ini **bukan persentase kemajuan tugas aktual**.

**Selisih dengan sesi mendatang (Q80):** Jika total durasi sesi belum terlaksana kurang/lebih dari sisa estimasi yang telah dikonfirmasi, tampilkan selisih dan opsi: tambahkan/kurangi sesi, optimasi ulang semua sesi mendatang, atau **pertahankan rencana saat ini**. Setiap perubahan memerlukan persetujuan; mempertahankan rencana dapat meninggalkan selisih yang ditampilkan jelas. Riwayat terlaksana tidak ditimpa; deadline tetap.

**Alur contoh algoritmik (konsep, bukan implementasi final):**

```text
Input: task, estimasiSisaDisetujui, deadlineAktif, jamAktifPerHari,
       preferensiJenis, eventSibuk, buffer, batasMinSesi, batasMaxSesi
1. Bangun interval waktu kandidat di jam aktif hingga deadline.
2. Kurangi interval Sibuk dan buffer masing-masing kegiatan.
3. Prioritaskan waktu sesuai preferensi pengguna.
4. Cari satu sesi yang memuat estimasiSisaDisetujui.
5. Jika tidak ada, cari kombinasi <= batasMaxSesi, tiap sesi >= batasMinSesi,
   total sesi mencukupi estimasi, dan seluruhnya sebelum deadline.
6. Jika tidak ada solusi, tampilkan alasan/batasan yang gagal beserta opsi revisi.
7. Tampilkan proposal tanpa mengubah database.
8. Setelah persetujuan, validasi ulang terhadap kalender terkini lalu simpan atomik.
```

**Penerimaan kritis:** tidak membuat double booking rekomendasi, tidak berpindah otomatis saat konflik, tidak memotong deadline/riwayat, hasil deterministik untuk set input yang sama; pembuatan sesi menolak proposal yang sudah stale dan menawarkan refresh.

### FR-08: Notifikasi, pengingat, dan Jam Tenang (CONFIRMED)

Jenis: pra-kegiatan (beberapa reminder dengan waktu dapat diatur), saat mulai, ringkasan pagi, deadline tugas, bentrok jadwal, snooze, reminder rutinitas, target timer, dan pengingat konfirmasi terbatas setelah akhir kegiatan.

- Minta permission saat dibutuhkan, bukan memblokir onboarding/MVP.
- Jika ditolak/dinonaktifkan, aplikasi tetap dapat digunakan, tampilkan indikator status dan pengingat tertunda/yang relevan dalam dashboard saat aplikasi dibuka; sediakan jalan ke Pengaturan Notifikasi sistem.
- Quiet Hours memiliki jam mulai/selesai pengguna dan pengecualian berdasarkan jenis reminder. Pengaturan berbeda per hari **tidak dipilih**.
- Pengecualian Quiet Hours aplikasi **tidak mengesampingkan** izin notifikasi atau DND/Focus sistem.
- Ada batas jumlah reminder konfirmasi. Nilai, interval, default dan perlakuan reminder yang terlewat selama Quiet Hours masih **OPEN**.
- Sistem operasi dapat membatasi ketepatan/eksekusi notifikasi lokal; verifikasi kebijakan platform dan permission sebelum production.

### FR-09: Kategori, pencarian dan filter (CONFIRMED)

- Kategori bersama lintas kegiatan, task, rutinitas; CRUD nama/ikon/warna.
- Saat hapus kategori, minta pengguna memilih **pindahkan seluruh item terkait ke kategori pengganti** atau **Tanpa Kategori**. Item aktivitasnya tidak dihapus.
- Cari berdasarkan judul; filter tanggal, kategori, status, prioritas; sort waktu kegiatan, deadline, atau prioritas. Filter hanya ditampilkan untuk entitas yang mendukung field terkait.

### FR-10: Statistik dan riwayat (CONFIRMED)

Halaman Statistik dibuka dari Home. Tampilkan:

- Harian, mingguan, bulanan dengan grafik dan riwayat.
- KPI keseluruhan, rincian kegiatan vs task vs rutinitas; filter kategori bersama.
- Perbandingan otomatis dengan periode sebelumnya dan pilihan periode pembanding manual. Tidak perlu rentang tanggal bebas.
- Untuk periode **sedang berjalan**, bandingkan periode sebelumnya dengan **durasi kalender yang setara**. Jelaskan kedua rentang dengan label jelas.
- Hari tanpa aktivitas tampil sebagai **Tidak Ada Aktivitas**, tanpa persentase, dan tidak masuk rata-rata persentase harian.
- Statistik mingguan/bulanan menampilkan **dua metrik terpisah**:
  1. **KPI utama:** total aktivitas Selesai / total aktivitas pada periode itu.
  2. **Metrik sekunder:** rata-rata persentase penyelesaian dari hari-hari yang memiliki aktivitas.
- Perubahan awal minggu menghitung ulang pengelompokan seluruh statistik historis, tanpa mengubah data aktivitas.

**Contoh:** Hari Senin 1/1 (100%) dan Selasa 2/10 (20%) → KPI utama 3/11 (27,3%); rata-rata persentase harian 60%. Dua metrik harus diberi label berbeda.

**OPEN:** penanganan pembanding bulan dengan panjang berbeda, detail batas periode berjalan (jam saat ini vs tanggal), aturan statistik historis saat deadline berpindah lintas hari, retensi statistik saat aktivitas dihapus permanen, perlakuan kategori yang diganti terhadap filter riwayat.

### FR-11: Zona waktu & awal minggu (CONFIRMED)

- Mode waktu aktivitas fleksibel per jenis dan dapat dipilih untuk tiap aktivitas. Kegiatan dapat mempertahankan zona asal; rutinitas dapat mengikuti jam lokal perangkat.
- Deadline task juga fleksibel per tugas, **default mempertahankan zona waktu asal**, opsi mengikuti jam lokal.
- Notifikasi, overdue, event berulang, kegiatan lintas hari, tampilan kalender, dan Smart Scheduling konsisten dengan mode zona waktu yang dipilih.
- Simpan identitas zona waktu IANA jika sesuai, serta instant dan informasi lokal yang diperlukan untuk recurrence. **PROPOSED:** penggunaan `Asia/Jakarta` dan bukan hanya offset `UTC+7`.
- Hari pertama minggu Senin atau Minggu dapat dipilih. Default awal belum diputuskan.

### FR-12: Tempat Sampah (CONFIRMED)

- Hapus kegiatan/task/rutinitas menjadi soft-delete dan masuk **Tempat Sampah 30 hari**.
- Dalam jendela retensi, pengguna dapat memulihkan atau menghapus permanen.
- Tombol Undo sesaat setelah hapus **tidak dipilih**.
- Item Trash tidak memblokir kalender, memicu notifikasi, atau dihitung sebagai aktivitas aktif/KPI.
- Saat restore item, periksa konflik baru, referensi kategori dan hubungan event/task/routine.
- **OPEN:** kapan tepatnya expiry 30 hari berjalan, kebijakan purge otomatis, perilaku jika parent–child terhapus parsial dan pilihan riwayat KPI setelah delete.

### FR-13: Backup & restore manual (CONFIRMED)

- Ekspor data lokal ke file terenkripsi **menggunakan password yang dipilih saat ekspor**; restore memerlukan password yang sama.
- Tujuan ekspor fleksibel: folder perangkat, Share Sheet Android/iOS, atau aplikasi cloud yang tersedia (Drive/iCloud Drive) via file picker/share system. **Bukan** integrasi sinkronisasi cloud aplikasi.
- Restore menawarkan **Ganti Semua** atau **Gabungkan** data.
- Merge memakai ID stabil; untuk dua versi berbeda dari entitas yang sama, tampilkan perbandingan konflik dan pengguna memilih versi yang dipertahankan. Item yang kebetulan memiliki judul sama tetapi ID berbeda tidak boleh digabung otomatis.
- Ingatkan backup manual setiap 7/14/30 hari, jadwal khusus, atau off; frekuensi dapat diubah. Default frekuensi belum diputuskan.
- Password hilang berpotensi membuat backup tidak bisa dipulihkan, dan aplikasi harus menjelaskannya. Tidak boleh menjanjikan recovery password.

**Security acceptance criteria:** enkripsi terautentikasi standar industri, derivasi kunci dari password dengan KDF teruji, salt/nonce unik, format berversi, validasi integritas sebelum restore, penanganan password salah vs file rusak yang tidak membocorkan informasi sensitif, password tidak dicatat di log atau disimpan plaintext, operasi restore atomik/rollback, dan pengujian kompatibilitas backup di Android/iOS. Pilihan algoritma/KDF/parameter memerlukan security review: **OPEN, bukan keputusan fitur**.

**Pencegahan kehilangan data:** tampilkan ringkasan aksi Ganti Semua vs Gabungkan, minta konfirmasi risiko penggantian, dan lakukan validasi penuh file sebelum perubahan data. Sediakan backup safety sebelum replace jika implementasinya memungkinkan (**PROPOSED**).

## 7. Aturan global dan invariants

1. **Explicit user approval**: semua mutasi rekomendasi Smart Scheduling, pengubahan deadline, pelanggaran aturan manual, reassign kategori, dan pilihan konflik restore tidak boleh di-commit tanpa aksi pengguna yang tepat.
2. **No fabricated completion**: timer, berakhirnya jam, mencapai target subtugas, dan berlalu deadline tidak otomatis menandai Selesai.
3. **Single source of truth**: satu kewajiban dapat tampil pada beberapa halaman tetapi KPI harus dedup melalui ID keterkaitan.
4. **Historical immutability**: kejadian yang sudah selesai/dilewatkan/ditunda dan time log aktual tidak diubah oleh rescheduling masa depan.
5. **Time zone correctness**: simpan waktu dan mode zona sehingga tampilan mengikuti konfigurasi pengguna tanpa diam-diam menggeser deadline mode zona asal.
6. **Recurrence safety**: edit satu occurrence tidak memutasi seluruh series; edit "ini dan berikutnya" memisahkan rangkaian dengan identitas/relasi yang jelas.
7. **Offline usability**: fungsi inti tidak bergantung pada server. Fitur file sharing bergantung fasilitas sistem/aplikasi tersedia, bukan koneksi backend produk.
8. **Permission resilience**: aplikasi tetap berfungsi bila push/local notification permission ditolak; aplikasi tidak menjanjikan notifikasi OS dalam kondisi itu.
9. **Trash isolation**: konten soft-deleted tidak aktif dalam reminder, pencarian aktif, rekomendasi atau KPI.
10. **Backup safety**: tidak ada kehilangan data diam-diam saat restore; konflik merge dan replace harus eksplisit.

## 8. Data architecture & strategi implementasi (PROPOSED)

Pilihan berikut *usulan teknis untuk dievaluasi oleh Codex*, bukan keputusan wawancara:

- Lapisan Flutter: `presentation → application/use cases → domain → repositories → storage/services`.
- Database lokal transaksional dan terindeks untuk event/rules/occurrences/tasks/routines/session logs. Pilihan SQLite/Drift/Isar/Hive **belum diputuskan**, verifikasi maintenance dan kompatibilitas terakhir sebelum menetapkan.
- Event recurrence disimpan sebagai rule + exception; occurrence dihitung/dimaterialisasi secara terbatas dengan cache agar seri tanpa batas tidak menyebabkan operasi tak berhingga.
- Scheduling diisolasi sebagai layanan/domain murni yang dapat diuji tanpa UI, menerima snapshot kalender dan menghasilkan proposal, bukan menulis data langsung.
- Gunakan transaksi lokal ketika commit beberapa sesi atau restore; validasi ulang snapshot agar tidak menimpa jadwal baru.
- Timer menyimpan waktu mulai/titik pause, durasi terakumulasi, dan checkpoint agar durasi bisa direkonstruksi saat aplikasi kembali. Uji reboot/pergantian waktu manual/DST.
- Sistem notifikasi: adaptor platform yang mengelola permissions, rescheduling reminder, dan fallback dalam aplikasi. Jangan mengandalkan eksekusi background terus-menerus.
- Statistik dihitung dari data sumber/riwayat; cache boleh digunakan tetapi invalidasi harus tepat terhadap perubahan kegiatan, zona waktu, kategori, awal minggu, trash, dan restore.
- Backup menggunakan skema ber-versi, checksum/integrity, dan migrasi skema yang teruji sebelum restore.

### 8.1 Sketsa relasi konseptual

```text
LocalProfile ── Preferences (activeHours, quietHours, reminders, weekStart, buffer)
Category ──< EventSeries/EventOccurrence
         ├──< Task ──< Subtask
         │         └──< WorkSession ──< TimeLog
         └──< Routine ──< RoutineOccurrence ──< TimeLog
EventSeries ──< EventOccurrence ──< OccurrenceOverride
Activity* ──< ReminderRule
Activity* ──< ActivityStatusHistory
Activity* ──< TrashEntry
BackupManifest + EncryptedData + VersionedSchema
```

### 8.2 ID dan relasi yang perlu dipertahankan

- ID UUID/identifier stabil untuk series, instance, task, session, routine, time log, category.
- Link antara `WorkSession.taskId` dan `RoutineOccurrence`/representasi kalender untuk deduplikasi.
- Tombstone untuk delete/merge agar item yang sudah dihapus tidak muncul kembali tanpa pilihan user.
- Status punya timestamp, dan bila ada reschedule, link dari occurrence/sesi lama ke pengganti.

## 9. UI/UX dan desain

Spesifikasi visual detail ada pada [`DESIGN.md`](./DESIGN.md), menjadi rujukan implementasi prototipe design-first.

- Tema **Balanced Neobrutalism**.
- Palet: Biru `#537BFF`, Kuning `#FFE65B`, Coral `#FF8C82`, Krem `#F5F2E9`, Hitam `#171717`.
- Flat colors, garis 2–3px, hard offset shadow tanpa blur, headline tebal, geometri cenderung kotak.
- Terapkan elemen brutalist pada KPI, primary CTA, kartu penting dan heading; buat form, kalender, dan daftar tetap bersih, padat data terbaca.
- Tidak membuat dark mode saat ini.
- Semua halaman, form, dan state penting diprototipe termasuk empty, loading, error, overlap/buffer warning, pending confirmation, overdue, backup replace/merge/conflicts, permission declined.

## 10. State, error, dan edge-case wajib diuji

| Skenario | Hasil diharapkan |
|---|---|
| Event selesai waktunya, status belum dikonfirmasi | Pending confirmation, tidak otomatis Selesai |
| Event berulang diedit satu occurrence | Kejadian lain tidak berubah |
| Edit "ini dan berikutnya" | Pisah series, historis awal utuh |
| Event all-day Sibuk | Menutup slot hari itu |
| Event all-day Tersedia | Tidak menutup slot |
| Manual event melanggar buffer/jam aktif | Warning + confirm sebelum simpan |
| Smart Scheduling tidak menemukan slot tunggal | Menawarkan pembagian sesi |
| Tidak ada pembagian memenuhi constraint | Jelaskan constraint, minta tindakan pengguna |
| Perubahan kalender bentrok dengan work session | Tandai dan tawarkan replan dengan persetujuan |
| Tugas selesai dengan sesi masa depan | Prompt batalkan/pertahankan sesi |
| Work session mendatang kurang dari sisa estimasi | Tampilkan selisih dan opsi, bukan auto-mutate |
| Work session mendatang lebih dari sisa estimasi | Tawarkan kurangi/optimasi/pertahankan |
| Subtask 100% | Task belum otomatis Selesai |
| Task lewat deadline | Overdue, reminder terbatas, opsi tindak lanjut |
| App dihentikan saat timer berjalan | Rekonstruksi state/durasi secara aman saat dibuka |
| Izin notifikasi ditolak | UI tetap berfungsi dan fallback dashboard |
| Quiet Hours aktif | Kirim hanya tipe yang diizinkan, sesuai OS permission |
| Kalender memakai zona waktu berbeda | Deadline fixed-origin dan floating-local dibedakan |
| Event lintas hari | Tampil dua hari, dihitung KPI sekali pada hari mulai |
| Hari tanpa aktivitas | Tampilkan Tidak Ada Aktivitas, keluarkan dari rata-rata harian |
| Awal minggu berubah | Hitung ulang agregat, riwayat tidak berubah |
| Hapus kategori | Reassign/uncategorized, bukan hapus aktivitas |
| Hapus event/task/routine | Pindah ke Trash 30 hari, nonaktif reminder/blocker |
| Restore file salah password/rusak | Tolak tanpa mengubah data lokal |
| Merge dua versi ID sama | Dialog banding versi, pengguna memilih |
| Merge judul sama, ID berbeda | Tetap dua entitas kecuali user memilih lain |
| Replace restore gagal setengah jalan | Rollback, data awal tetap valid |
| Backup ke Share Sheet/cloud app | File tetap dienkripsi, bukan sync produk |

## 11. Persyaratan nonfungsional dan batasan produksi

### 11.1 Keandalan & performa

- Fungsi inti tersedia offline setelah instalasi.
- Penyimpanan dan restore tahan kegagalan; mutasi kompleks atomik.
- Rendering kalender recurrence tak terbatas harus memiliki window pagination/lazy expansion.
- Perubahan skema data menggunakan migrasi dan pengujian versi backup.
- Tidak mengubah data pengguna hanya untuk memperbaiki angka statistik tanpa jejak/audit yang sesuai.

### 11.2 Keamanan & privasi

- Default data berada di perangkat. Jangan memasukkan konten kegiatan/tugas ke analytics pihak ketiga tanpa keputusan privasi terpisah.
- Password backup tidak pernah disimpan plaintext dan dihindarkan dari log/crash report.
- Enkripsi file menggunakan primitive standar teruji; keamanan format diperiksa independen sebelum production.
- Jika password hilang, jangan menjanjikan mekanisme recovery yang belum ada.
- Akses folder/files dan share harus mengikuti izin platform serta user initiation.

### 11.3 Aksesibilitas

- Kontras teks terhadap warna flat harus diuji WCAG, jangan gunakan warna sebagai satu-satunya indikator status.
- Semua CTA minimum sentuh yang layak; screen-reader labels dan urutan fokus; skala font, dynamic text dan overflow.
- Kontrol waktu/tanggal tidak boleh hanya gestur; semua peringatan punya penjelasan tekstual.
- Siapkan lokalisasi bahasa/tanggal/zona waktu. Bahasa final UI belum diputuskan, namun draf memakai Bahasa Indonesia.

### 11.4 Android/iOS

- Periksa izin notifikasi, batas penjadwalan pengingat, file picker/Share Sheet, timer background/recovery, dan penanganan file cloud masing-masing platform.
- Tidak menjamin 100% notifikasi tepat waktu saat OS membatasi background atau izin ditolak.
- Perilaku tombol back, modal sheet, safe area, keyboard dan lifecycle mengikuti platform dengan identitas visual produk konsisten.

## 12. Kriteria penerimaan tingkat produk

1. Instalasi baru selesai onboarding dan masuk Home tanpa login dan internet.
2. Pengguna dapat Quick Add ketiga jenis aktivitas dan menyelesaikan form lengkap tanpa kehilangan isian.
3. Kalender harian/mingguan/bulanan konsisten dengan task deadline, all-day, recurrence dan waktu lintas tengah malam.
4. Warning manual dan penjadwalan rekomendasi bekerja sesuai aturan jam aktif/buffer/conflict.
5. Kegiatan, task dan rutinitas tidak dinyatakan Selesai otomatis karena waktu/progres subtugas.
6. Smart Scheduling mendeteksi solusi/tidak solusi dan tidak mengubah apa pun tanpa consent.
7. Statistik sejalan dengan rumus KPI, zero-activity day, perbandingan setara, dan dedup.
8. Trash recovery, kategori reassign, dan restore merge tidak menghapus aktivitas tak terkait.
9. Backup terenkripsi dapat diuji end-to-end dengan password benar/salah dan file korup.
10. Semua layar dan state di `DESIGN.md` siap dieksekusi menjadi prototype sebelum tahap implementasi data nyata.

## 13. Urutan pekerjaan yang disarankan (PROPOSED)

**Fase D0: Prototipe lengkap lebih dahulu** → semua screen, form, modal, edge-state menggunakan data contoh, validasi UX/flow.  
**Fase I1: Fondasi offline** → navigation, onboarding, profil/preferensi, storage migration, kategori.  
**Fase I2: Kegiatan/kalender/status/reminders** → CRUD, recurrence, conflicts, pending confirmation.  
**Fase I3: To-Do/WorkSession/Rutinitas** → subtugas, deadline, time logs/timer, frequency goals.  
**Fase I4: Smart Scheduling** → suggestion engine, splitting, replan, mismatch handling.  
**Fase I5: Statistik/backup/trash** → analytics, encrypted export/import, merge conflicts, recycle bin.  
**Fase I6: Hardening** → Android/iOS validation, performance, accessibility, security, QA.  
**Future:** akun, backend, multi-device sync.

Urutan ini bisa diubah setelah review; bukan izin untuk menghapus fitur yang disepakati.

## 14. Keputusan yang masih terbuka (OPEN QUESTIONS)

Kumpulan ini adalah **isu implementasi yang perlu keputusan/review**, bukan pengganti requirement yang sudah final:

1. **Pelacakan durasi aktual task work session:** metode input manual, timer, atau keduanya; relasi dengan riwayat time log (calon pertanyaan 81).
2. **Nilai default** minimum menit tiap sesi, maksimum jumlah sesi, buffer sebelum/sesudah, jam aktif awal, pengingat backup, interval reminder konfirmasi, jam Quiet Hours, hari pertama minggu.
3. Data profil lokal wajib/opsional, format waktu, bahasa dan lokalisasi, nilai prioritas, batas kategori.
4. Rincian waktu recurrence saat DST/perjalanan, all-day di lintas zona, serta overlapping interval across-midnight.
5. Spesifikasi restore kategori hilang, tombstone, backup older schema, penyelesaian konflik parsial, dan konsistensi relasi antarentitas.
6. Kebijakan purge 30 hari, konsekuensi restore item dari trash, dan snapshot riwayat statistik setelah penghapusan permanen.
7. Definisi task overdue jika deadline digeser, dampak pada KPI asal dan histori sebelum perubahan.
8. Ketentuan waktu pelaksanaan reminder yang jatuh pada Quiet Hours dan OS-specific scheduler feasibility.
9. Algoritma ranking slot, tie-breaker, toleransi atas-/kurang durasi pembagian, penanganan slot lebih panjang yang sengaja dipertahankan.
10. Jenis ikon/font final, radius, breakpoint, desain detail UI untuk landscape/tablet.
11. Pilihan paket Flutter serta DB lokal, algoritma enkripsi/KDF/backup, dan strategi pengujian lintas OS perlu verifikasi aktual sebelum finalisasi arsitektur produksi.
12. Skema rilis prioritas implementasi: prototipe seluruh halaman disetujui, namun fitur implementasi bertahap memerlukan acceptance gates.

## 15. Catatan keputusan dan aturan revisi

- Dokumen ini merekam **keputusan produk sampai pertanyaan 80**, bukan dokumentasi aplikasi yang sudah dibangun.
- Pertanyaan 67 memutuskan melanjutkan discovery detail sebelum dokumen dibuat. Pada jawaban pertanyaan 80, pengguna **mengubah instruksi** dan meminta mulai membangun dokumen sekarang. Draf ini memenuhi instruksi terbaru; discovery tetap berlanjut sambil memperbarui dokumen.
- Jangan menulis jawaban atas OPEN sebagai confirmed tanpa persetujuan pengguna.
- Setelah wawancara berikutnya, perbarui `PRD.md` **dan** `DESIGN.md` apabila keputusan berdampak pada tampilan atau flow, serta catat ID/nomor pertanyaannya.

### Ringkasan pelacakan keputusan

| Topik | Nomor wawancara terkait |
|---|---|
| Product goals, jenis aktivitas, kalender, reminder | 1–10 |
| Visual/navigation, to-do, smart slot & onboarding | 11–20 |
| Backup, recurrence, form kegiatan, status, rutinitas/timer | 21–32 |
| Restore, design-first, neobrutalism, Quick Add, kategori & pencarian | 33–43 |
| KPI, all-day, buffer, kegiatan lintas hari, keamanan backup | 44–51 |
| Reminder backup, lokasi file, izin, Quiet Hours, overdue, subtask, trash | 52–59 |
| Statistik historis, perbandingan, hari kosong, rumus agregasi | 60–66 |
| Waktu dokumen, zona waktu, awal minggu, rescheduling | 67–72 |
| Pembagian sesi dan penanganan constraint, konflik, sisa durasi | 73–80 |

---

**Dokumen berikutnya untuk dipakai Codex + FigCraft:** buka [`DESIGN.md`](./DESIGN.md) untuk token desain, peta layar, komponen, dan state spesifik. Implementasi tidak boleh menganggap keputusan OPEN sudah final.
