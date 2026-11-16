# DESIGN.md

# Design System & UI/UX Specification: Aplikasi Perencana Aktivitas Personal

> **Status:** Draf kerja v0.1, berdasarkan keputusan wawancara pertanyaan 1–80 (15 November 2026).  
> **Platform:** Flutter Android & iOS. **Tema:** Balanced Neobrutalism, light-only pada MVP.  
> **Workflow:** Design-first. Buat dan review prototipe **seluruh halaman, formulir, dialog dan state** melalui Codex + FigCraft sebelum implementasi fungsi.  
> **Rujukan perilaku:** [`PRD.md`](./PRD.md). Jika terjadi konflik detail perilaku, gunakan keputusan produk PRD; perbarui kedua dokumen setelah ada keputusan baru.  
> **Status keputusan:** **CONFIRMED** = dipilih pengguna. **PROPOSED** = panduan rancangan kerja, masih dapat direvisi. **OPEN** = belum diputuskan. Jangan menyulap usulan menjadi persyaratan final tanpa persetujuan.

## 1. Visi pengalaman dan prinsip desain

Aplikasi menghadirkan kendali atas waktu dengan visual kuat, mudah dikenali, tetapi tetap efisien membaca data kalender dan tugas yang banyak. Estetika **Balanced Neobrutalism** dipilih, bukan neobrutalism yang ekstrem pada setiap elemen.

**Prinsip UX (CONFIRMED dari keputusan produk):**

1. **Satu dashboard, tiga jenis kewajiban**: kegiatan, To-Do List, rutinitas terintegrasi, tetapi tiap item tetap punya atribut dan aksi berbeda.
2. **Rekomendasi tidak sama dengan tindakan**: setiap saran Smart Scheduling harus ditinjau/disetujui; perubahan tidak pernah diam-diam.
3. **Kemajuan nyata, bukan tebakan**: durasi aktual, status akhir, dan subtask progress tidak dicampur.
4. **Konsistensi waktu**: deadline, zona waktu, recurrence, sesi lintas hari dan awal minggu divisualkan jelas.
5. **Warna mendukung pemindaian**: biru/kuning/coral untuk perhatian dan hierarki, bukan seluruh latar sekaligus.
6. **Pemulihan sebagai bagian UX**: trash 30 hari, konflik restore, overdue, permission denied dan penanganan jadwal bermasalah merupakan layar kelas satu.
7. **Offline-by-default**: tidak menampilkan CTA login/cloud sync di MVP; backup berbasis file dengan enkripsi password.

**Referensi:** pengguna memilih inspirasi dari gambar UI planner yang pernah dibagikan untuk struktur kalender, event card, onboarding, floating (+), dan bottom navigation. Gunakan konsepnya, **jangan menyalin palet lembut**. Rujukan visual neobrutalism: https://neubrutalism.com/ . Jangan menganggap gambar asli tersedia sebagai asset repo apabila belum dilampirkan di proyek.

## 2. Design tokens

### 2.1 Palet utama (CONFIRMED)

| Token | Hex | Fungsi yang disarankan |
|---|---|---|
| `color.blue` | `#537BFF` | Aksi utama, kartu KPI tertentu, seleksi kalender, progress |
| `color.yellow` | `#FFE65B` | Highlight, informasi penting, floating add, tindakan positif non-status |
| `color.coral` | `#FF8C82` | Peringatan bentrok/overdue dan aksen |
| `color.cream` | `#F5F2E9` | Kanvas utama, latar halaman |
| `color.ink` | `#171717` | Outline, teks utama, shadow keras |

Warna terpilih **bukan berarti setiap komponen harus memakai semua warna**. Gunakan distribusi visual seimbang. Warna lain seperti putih, abu muda/abu sedang, hijau status dan red error dapat dipakai sebagai token semantik pelengkap **PROPOSED** jika dibutuhkan aksesibilitas.

### 2.2 Kontras warna (hasil pemeriksaan matematis, patut diterapkan)

Kontras perkiraan sRGB terhadap `#171717`: blue 4,82:1, yellow 14,28:1, coral 7,96:1, cream 16,02:1. Putih terhadap blue 3,72:1 (di bawah 4,5:1 untuk teks normal), terhadap yellow 1,26:1, terhadap coral 2,25:1. **Gunakan teks `#171717` di atas biru/kuning/coral untuk teks ukuran normal**, terutama komponen penting; teks putih di atas `#171717` aman. Teks besar/bold di atas biru putih mungkin punya batas lain, tetapi default yang konsisten adalah ink pada warna aksen.

Status tidak boleh ditandai hanya berdasarkan warna. Berikan ikon dan kata **Selesai, Ditunda, Dilewatkan, Overdue, Bentrok, Menunggu Konfirmasi**.

### 2.3 Bentuk, border, shadow (sebagian CONFIRMED, angka rinci PROPOSED)

