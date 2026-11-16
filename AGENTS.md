# Konvensi kerja Codex untuk Routina

## Sumber dan fase

- **CONFIRMED** · `PRD.md` menetapkan perilaku produk. `DESIGN.md` menetapkan struktur UI dan state. `Personal Planner - Flutter UI Design.figcraft` menyediakan referensi visual dan alur demo. Gunakan kapitalisasi nama file tersebut.
- **CONFIRMED** · Kerjakan hanya fase yang diminta. Baca `docs/IMPLEMENTATION_PLAN.md` dan `docs/FIGCRAFT_SCREEN_MAP.md`, lalu periksa riwayat Git, `git status --short --branch`, instruksi direktori, dependency, dan hasil fase sebelumnya.
- **CONFIRMED** · Pertahankan aturan CONFIRMED. Uji usulan PROPOSED dan dokumentasikan asumsi yang disetujui. Catat dampak keputusan OPEN pada fase terkait. Jangan mengambil keputusan bisnis dari data contoh FigCraft.
- **CONFIRMED** · Gunakan FigCraft MCP untuk inspeksi jika tersedia, atau ekspor dan aset lokal sebagai referensi. Implementasikan widget reusable dan pertahankan artefak desain kecuali perubahan desain termasuk lingkup yang diberi izin.

## Flutter dan domain

- **CONFIRMED** · Gunakan Flutter stable dan Dart yang kompatibel untuk Android/iOS. MVP bekerja offline dengan satu sumber data lokal, tanpa akun online, backend, atau sinkronisasi cloud. Gunakan bahasa Indonesia untuk UI kerja.
- **CONFIRMED** · Pisahkan durasi rencana, durasi aktual, estimasi sisa, progres subtugas, dan status selesai. Mutasi Smart Scheduling memerlukan persetujuan eksplisit dan validasi ulang jadwal. Jaga identitas, relasi, dan riwayat untuk deduplikasi, recurrence, dan restore.
- **CONFIRMED** · Tangani validasi serta state loading, kosong, error, dan izin ditolak sesuai fitur. Jaga draft Quick Add saat membuka Form Lengkap. Gunakan target sentuh, semantics, dan layout yang mendukung text scaling.
- **PROPOSED** · Setelah scaffold tersedia, gunakan Pub melalui `flutter pub get` dan lacak `pubspec.lock` aplikasi. Gunakan test yang dekat dengan unit atau widget yang diubah, misalnya `flutter test test/<fitur>_test.dart`, sebelum validasi seluruh proyek.

## Validasi dan Git

- **CONFIRMED** · Untuk fase Flutter, jalankan `dart format <path Dart yang berubah>`, `flutter analyze`, `flutter test`, dan pengujian relevan. Jalankan aplikasi atau uji integrasi jika perangkat tersedia. Untuk perubahan UI, bandingkan hasil render dengan frame terkait dan laporkan cakupan validasi visual.
- **CONFIRMED** · Laporkan hasil yang teramati dan alasan cek yang tidak dapat dijalankan. Untuk perubahan dokumentasi, periksa pemetaan, tautan, dan `git diff --check`.
- **CONFIRMED** · Stage dan commit hanya file terkait fase menggunakan judul yang ditetapkan. Jaga perubahan pengguna dan hindari `git reset --hard` serta force push. Verifikasi status Git setelah commit.
- **CONFIRMED** · Laporkan fitur atau artefak selesai, file utama, hasil uji, validasi UI bila relevan, masalah terbuka, serta hash dan judul commit jika berhasil. Berhenti setelah fase yang diminta.
