# Spesifikasi teknis landing page distribusi APK

Fase 19 hanya menghasilkan spesifikasi. **Belum ada website, backend, domain, hosting, URL unduhan, tanggal rilis publik, atau APK publik yang disiapkan.** Publikasi bergantung pada [gerbang distribusi](ANDROID_DISTRIBUTION.md) dan peninjauan cakupan [verification](ANDROID_DEVELOPER_VERIFICATION.md).

## Metadata wajib per rilis

| Field | Ketentuan |
| --- | --- |
| Nama / package | Routina dan applicationId final yang telah disetujui; contoh `com.example` tidak boleh tampil sebagai rilis final. |
| Versi / build | versionName dan versionCode dari APK final, bukan angka yang diketik ulang tanpa pemeriksaan. |
| Unduhan | Satu universal signed APK, tautan HTTPS absolut pada domain resmi; nama file unik per versi/build. |
| Ukuran | Jumlah byte tepat dan label MiB yang diturunkan dari file yang sama. |
| Tanggal rilis | Waktu publikasi nyata dengan zona waktu; `builtAtUtc` pipeline bukan tanggal publikasi. |
| Integritas | SHA-256 seluruh APK final berupa 64 hex, ditampilkan dan tersedia sebagai `.sha256`. Bedakan dari fingerprint sertifikat signing. |
| Identitas signing | SHA-256 sertifikat publik yang cocok dengan register pemilik dan versi sebelumnya; tanpa keystore/password. |
| Minimum OS / ABI | Android 7.0/API 24 ke atas; ARM 32-bit, ARM64, x86_64 sesuai APK universal yang diuji. API minimum bukan jaminan seluruh perangkat sudah diuji. |
| Release notes | Perubahan, perbaikan, masalah diketahui, perubahan skema/izin dan instruksi update untuk versi itu. |
| Privasi / kontak | Tautan kebijakan privasi bertanggal dan kontak developer yang nyata serta disetujui pemilik. Keduanya **DECISION REQUIRED**, jangan mengisi dengan identitas fiktif. |

JSON pipeline lokal menyediakan package, versi/build, byte, checksum, waktu build, SDK, ABI dan status signature/alignment. Website hanya mengambil kandidat yang sudah lolos seluruh checklist manual; tolak `UNSIGNED_NOT_FOR_DISTRIBUTION` dan setiap `publicationStatus` yang masih PENDING. Operator menetapkan status publik setelah review, tanpa menganggap keberhasilan script sebagai otorisasi publikasi.

## Pengiriman dan konsistensi artefak

- Seluruh halaman, file, checksum dan redirect memakai HTTPS dengan sertifikat valid. Tidak ada redirect HTTP, pemendek URL atau mirror yang identitasnya tidak dikendalikan pemilik.
- Sajikan APK dengan `Content-Type: application/vnd.android.package-archive`, `Content-Disposition: attachment; filename="<nama-versi-build>.apk"` dan ukuran respons yang benar. Gunakan `X-Content-Type-Options: nosniff`. Range/resume unduhan boleh didukung tanpa mengubah byte.
- Simpan path per versi secara immutable. Perbarui tautan rilis terkini dan metadata secara atomik setelah upload diverifikasi; jangan menimpa file versi lama dengan byte berbeda.
- Unduh ulang file dari URL publik dan hitung SHA-256, ukuran, signature dan package. Cocokkan terhadap hasil lokal. Jangan membuka CTA sampai seluruh metadata dan release notes cocok.
- Sertakan label jelas **Unduh APK untuk Android**, versi, ukuran dan kebutuhan OS dekat CTA. Unduhan dimulai dari tindakan pengguna. Gunakan link/tombol berlabel, fokus keyboard, kontras dan layout teks besar yang layak.

## Copy keamanan dan instalasi

1. Unduh hanya dari tautan HTTPS resmi. Cocokkan nama aplikasi, versi dan checksum jika pengguna memilih memeriksa integritas. Checksum membantu memeriksa file; tidak menggantikan signature dan kepercayaan pada sumber resmi.
2. Buka APK dari Downloads menggunakan installer Android. Jika sistem meminta, pengguna dapat memberikan izin **Instal aplikasi tidak dikenal** hanya pada browser/pengelola file yang dipakai, sesuai pengamanan Android. Nama menu berbeda menurut versi/OEM. Cabut kembali izin sumber itu setelah selesai. Android 7 memakai pengaturan berbeda; instruksi harus mengikuti dialog OS yang tersedia. [Distribusi melalui website](https://developer.android.com/distribute/marketing-tools/alternative-distribution)
3. Biarkan pemeriksaan keamanan dan Play Protect aktif. Jika ada peringatan berbahaya, signature tidak sesuai, atau instalasi diblokir, hentikan dan hubungi developer. Tidak ada petunjuk untuk melewati blokir, menonaktifkan proteksi, mematikan jaringan, atau memakai ADB bagi pengguna umum.
4. Untuk update, ekspor backup `.routina` terenkripsi dari versi lama ke lokasi aman di luar aplikasi, simpan password terpisah dan pastikan backup dapat dibaca. Unduh versi baru lalu pilih update tanpa uninstall atau clear data. Peringatkan bahwa uninstall dapat menghapus data lokal dan backup OS dinonaktifkan. [Backup](BACKUP.md)
5. Sesudah update, buka Routina dan periksa agenda, tugas, rutinitas, timer dan pengaturan notifikasi. Jika installer tidak menawarkan update atau menolak, jangan uninstall; hubungi kontak resmi dengan versi/OS tanpa mengirim isi agenda atau password.

## Isi kebijakan privasi yang harus disetujui

Jelaskan profil dan planner lokal/offline, izin notifikasi dan boot, SQLite lokal di sandbox, backup manual terenkripsi serta tanggung jawab password. Terangkan bahwa penyedia Files/Share Sheet yang dipilih pengguna dapat memakai jaringan/cloud sendiri. Nyatakan praktik aktual mengenai analitik, iklan dan pengumpulan data aplikasi, serta praktik log hosting website yang nanti dipilih. Jangan menjanjikan hosting tanpa log sebelum implementasi nyata. Tetapkan kontak, tanggal berlaku, prosedur laporan keamanan dan penghapusan data yang dipahami pengguna.

Persetujuan identitas, kontak, privasi, release notes dan tanggal publikasi tetap PENDING sampai pemilik menetapkannya. Tidak ada sistem update otomatis, backend atau pelacakan yang ditambahkan oleh spesifikasi ini.