| Token | Nilai awal usulan | Penjelasan |
|---|---|---|
| `border.default` | 2px solid `#171717` | Input utama, kartu, CTA |
| `border.emphasis` | 3px solid `#171717` | Hero KPI/primary action |
| `shadow.hard.sm` | offset 2px 2px, blur 0 | Chips/kartu kecil |
| `shadow.hard.md` | offset 4px 4px, blur 0 | Kartu utama/CTA |
| `radius.sm` | 6px | Badge/input kecil |
| `radius.md` | 10px | Card/list/form |
| `radius.lg` | 14px | Bottom sheet, dialog |
| `spacing.unit` | 4px | Sistem 4/8/12/16/24/32 |
| `touch.min` | setidaknya 44–48dp | Target area sentuh tombol/interaksi |

Ciri **CONFIRMED:** outline tebal 2–3px, hard offset shadow tanpa blur, warna flat kontras, headline tebal, geometri cenderung persegi. Detail offset, radius, dan spacing di atas merupakan **starting point**, bukan keputusan wawancara.

### 2.4 Tipografi (PROPOSED)

- Font modern sans dengan bobot tebal untuk judul/angka KPI, body normal yang mudah dibaca. Pilihan keluarga font **OPEN**, jangan mengasumsikan sudah memilih Poppins/Inter/Manrope.
- Skala awal: Display 28–32sp/700; H1 24sp/700; H2 20sp/700; H3 17sp/700; body 14–16sp/400–500; caption 12–13sp/500. Uji text scaling.
- Jangan pakai ALL CAPS untuk paragraf panjang; gunakan untuk badge pendek saja.
- Angka jam/angka statistik gunakan tabular figures agar alignment stabil.
- Format tanggal/jam disesuaikan lokalisasi; rancangan awal menggunakan `DD MMM YYYY` dan `HH.mm` (PROPOSED).

### 2.5 Motion, feedback, dan suara (PROPOSED)

- Transisi singkat, sederhana, tidak mengaburkan state data atau menyamarkan perubahan jadwal.
- Loading menampilkan skeleton ringan atau progress jelas; jangan animasi berlebihan.
- Confirm success menunjukkan hasil dan state kalender terbaru.
- Jadwal rekomendasi **tidak boleh tampak seolah telah disimpan** sebelum pengguna mengonfirmasi.
- Haptic/audio tidak wajib; hormati pengaturan aksesibilitas dan OS.

## 3. Grid, komposisi dan komponen global

### 3.1 Layout aplikasi

- Kanvas `color.cream`; page header jelas dengan judul dan aksi kontekstual.
- Safe area Android/iOS, keyboard avoidance, state saat tombol back/gesture, font besar dan screen reader.
- Rancangan utama smartphone portrait; tablet/landscape dapat menjadi adaptasi **OPEN**. Jangan memaksakan dua kolom pada layar sempit.
- Bottom nav lima tab permanen: **Home**, **Kalender**, **To-Do List**, **Rutinitas**, **Profil**; icon + teks. Floating `(+)` diposisikan dengan aman tanpa menutupi tab/scroll/list. Komposisi khusus tab dan FAB masih PROPOSED.
- Halaman Statistik dibuka dari Home sebagai halaman turunan dengan tombol back, **bukan tab keenam**.

### 3.2 Component inventory

| Komponen | Varian/state wajib | Pemakaian |
|---|---|---|
| `AppHeader` | default, back, action, notification indicator | Semua halaman |
| `BottomNav` | 5 destination, active/inactive | Navigasi utama |
| `FABAdd` | idle, expanded, disabled modal | Tambah tiga jenis item |
| `NeoButton` | primary, secondary, danger, disabled, loading | Form, confirm, backup |
| `NeoCard` | plain, highlighted, warning, selected | KPI, kegiatan, rekomendasi |
| `KpiTile` | nilai, label, zero-state, tap | Home |
| `ActivityCard` | category, datetime, status, conflict, recurrence | Kalender/Home |
| `TaskCard` | due, overdue, priority, subtasks, session count | To-Do |
| `RoutineCard` | target, actual, progress, timer, missed | Rutinitas |
| `StatusBadge` | pending, active, completed, postponed, skipped, overdue, conflicted | Semua |
| `CategoryChip` | selected, unselected, color+icon, no category | Filter dan form |
| `DateTimePicker` | timezone label, all-day, repeated | Input jadwal |
| `RecurrencePicker` | daily/weekly/monthly/custom/end | Kegiatan |
| `ReminderEditor` | add multiple, quiet-hours hint | Form dan Pengaturan |
| `ConflictBanner` | hard overlap, buffer, outside active hours | Form dan kalender |
| `TimeSlotSuggestion` | valid, selected, changed/stale, unavailable | Smart Scheduling |
| `SessionPlanCard` | proposed, saved, conflict, cancelled, completed | Task work sessions |
| `ProgressBar` | task subtask %, routine actual, coverage | To-Do/Routine |
| `TimerPanel` | idle, running, paused, restored, goal reached | Rutinitas |
| `ComparisonChart` | day/week/month, no-data, partial-period | Statistik |
| `EmptyState` | per halaman, CTA relevan | Semua |
| `InlineNotificationWarning` | permission off, quiet hours, delivery unavailable | Home/Settings |
| `ConfirmDialog` | remove, save conflict, recurring scope, status, restore | Semua |
| `TrashItemCard` | remaining days, restore, delete permanent | Tempat Sampah |
| `PasswordField` | masked, strength help, visibility toggle | Backup/restore |
| `BackupConflictDiff` | local vs imported, per item selection | Restore merge |

