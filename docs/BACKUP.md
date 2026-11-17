# Format backup Routina untuk review

Fase 14 mengimplementasikan FR-13 dengan file `.routina`. Format berikut berstatus **PROPOSED** sampai review keamanan OPEN-11 selesai.

## Envelope biner v1

| Offset | Ukuran | Isi |
| --- | --- | --- |
| 0 | 8 | ASCII `ROUTBKUP` |
| 8 | 1 | Versi format `0x01` |
| 9 | 1 | Suite `0x01` untuk PBKDF2-HMAC-SHA-256 dan AES-256-GCM |
| 10 | 4 | Iterasi PBKDF2 `600000` sebagai uint32 big-endian |
| 14 | 16 | Salt acak independen |
| 30 | 12 | Nonce GCM acak independen |
| 42 | Variabel | Ciphertext JSON UTF-8 |
| Akhir | 16 | Tag GCM 128 bit |

KDF menerima byte UTF-8 dari password persis seperti yang diketik dan menghasilkan kunci 256 bit. Aplikasi mengambil salt dan nonce baru dari CSPRNG bawaan Dart pada setiap ekspor. Seluruh header 42 byte dipakai sebagai associated data. Pembaca menerima kombinasi versi, suite, dan iterasi di atas. Batas 32 MiB dan 50.000 entitas membatasi biaya pembacaan. Enkripsi dan derivasi berjalan di isolate agar UI tetap merespons. Rujukan parameter dan algoritma. [OWASP PBKDF2](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html#pbkdf2) · [NIST SP 800-38D](https://csrc.nist.gov/pubs/sp/800/38/d/final)

Password salah dan modifikasi ciphertext, salt, nonce, atau tag menghasilkan pesan autentikasi yang sama. Format asing, ukuran, dan versi yang belum didukung dapat diberitahukan terpisah. Skema dan isi dibaca setelah autentikasi berhasil. Password tidak menjadi bagian file, database, riwayat, atau pesan diagnostik. Aplikasi mengosongkan kolom password saat operasi dimulai dan membersihkan buffer kriptografi yang bisa ditulis. Dart tidak menyediakan jaminan penghapusan seluruh salinan string dari memori. Perlindungan terhadap tebakan offline tetap bergantung pada kekuatan password. Simpan password di tempat aman karena Routina tidak memiliki jalur pemulihan password.

## Manifest dan data

Manifest terenkripsi memuat `application = "routina"`, `schemaVersion`, `createdAt` ISO 8601 UTC, dan jumlah per jenis entitas. Format v1 membawa skema SQLite 9. Pembaca memeriksa kesesuaian versi skema dengan aplikasi. Migrasi isi file lintas versi memerlukan aturan eksplisit saat skema baru diperkenalkan.

Setiap entitas membawa ID stabil, jenis, revisi, waktu pembuatan/perubahan, relasi induk, dan data sesuai tabel. Snapshot memuat profil, kategori, seri dan pengecualian, kegiatan, tugas, subtugas, sesi, rutinitas, time log, riwayat status, aturan pengingat, serta Tempat Sampah. Timer aktif dicadangkan sebagai jeda dengan durasi hingga waktu snapshot. Perkiraan target dari timer yang berjalan akan dibentuk ulang saat timer dilanjutkan. Cache pengiriman pengingat perangkat dibentuk ulang setelah commit.

## Restore dan mitigasi kehilangan data

- Aplikasi memvalidasi backup terautentikasi di SQLite dalam memori. Validasi memeriksa bentuk kolom dan tipe nilai, ID unik, profil, induk, relasi, aturan kalender, hitungan manifest, batasan tabel, foreign key, serta konsistensi hasil dengan riwayat. Tinjauan dan pemilihan versi tidak menulis data aktif.
- **Ganti Semua** menampilkan ringkasan, menawarkan ekspor cadangan data saat ini, dan meminta konfirmasi. **Gabungkan** memakai ID stabil. Judul kembar dengan ID berbeda tetap terpisah. Dua versi berbeda membutuhkan pilihan. Jika kedua sumber memiliki ID profil yang berbeda, pengguna memilih satu karena perangkat hanya memiliki satu profil lokal.
- Gabungan dengan relasi, hasil historis, atau slot unik yang bertentangan ditolak. Catatan waktu yang dipertahankan tetap terikat pada jadwal sumbernya. Aplikasi meminta tinjauan ulang jika data aktif berubah sebelum commit. Penghapusan dan penyisipan dilakukan dalam satu transaksi dalam urutan dependensi, dengan foreign key tetap aktif. Kegagalan memicu rollback. Rekonsiliasi pengingat berjalan sesudah commit.
- Cadence tersedia untuk 7, 14, 30, atau 1–365 hari khusus. Pemilih file memperbarui waktu backup terakhir setelah penyimpanan berhasil. Setelah berbagi, pengguna mengonfirmasi bahwa salinan sudah tersimpan di aplikasi tujuan. Penyedia cloud dikelola oleh OS dan mungkin belum selesai mengunggah saat berbagi selesai.

## Pustaka dan platform

| Pustaka | Versi lockfile | Pertimbangan |
| --- | --- | --- |
| `cryptography` | 2.9.0 | Pustaka lintas platform yang masih dipelihara. AES-GCM dan PBKDF2 tersedia di Dart untuk Android/iOS dengan format byte yang sama. |
| `file_picker` | 11.0.3 | Memilih dan menyimpan file melalui dialog Android/iOS. Podspec versi ini mendukung iOS 12. Seri 12 ke atas mensyaratkan iOS 14, sementara Routina menargetkan iOS 13. |
| `share_plus` | 11.1.0 | Share Sheet asli Android/iOS. Versi ini mendukung iOS 12 dan Android Gradle Plugin mulai 8.3. Seri 12 memakai AGP mulai 8.12.1, sementara proyek memakai 8.11.1. |

Sumber dokumentasi dan riwayat rilis. [cryptography 2.9.0](https://pub.dev/packages/cryptography/versions/2.9.0) · [file_picker](https://pub.dev/packages/file_picker/changelog) · [share_plus 11.1.0](https://pub.dev/packages/share_plus/versions/11.1.0) · [share_plus 12.0.2](https://pub.dev/packages/share_plus/versions/12.0.2)

Pemilih file dan menu berbagi dapat membuat salinan sementara dari file yang dipilih atau dibagikan. Untuk ekspor, salinan yang diteruskan ke adaptor dan penyedia file sudah terenkripsi. Aplikasi tidak membuat file export plaintext. Uji interoperabilitas memakai vektor Node.js/OpenSSL independen. Review keamanan format dan validasi berbagi serta pemilih file di perangkat iOS tetap diperlukan sebelum rilis.
