# Android Developer Verification untuk APK langsung

Pemeriksaan dokumentasi resmi: **18 November 2026, Asia/Jakarta**. **Routina: PENDING / BELUM DAPAT DIVERIFIKASI.** Tidak ada bukti dari Android Developer Console, ID publik final, atau sertifikat pemilik yang tersedia. Tidak ada pendaftaran atau klaim verifikasi yang dilakukan pada fase ini.

## Cakupan yang berlaku dan jadwal berikutnya

Sejak **30 September 2026**, tahap awal berlaku bagi instalasi dari **toko peserta** di Indonesia, Brasil, Singapura dan Thailand pada perangkat Android bersertifikasi. Overview dan FAQ terkini menetapkan Android 8/API 26 ke atas. FAQ yang diperbarui 10 November 2026 perlu diprioritaskan terhadap salinan lama yang masih menyebut Android 7+. [Overview resmi](https://developer.android.com/developer-verification) · [FAQ resmi](https://developer.android.com/developer-verification/guides/faq)

FAQ membedakan sideload langsung dan toko di luar daftar peserta: jalur tersebut **belum terkena enforcement tahap September 2026**. Karena Routina menargetkan download langsung dari website, jangan menyatakan semua unduhan APK di Indonesia sudah dilarang tanpa verification. Dokumentasi menjadwalkan perluasan global pada **2027 dan sesudahnya**; tidak memberikan tanggal pasti enforcement untuk setiap unduhan website. Verifikasi identitas dan registrasi paket tetap harus dipersiapkan serta diperiksa ulang sebelum rilis. [Cakupan sideload dan jadwal FAQ](https://developer.android.com/developer-verification/guides/faq)

## Publik dan terbatas

| Jalur | Implikasi untuk Routina |
| --- | --- |
| Full distribution | Ditujukan untuk distribusi luas, tanpa batas aplikasi/instalasi akun. Membutuhkan verifikasi identitas dan kontak. Organisasi memiliki persyaratan tambahan seperti D-U-N-S serta website terverifikasi; dokumen bergantung lokasi. Download publik dari landing page sesuai kategori distribusi luas, bukan kelompok perangkat tertutup. [Panduan full distribution](https://developer.android.com/developer-verification/guides/full-distribution) |
| Limited distribution | Akun gratis untuk pelajar/hobi, tanpa ID pemerintah tambahan, dengan Google Account, verifikasi dua langkah, payments profile dan kontak. Perangkat memerlukan otorisasi pengguna melalui proses QR/link. Panduan khusus bertanggal 28 Oktober 2026 menyebut hingga **50 perangkat**, sementara kartu overview masih menyebut **20**. Konfirmasi batas aktual di konsol sebelum memilih jalur ini; jangan menjanjikan angka yang belum konsisten. Ini tidak memenuhi kebutuhan download publik tanpa batas. [Panduan limited distribution](https://developer.android.com/developer-verification/guides/limited-distribution) |

Panduan limited masih memuat kalimat cakupan regional September yang lebih umum. Untuk penentuan kanal website, catat perbedaan tersebut dan gunakan penjelasan sideload yang eksplisit pada FAQ terkini. Kebijakan ini harus dicek ulang menjelang publikasi.

## Bukti yang diperlukan dari pemilik

Gunakan **Android Developer Console** untuk distribusi khusus di luar Google Play. Pemilik menyelesaikan jenis akun dan verifikasi identitas, menentukan package name, lalu mendaftarkan SHA-256 sertifikat signing. Paket yang sudah ada dapat memerlukan APK bertanda tangan dengan challenge asset dari konsol sebagai bukti kepemilikan. Status `In review` belum sama dengan `Registered`. [Panduan registrasi resmi](https://developer.android.com/developer-verification/guides/android-developer-console)

Simpan tanggal pemeriksaan, package final, fingerprint sertifikat, tipe akun dan status `Registered` dari konsol resmi dalam register rilis; bukti identitas pribadi tetap disimpan secara privat. Pada fase ini bukti tersebut belum tersedia. API status baru disebut dalam dokumentasi, tetapi tidak ada kredensial atau hasil untuk identitas final Routina; tidak dilakukan integrasi API ataupun klaim berdasarkan nama aplikasi.

Jangan menjadikan ADB, advanced flow, perubahan pengaturan keamanan, atau penonaktifan Play Protect sebagai petunjuk distribusi konsumen. Jika instalasi diblokir perlindungan platform, panduan website harus meminta pengguna berhenti dan menghubungi kontak resmi.