**Aturan komponen:** outline tidak boleh membebani kalender/list padat. Gunakan border tebal pada *primary sections*, border/garis tipis yang konsisten di subelemen. Setiap kartu harus memisahkan informasi inti (judul, waktu, status) dari secondary metadata. Elemen yang terlihat interaktif harus memiliki action nyata pada prototipe/implementasi, bukan label dekoratif.

### 3.3 Hierarki prioritas visual

1. **Keselamatan keputusan:** warning bentrok, overdue, restore replace dan password.
2. **Aksi utama:** tambah, simpan, setujui rencana, konfirmasi status.
3. **Informasi saat ini:** tanggal, jam, aktivitas terdekat, progress harian.
4. **Informasi tambahan:** kategori, recurrence, catatan, lokasi, tautan.

## 4. Peta layar dan routing

```text
Splash
 └─ Onboarding (multi-step)
     └─ Profil Lokal dan Preferensi
         └─ Home [tab]
             ├─ Statistik [push screen]
             ├─ Detail Aktivitas / Konfirmasi
             └─ Pengingat/Notifikasi dalam aplikasi

BottomNav
 ├─ Home
 ├─ Kalender
 │   ├─ Hari / Minggu / Bulan
 │   └─ Detail Kegiatan / Edit / Cakupan Perulangan
 ├─ To-Do List
 │   ├─ Detail Tugas / Subtasks / Work Sessions
 │   ├─ Overdue / Reschedule
 │   └─ Smart Scheduling Wizard
 ├─ Rutinitas
 │   ├─ Detail Rutinitas / Progres
 │   └─ Timer / Catatan Durasi
 └─ Profil
     ├─ Preferensi Jam Aktif / Jenis Kegiatan
     ├─ Pengaturan Notifikasi / Jam Tenang
     ├─ Kategori Bersama
     ├─ Pengaturan Kalender & Zona Waktu
     ├─ Backup / Restore / Conflict Resolution
     └─ Tempat Sampah

Floating (+)
 ├─ Tambah Kegiatan → Quick Add ↔ Form Lengkap
 ├─ Tambah Tugas → Quick Add ↔ Form Lengkap
 └─ Tambah Rutinitas → Quick Add ↔ Form Lengkap
```

Routing detail (nama path, nested navigator, deep links) adalah keputusan implementasi **OPEN**. Struktur di atas **CONFIRMED** pada level UX.

## 5. Spesifikasi layar dan state

Setiap layar di bawah harus disiapkan sebagai artboard/prototipe untuk design-first. Minimal state yang dicantumkan harus tersedia sebelum mengimplementasikan fungsionalitas backend lokal.

### SC-01 Splash Screen

- Logo/nama produk (branding final **OPEN**), latar krem atau warna aksen flat, visual sederhana neobrutalism.
- Transisi ke onboarding saat first run; ke Home jika profil/preferensi telah disiapkan.
- State: normal, startup loading, kegagalan data lokal/migrasi (pesan retry yang tidak menghilangkan data).

### SC-02 Onboarding

- Jelaskan manfaat: atur kegiatan, deadline, rutinitas, saran jadwal, offline/backup.
- Navigasi maju/kembali, indikator langkah, skip jika kebijakan memungkinkan (**OPEN**).
- Tidak ada register/login di MVP.
- State: first slide, middle slide, last slide, large text, interrupted/resume.

### SC-03 Profil lokal & preferensi awal

- Form profil lokal (field wajib belum final; jangan tambahkan field wajib yang tidak diputuskan).
- Set jam aktif per hari Senin–Minggu; set preferensi belajar/workout per jenis kegiatan.
- Opsi waktu/visual contoh dengan label default PROPOSED jika dirender.
- State: empty, incomplete, invalid interval, successfully saved, permission reminder optional.

### SC-04 Home Dashboard

**Susunan yang disarankan:**

1. Header sapaan singkat, tanggal, indikator notifikasi dan shortcut Statistik.
2. Lima KPI: total hari ini, selesai, belum selesai, persentase, kegiatan terdekat.
3. Panel **Menunggu Konfirmasi** (hanya jika ada).
4. Kartu kegiatan/agenda hari ini, dengan status dan waktu.
5. CTA lihat kalender/statistik atau tambah bila kosong.

**KPI:** tidak menghitung ganda task work session/routine event; hanya Selesai masuk pembilang. Hari tanpa aktivitas: `Tidak Ada Aktivitas`, bukan 0%/100%.

**State wajib:** loading, belum ada kegiatan, semua selesai, ada kegiatan belum dikonfirmasi, ada bentrok, izin notifikasi nonaktif, kegiatan lintas hari, banyak kategori, task overdue muncul sebagai entry yang jelas jika relevan.

### SC-05 Kalender Bulanan

