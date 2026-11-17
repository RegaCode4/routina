# Format backup Routina untuk review

Fase 14 memperkenalkan file `.routina`. Fase 17 mengaudit kontrak, jalur impor, dan restore. Format v1 dan pembacaan backup skema 9 dipertahankan. Parameter final untuk produksi masih **OPEN-11**.

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

Manifest terenkripsi memuat `application = "routina"`, `schemaVersion`, `createdAt` ISO 8601 UTC, dan jumlah per jenis entitas. Format v1 membawa skema pertukaran 9 dan tetap menerima file v1 dari Fase 14–17. Skema SQLite lokal 10 menambahkan acuan boot dan jam monotonik Android untuk timer aktif. Ekspor membawa durasi akumulasi sebagai timer yang dijeda. Acuan boot tetap tersimpan lokal. Schema ID file lain ditolak sebelum penulisan. Migrasi isi file lintas versi tetap OPEN-05.

Setiap entitas membawa ID stabil, jenis, revisi, waktu pembuatan/perubahan, relasi induk, dan data sesuai tabel. Snapshot memuat profil, kategori, seri dan pengecualian, kegiatan, tugas, subtugas, sesi, rutinitas, time log, riwayat status, aturan pengingat, serta Tempat Sampah. Timer aktif dicadangkan sebagai jeda dengan durasi hingga waktu snapshot. Perkiraan target dari timer yang berjalan akan dibentuk ulang saat timer dilanjutkan. Cache pengiriman pengingat perangkat dibentuk ulang setelah commit.

## Restore dan mitigasi kehilangan data

- Aplikasi memvalidasi backup terautentikasi di SQLite dalam memori. Validasi memeriksa bentuk kolom dan tipe nilai, ID unik, profil, induk, relasi, aturan kalender, hitungan manifest, batasan tabel, foreign key, serta konsistensi hasil dengan riwayat. Tinjauan dan pemilihan versi tidak menulis data aktif.
- **Ganti Semua** menampilkan ringkasan, menawarkan ekspor cadangan data saat ini, dan meminta konfirmasi. **Gabungkan** memakai ID stabil. Judul kembar dengan ID berbeda tetap terpisah. Dua versi berbeda membutuhkan pilihan. Jika kedua sumber memiliki ID profil yang berbeda, pengguna memilih satu karena perangkat hanya memiliki satu profil lokal.
- Gabungan dengan relasi, hasil historis, atau slot unik yang bertentangan ditolak. Catatan waktu yang dipertahankan tetap terikat pada jadwal sumbernya. Aplikasi meminta tinjauan ulang jika data aktif berubah sebelum commit. Penghapusan dan penyisipan dilakukan dalam satu transaksi dalam urutan dependensi, dengan foreign key tetap aktif. Kegagalan memicu rollback. Rekonsiliasi pengingat berjalan sesudah commit.
- Restore menolak snapshot yang akan menyembunyikan profil tunggal di Tempat Sampah. Merge menolak status Trash yang berbeda untuk ID target bersama. Pengguna masih dapat meninjau mode Ganti Semua. Jika hasil Merge identik dengan data aktif saat konfirmasi, aplikasi melewati penulisan ulang dan mempertahankan progres pengingat perangkat.
- Cadence tersedia untuk 7, 14, 30, atau 1–365 hari khusus. Pemilih file memperbarui waktu backup terakhir setelah penyimpanan berhasil. Setelah berbagi, pengguna mengonfirmasi bahwa salinan sudah tersimpan di aplikasi tujuan. Penyedia cloud dikelola oleh OS dan mungkin belum selesai mengunggah saat berbagi selesai.

## Pustaka dan platform

| Pustaka | Versi lockfile | Pertimbangan |
| --- | --- | --- |
| `cryptography` | 2.9.0 | Pustaka lintas platform yang masih dipelihara. AES-GCM dan PBKDF2 tersedia di Dart untuk Android/iOS dengan format byte yang sama. |
| `file_picker` | 11.0.3 | Memilih dan menyimpan file melalui dialog Android/iOS. Podspec versi ini mendukung iOS 12. Seri 12 ke atas mensyaratkan iOS 14, sementara Routina menargetkan iOS 13. |
| `share_plus` | 11.1.0 | Share Sheet asli Android/iOS. Versi ini mendukung iOS 12 dan Android Gradle Plugin mulai 8.3. Seri 12 memakai AGP mulai 8.12.1, sementara proyek memakai 8.11.1. |

Sumber dokumentasi dan riwayat rilis. [cryptography 2.9.0](https://pub.dev/packages/cryptography/versions/2.9.0) · [file_picker](https://pub.dev/packages/file_picker/changelog) · [share_plus 11.1.0](https://pub.dev/packages/share_plus/versions/11.1.0) · [share_plus 12.0.2](https://pub.dev/packages/share_plus/versions/12.0.2)

Impor memakai pembaca dokumen native yang membatasi stream. File di atas 32 MiB ditolak sebelum dipindah ke isolate. Ekspor memakai encoder JSON UTF-8 bertahap dengan batas payload. File sementara yang dibuat saat ekspor atau berbagi hanya berisi ciphertext. SQLite staging memakai penyimpanan dalam memori. SQLite aktif dan jurnal transaksinya tetap merupakan data lokal yang dilindungi sandbox dan kebijakan OS. [Kebijakan backup platform](BACKUP_PLATFORM_POLICY.md)

Vektor Node.js/OpenSSL independen di `test/fixtures/backup_v1_vectors.cjs` memakai data sintetis dan memasukkan Unicode, deadline floating, manifest yang tidak cocok, dan ID ganda. Jalankan `node test/fixtures/backup_v1_vectors.cjs` untuk menghasilkan kembali konstanta fixture di `test/support/backup_vectors.dart`. Salt/nonce fixture deterministik. Jalur produksi mengambil 28 byte acak dengan `Random.secure()` pada setiap file. Salt 128 bit membedakan kunci turunan per ekspor dan nonce 96 bit diambil secara independen. Risiko tabrakan bersifat probabilistik. [Dart Random.secure](https://api.dart.dev/dart-math/Random/Random.secure.html)

## Risiko dan keputusan terbuka

- **Tinggi untuk rilis iOS.** Build, migrasi data perangkat, penanda pengecualian, picker, dan pertukaran file lintas OS berstatus PENDING.
- **Sedang.** Password lemah masih memungkinkan penebakan offline. PBKDF2 membatasi laju tebakan dan string password dapat memiliki salinan di heap Dart. Tinjauan parameter dan keputusan suite berikutnya tetap OPEN-11.
- **Sedang.** Kebutuhan memori mendekati batas file perlu diukur pada perangkat menengah ke bawah. Provider cloud mengendalikan unduhan dan salinan di luar sandbox aplikasi.
- **OPEN-05/06.** Arsip lama dapat membawa kembali ID yang sudah dihapus permanen karena skema tidak menyimpan tombstone purge. Pemilihan grup konflik Trash dan migrasi skema file yang lebih lama memerlukan kebijakan.