- Header bulan, tombol bulan sebelumnya/berikutnya, hari pertama Senin/Minggu sesuai setting.
- Sel tanggal menandai aktivitas/deadline, tanggal terpilih dan hari ini.
- Tap tanggal → daftar kegiatan tanggal itu atau navigasi ke Day View. Event all-day dan lintas tengah malam jelas.
- State: hari tanpa item, banyak item pada satu tanggal, busy all-day, event recurrence, cross-midnight, deadline timezone shift, date picker.

### SC-06 Kalender Mingguan

- Grid 7 hari dengan label waktu dan card/block event, all-day lane di atas.
- Visual beda untuk event Sibuk/Tersedia serta buffer (buffer boleh ditampilkan pada edit/preview jika dense terlalu banyak).
- Overlap manual harus tergambar sebagai dua blok dengan icon/warning, bukan saling menutupi tanpa petunjuk.
- State: conflict overlap, buffer violation, timezone change, event crossing day boundary, week-start switch.

### SC-07 Kalender Harian

- Timeline waktu, all-day section, event cards, deadline chips, work sessions.
- Aksi tap detail, edit, add; highlight current time dan available slots jika dibutuhkan.
- State: empty, loading, multiple overlaps, task deadline at same hour, out-of-active-hours manually confirmed.

### SC-08 Detail Kegiatan

- Judul, tanggal, jam, zona waktu, status, kategori, recurrence, deskripsi, lokasi/link/catatan jika ada.
- Aksi: edit, hapus, konfirmasi Selesai/Ditunda/Dilewatkan (sesuai waktu/status), jadwalkan ulang.
- Recurrence edit/delete: bottom sheet pilihan **Hanya kejadian ini / Ini dan berikutnya / Seluruh rangkaian**.
- State: upcoming, in-progress indication, pending confirmation, completed, postponed, skipped, deleted-in-trash, recurring exception.

### SC-09 Quick Add Kegiatan

- Field **wajib** judul, tanggal, mulai, selesai. CTA Form Lengkap.
- Tidak menciptakan waktu default secara diam-diam.
- State: missing fields, end before start validation (kegiatan lintas tengah malam sah jika tanggal akhir ditentukan sesuai model), conflict warning, buffer warning, outside-active-hours warning, success.

### SC-10 Form Lengkap Kegiatan

- Quick Add fields tetap terisi; tambahan deskripsi, kategori/warna, lokasi, recurrence, reminders, notes, link, all-day Busy/Free, before/after buffer, time zone mode.
- Hierarki grup: **Waktu**, **Kategori**, **Pengulangan**, **Pengingat**, **Detail Tambahan**.
- State: multiple reminders, monthly custom recurrence, one occurrence edit, split series, valid/invalid link, all-day free/busy.

### SC-11 To-Do List

- Search/filter: tanggal, kategori, status, prioritas; sort deadline/prioritas (sort time hanya untuk entitas yang memilikinya).
- Kartu: judul, deadline, priority badge, status, jumlah subtugas + % jika ada, count sesi kerja bila relevan.
- Overdue ditandai dengan teks + ikon, bukan coral saja.
- State: empty, all completed, overdue, with upcoming sessions, no category, no tasks matching filter, errors.

### SC-12 Detail Tugas

- Deadline vs jadwal sesi **dipisahkan secara visual**.
- Subtask list interaktif dengan progress otomatis, tetapi CTA **Tandai Tugas Selesai** tetap eksplisit.
- Tampilkan durasi rencana, time log aktual, estimasi sisa yang telah dikonfirmasi (jika ada), serta daftar sesi mendatang.
- Aksi ubah deadline, tambah sesi manual, buka Smart Scheduling, edit, hapus.
- State: unfinished subtask, 100% subtask not completed, completed with future sessions (prompt cancel/keep), overdue, time estimate mismatch, no session.

### SC-13 Quick Add & Form Lengkap Tugas

- Quick Add wajib judul + deadline tanggal/jam.
- Form lengkap: deskripsi, kategori, prioritas, checklist subtask, reminder, zona waktu deadline (default asal), estimasi durasi, sesi pengerjaan terkait.
- Jangan mengasumsikan task recurrence.
- State: deadline in past warning, invalid values, permission off, timezone mode detail, add subtask/edit/remove.

### SC-14 Rutinitas

- Kartu: nama, target jenis checklist/durasi/jumlah/frekuensi, target vs progres aktual, tanggal/frekuensi, kategori.
- Sediakan penanda jadwal rutin dan progress mingguan mengikuti awal minggu yang dipilih.
- State: belum ada rutinitas, target tercapai tapi belum status selesai, rutinitas terlewat, timer berjalan, partial history.

### SC-15 Quick Add & Form Lengkap Rutinitas

- Quick Add wajib nama, jenis target, frekuensi.
- Form lengkap: rincian target, kategori, preferensi waktu, rencana pengulangan bila ditautkan pada kegiatan terjadwal, reminder.
- Field spesifik target berbasis tipe, bukan semua field sekaligus.
- State: checklist, durasi, jumlah, mingguan, invalid target, partial form.

### SC-16 Detail Rutinitas & Timer

- Timer Start/Pause/Stop dan tampilan durasi aktual yang dipulihkan setelah aplikasi kembali dari background/lock.
- Penanda target tercapai; **jangan menyamakan pencapaian timer dengan status Selesai**.
- Input progres manual dan riwayat.
- State: idle, running, paused, stopped, restored session, goal reached notification not available, app resumed.

### SC-17 Smart Scheduling Wizard: Pra-pencarian

- Nama tugas, deadline (dengan timezone), estimasi sisa (dengan label apakah usulan/konfirmasi), durasi minimum sesi, maksimum sesi, preferensi waktu.
- Peringatan jika durasi aktual tidak identik dengan progres task.
- Pengguna meninjau dan mengonfirmasi estimasi sisa sebelum mencari proposal.
- State: first planning, replanning, invalid deadline, missing estimate, permission/setting conflict.

### SC-18 Smart Scheduling: Hasil rekomendasi

- Slot kandidat berdasarkan jam aktif, preferensi, buffer, busy intervals, deadline. Tampilan agenda timeline dan list sesi.
- Untuk split sessions, tampilkan total jam serta tiap durasi, hari dan jam, dan hubungan dengan deadline.
- CTA **Setujui & Simpan Sesi** hanya setelah review. Pre-save harus menampilkan proposal yang jelas (belum disimpan).
- State: one-slot found, multi-session found, selected/unselected, stale calendar requiring recheck, no feasible result.

### SC-19 Smart Scheduling: Kendala dan alternatif

- Tampilkan **alasan konkret**: tidak ada ruang dalam jam aktif, buffer, batas sesi, durasi minimum, atau waktu sebelum deadline.
- Alternatif: kurangi minimum sesi, tingkatkan maksimum sesi, jadwalkan manual. Deadline tidak digeser otomatis.
- Perubahan parameter harus terlihat dan disetujui sebelum rerun.
- State: no slot, sum insufficient, max-session constraint, min-duration constraint, persistent failure.

### SC-20 Smart Scheduling: Konflik & optimasi ulang

- Banner sesi terdampak ketika perubahan kalender menciptakan bentrok.
- Pilih cakupan: **hanya sesi bentrok** / **seluruh sesi mendatang**. Sesi terlaksana ditampilkan read-only.
- Preview old vs proposed sessions; validasi ulang jam aktif/buffer/deadline.
- State: only one conflict, multiple conflicts, no solution, user retained conflicting manual plan, approval dialog.

### SC-21 Smart Scheduling: Selisih sisa durasi (Q79–80)

- Kartu perbandingan **Estimasi sisa disetujui** vs **Total sesi mendatang**; tampilkan selisih dalam jam/menit.
- Jika kurang: tawarkan penambahan sesi, optimasi ulang, atau pertahankan rencana.
- Jika lebih: tawarkan kurangi sesi, optimasi ulang, atau pertahankan rencana.
- Perubahan memerlukan persetujuan; mempertahankan rencana tetap menampilkan info selisih.
- State: match, shortage, surplus, no feasible adjustment, proposed change, approved change, cancelled dialog.

### SC-22 Statistik Produktivitas

- Entry dari Home; tab/segmented Hari/Minggu/Bulan di dalam halaman, **bukan bottom nav**.
- Kartu KPI penyelesaian total, rata-rata persentase harian, total kegiatan, status selesai/ditunda/dilewatkan.
- Per jenis kegiatan kalender, task, rutinitas; filter kategori bersama; chart per periode.
- Pemilih pembanding: default periode sebelumnya, dapat dipilih manual. Periode berjalan dibanding rentang durasi yang setara; tampilkan label dua rentang dengan jelas.
- Hari tanpa aktivitas tampil sebagai placeholder `Tidak Ada Aktivitas`, tidak digambarkan 0%.
- Ubah awal minggu → pengelompokan historis berubah. Tidak mengubah riwayat.
- State: no activity day, no data in selected period, partial period, side-by-side comparison, category filtered, changed-week-start, loading/error.

### SC-23 Profil & Pengaturan

- Profil lokal dan preferensi, masuk ke pengaturan jam aktif per hari, waktu per jenis kegiatan, buffer default, kategori, kalender/awal minggu, zona waktu, notifikasi dan Quiet Hours, backup/restore, Tempat Sampah.
- Tidak menampilkan login online sebagai aksi aktif MVP.
- State: profile saved, profile incomplete, backup reminder due, notifications denied, settings changed.

### SC-24 Pengaturan Jam Aktif

- Editor 7 hari, tiap hari punya rentang jam aktif sendiri; preferensi berbeda untuk workout/belajar.
- Beri perbedaan visual dari Quiet Hours; jangan menyebut jam aktif sebagai waktu dilarang.
- State: multiple days, changed, invalid/overlapping interval, manual event outside active hours warning (di form event), timezone change.

### SC-25 Pengaturan Notifikasi & Quiet Hours

- Toggle pengingat global (sesuai OS), daftar jenis reminder, multiple reminders per activity, batas pengingat konfirmasi, Quiet Hours waktu mulai dan selesai, pengecualian per jenis.
- Jika permission off, tampilkan banner non-blocking, status tidak aktif, tombol **Buka Pengaturan Sistem** dan fallback dashboard. Tidak mengklaim sistem bisa memaksa notification.
- State: permission not requested, permission denied, permission granted, Focus/DND caveat, quiet hours active, exceptions configured, notification scheduling failure.

### SC-26 Kategori Bersama

- Daftar kategori beserta ikon dan warna. Tambah/edit/hapus.
- Saat hapus kategori yang digunakan item: dialog pilihan **Pindahkan seluruh aktivitas ke kategori pengganti** atau **Tanpa Kategori**. Jelaskan bahwa kegiatan/tugas/rutinitas **tidak ikut dihapus**.
- State: empty, valid edit, duplicate names (policy OPEN), color/icon picker, deleting in-use category, reassign complete, error.

### SC-27 Backup Ekspor

- Ringkasan isi data/cakupan backup (tanpa data sensitif berlebihan), bidang password + konfirmasi, peringatan bahwa password mungkin tidak bisa dipulihkan.
- Setelah file dienkripsi, pilih **Simpan ke perangkat / Share Sheet / aplikasi cloud jika tersedia** melalui sistem.
- Pengingat backup pilihan 7/14/30 hari, custom, atau nonaktif, tempatkan di Settings atau subhalaman ini.
- State: no password, password mismatch, encryption in progress, export success, share canceled, OS picker unavailable, write error, reminder enabled/disabled.

### SC-28 Backup Restore & Konflik Merge

- Pilih file → masukkan password → validasi format/integritas → preview isi/mode restore.
- Pilih **Ganti Semua** atau **Gabungkan**. Untuk Ganti Semua tampilkan peringatan tegas bahwa data lokal akan diganti. Untuk Gabungkan, tampilkan diff ID sama dengan versi berbeda, pilih versi lokal atau backup untuk tiap konflik.
- `ConflictDiff`: dua kolom/kartu jelas untuk konten dan timestamp, badge lokal vs backup, pilihan keep.
- State: incorrect password, invalid file, unsupported schema version, file corruption, no conflicts, one/many conflicts, unresolved decision, restore success, rollback-safe failure.

### SC-29 Tempat Sampah

- Tiga jenis item dan tanggal penghapusan, sisa retensi 30 hari (lihat kebijakan purge OPEN).
- Aksi Pulihkan, Hapus Permanen. Restore memeriksa bentrok kalender; jelaskan pilihan konsekuensi tanpa menghapus jadwal lain.
- State: empty, many deleted items, imminent expiry, restore conflict, restored, delete confirmed, expired.

### SC-30 Dialog dan overlay universal

Buat desain tersendiri untuk:

1. Hapus aktivitas dan scope recurring 1/this+future/all.
2. Simpan manual meski overlap, buffer, atau di luar jam aktif.
3. Konfirmasi hasil event Selesai/Ditunda/Dilewatkan.
4. Sesi tugas yang masih ada setelah task selesai: Batalkan/Pertahankan.
5. Modal proposal Smart Scheduling + scope rescheduling + review final.
6. Selisih estimasi sisa dan durasi sesi mendatang (Q80).
7. Konfirmasi perubahan awal minggu (statistik agregat terhitung ulang).
8. Hapus kategori dengan reassignment.
9. Backup: password, replace-all warning, merge conflict picker.
10. Hapus permanen Trash.
11. Izin notifikasi ditolak.

**Aturan dialog:** judul menyebut akibat, badan singkat, CTA eksplisit dengan hasil yang dapat dipahami, pilihan **Batal** selalu tersedia untuk aksi destruktif atau berisiko.

## 6. Form detail & validasi

### 6.1 Pola Quick Add → Full Form

- Simpan isian saat user memilih Full Form; penjelasan wajib/opsional jelas.
- Jangan memilih jam, tanggal, durasi atau prioritas secara diam-diam ketika user belum memberikan nilai Quick Add wajib.
- Pada Form Lengkap gunakan section bertingkat; input jarang dipakai dipindah ke Advanced, bukan menghilangkan feature.
- Keyboard dan date picker tidak menutupi CTA atau menyebabkan kehilangan form saat back.

### 6.2 Pesan validasi (PROPOSED copy, dapat direvisi)

| Kondisi | Copy UI |
|---|---|
| Judul kosong | `Judul wajib diisi.` |
| Tanggal/waktu belum lengkap | `Lengkapi tanggal dan waktu kegiatan.` |
| Bentrok langsung | `Jadwal ini bertabrakan dengan kegiatan lain.` |
| Buffer dilanggar | `Jeda sebelum atau sesudah kegiatan tidak terpenuhi.` |
| Di luar jam aktif | `Waktu ini berada di luar jam aktifmu.` |
| Deadline berlalu | `Deadline telah terlewati. Tugas ditandai Overdue.` |
| Estimasi sisa belum disetujui | `Konfirmasi estimasi waktu yang masih dibutuhkan.` |
| Tidak ada slot Smart Scheduling | `Tidak ditemukan slot yang memenuhi semua batasan.` |
| File backup password salah/korup | `Backup tidak dapat dibuka. Periksa password dan file.` |
| Notifikasi off | `Notifikasi perangkat belum aktif. Pengingat tetap dapat dilihat di Home.` |
| Hari tanpa aktivitas | `Tidak Ada Aktivitas` |

Error message sebaiknya menyatakan tindakan berikutnya, bukan hanya 'Gagal'.

## 7. Interaksi penting: skenario detail

### 7.1 Menyelesaikan event yang waktunya sudah lewat

1. Kartu/event masuk `Menunggu Konfirmasi`, dengan indikator masa lalu.
2. Pengguna tap → modal **Selesai / Ditunda / Dilewatkan**.
3. Jika Ditunda, modal lanjutan opsi tanggal manual/Smart Scheduling/nanti; jangan otomatis menghapus occurrence asal.
4. Jika Dilewatkan, riwayat tetap; tawarkan sesi pengganti tanpa mengubah occurrence rutin berikutnya.
5. Home dan Statistik dihitung ulang setelah commit status.

### 7.2 Membuat task dan meminta rekomendasi

1. Quick Add task title+deadline → Full Form jika butuh prioritas/subtasks.
2. Pengguna mengisi estimasi pengerjaan (rincian input durasi belum final).
3. Smart Scheduling menampilkan jam aktif, preferensi dan estimasi sisa.
4. User konfirmasi perkiraan sisa, lalu memilih rekomendasi.
5. Bila satu slot tidak cukup, tampilkan multi-sesi, per-slot waktu/durasi.
6. Jika gagal, sebut batasan dan opsi; jangan merelaksasi batasan diam-diam.
7. Setelah setuju, validasi kalender lagi dan commit bersama.

### 7.3 Kalender berubah setelah sesi ditetapkan

1. User menambah event manual (dengan peringatan konflik sesuai kebijakan).
2. Sesi kerja yang sekarang bentrok diberi badge.
3. Sheet: **Ubah sesi bentrok saja** atau **Ubah semua sesi mendatang**.
4. Preview perubahan dan constraints. Sesi terlaksana read-only.
5. User menyetujui; sesudah itu baru commit.

### 7.4 Koreksi estimasi & Q80

1. Task menampilkan durasi aktual dan estimasi sisa yang diusulkan.
2. User mengoreksi lalu menekan **Konfirmasi estimasi**.
3. Sistem membandingkan total sesi mendatang dengan angka yang disetujui.
4. UI menampilkan `Kurang X` / `Lebih X` / `Sesuai`.
5. Tawarkan **Tambah/Kurangi Sesi**, **Optimasi Ulang**, **Pertahankan Rencana**.
6. **Pertahankan Rencana** tidak mengubah sesi dan tidak menghapus label selisih; opsi lain membuka preview dan butuh persetujuan.

### 7.5 Restore merge

1. Pilih backup file, password, baca header/integrity.
2. Pilih **Ganti Semua** atau **Gabungkan**.
3. Jika Gabungkan, tampilkan konflik dengan kartu `Data di perangkat` vs `Data dalam backup`.
4. Pilih versi untuk semua konflik; jika belum selesai, CTA commit disabled/menjelaskan sisa konflik.
5. Commit atomik dan tampilkan ringkasan jumlah item hasil restore.

## 8. Matriks state prototipe minimum

Gunakan checklist ini sebagai **delivery gate** untuk FigCraft. Screenshot/desain tidak cukup hanya satu happy-path per screen.

| Grup | Normal | Empty/loading/error | Edge/confirmation |
|---|---|---|---|
| Onboarding/profil | Setup berhasil | First install/loading | Resume incomplete, validation error |
| Home | KPI dan agenda | Hari kosong/loading | Pending confirmation, notification denied |
| Kalender | Day/week/month | Tidak ada event | Cross-midnight, all-day busy/free, bentrok |
| Kegiatan | Detail dan edit | Validasi field | Recur edit scope, buffer/outside-active warning |
| To-Do | List dan detail | Tidak ada task | Overdue, subtask 100% not complete, future session dialog |
| Rutinitas | Goal dan riwayat | Empty | Timer running/paused/restored/goal achieved |
| Smart Scheduling | Single dan split proposal | No feasible slots | Min/max constraint, stale conflict, scope replan, Q80 mismatch |
| Statistik | Day/week/month chart | No activity/data | Equal-duration comparison, filtered, week start changed |
| Pengaturan | Profil & konfigurasi | Permission request | Quiet Hours exceptions, category reassignment |
| Backup | Export & restore | No file, loading/error | Wrong password, replace, merge conflict, rollback |
| Tempat Sampah | Deleted list | Empty | Restore conflict, 30-day expiry, permanent delete |

## 9. Accessibility & usability acceptance

- Kontras teks utama minimal 4,5:1 untuk teks normal; uji state disabled/secondary dan overlay, bukan hanya palet dasar.
- Badge status berisi teks dan ikon. Contoh `OVERDUE` bukan hanya coral.
- `FABAdd`, tombol status dan aksi destruktif terbaca screen reader; semua ikon punya semantic label.
- Jika font diperbesar sampai 200%, informasi tanggal/jam dan tombol tidak terpotong; layout scroll bukan clip.
- Target sentuh minimal sekitar 44–48dp; jarak cukup untuk aksi Hapus vs Batal.
- Pengguna dapat membatalkan alur multi-step tanpa menyimpan, kecuali form yang sengaja di-save.
- Dialog harus bisa dioperasikan via screen reader dan keyboard navigation jika platform mendukung.
- Progress tidak diwakili oleh bar warna saja; selalu tampil angka/label.
- Peringatan keamanan backup tidak disembunyikan dalam tooltip.

## 10. Panduan pengembangan prototipe menggunakan Codex + FigCraft

### 10.1 Output prototipe yang diminta

1. **Satu desain sistem token** yang bisa diubah: palet, tipografi, radii, border, shadow, spacing.
2. **Komponen reusable**: bottom nav, FAB, card, chips, form input, modal, KPI, status badge, warning, session slot, time picker.
3. **Seluruh screen SC-01 sampai SC-30** setidaknya satu artboard utama plus state wajib dalam Matriks §8.
4. **Data dummy realistis**, tidak memuat data pribadi nyata. Gunakan contoh: kelas Selasa pukul 13.00–16.00, tugas deadline Jumat, workout pagi/sore, belajar siang/malam.
5. **Prototipe alur klik** minimal: onboarding → Home, FAB → Quick Add → Full Form → save/warning, calendar recurring edit, Task → Smart Scheduling → review → approve, status event → postpone, backup → restore merge, statistik Home → comparison.
6. **Frame naming** yang konsisten, mis. `SC04_Home_Default`, `SC04_Home_Empty`, `SC18_Smart_SplitProposal`, `SC28_Restore_Conflict`.
7. **Tidak ada dummy UI yang menjanjikan login/sync otomatis** di MVP.

### 10.2 Acceptance gates sebelum coding fungsional

- Seluruh lima tab dan jalur navigasi bisa diikuti.
- Layar Home menampilkan lima KPI sesuai rumus PRD, bukan metrik sembarang.
- Task detail memisahkan deadline, sesi dan durasi aktual.
- Tidak ada saran Smart Scheduling yang tampil sebagai autosaved.
- Halaman Statistik menampilkan dua metrik mingguan/bulanan dengan label jelas.
- Konfirmasi status, bentrok dan semua restore paths ada dalam desain.
- Responsive text/accessibility check, terutama warna aksen.
- Semua state data kosong/loading/error dan edge-case utama terwakili.

### 10.3 Brief siap pakai untuk Codex/FigCraft

> Buat prototipe UI mobile Flutter Android/iOS berdasarkan `PRD.md` dan `DESIGN.md` ini. Desain **seluruh halaman, formulir, dialog, dan state** lebih dahulu dengan data ilustrasi. Gunakan gaya **Balanced Neobrutalism**, palet #537BFF, #FFE65B, #FF8C82, #F5F2E9, #171717, border hitam 2–3px, hard offset shadows tanpa blur, font headline tebal, body mudah dibaca. Navigasi bawah tetap lima tab: Home, Kalender, To-Do List, Rutinitas, Profil; tombol (+) membuka tambah Kegiatan/Tugas/Rutinitas dengan Quick Add dan Full Form. Statistik adalah halaman turunan Home. Fokus pada usability kalender dan daftar padat. Sertakan state empty/loading/error, task overdue, event pending confirmation, bentrok kalender dan buffer, split-session Smart Scheduling, selisih estimasi sisa, permission denied, restore merge conflict, Trash 30 hari. Smart Scheduling hanya memberikan proposal sampai pengguna menyetujui. Pakai label **PROPOSED** untuk detail yang belum disepakati, jangan membuat login/cloud sync MVP. Jangan menerapkan fitur bisnis permanen sebelum prototipe seluruh halaman direview.

## 11. Desain dan implementasi yang masih OPEN

- Nama/logo aplikasi, ikon app dan identitas merek final.
- Family font, font licensing, ukuran spacing/radius/shadow final, visual icon set.
- Default periode kalender/tab saat aplikasi dibuka; tanggal/waktu default jam aktif.
- Detail profil lokal; bahasa final dan format jam global.
- Default reminder, Quiet Hours, backup cadence, buffer, min/max sesi.
- Bentuk tampilan peta timeline jika event overlap >2, visualisasi recurrence sangat panjang.
- Konfirmasi time log aktual pada task work session (akan diputuskan pada wawancara lanjutan).
- Layout tablet/landscape, widget home, platform native styling vs satu sistem visual.
- Visual privacy info terkait penyimpanan offline, ekspor encrypted, dan password restore.

## 12. Aturan sinkronisasi dokumen setelah wawancara

Setiap keputusan tambahan ditambahkan ke `PRD.md` sebagai perilaku yang **CONFIRMED** dan ke `DESIGN.md` pada layar/state yang terdampak. Jika keputusan hanya menyangkut rumus/internal logic, update DESIGN hanya bila copy/visualisasi perlu berubah. Pertahankan nomor pertanyaan sebagai jejak asal keputusan. **Jangan menetapkan nilai default dari rekomendasi asisten sebagai keputusan final**.

---

**Dokumen ini mendeskripsikan UI yang akan dibuat, bukan klaim bahwa prototipe FigCraft atau aplikasi Flutter sudah diimplementasikan.**
