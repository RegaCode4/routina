# Release signing APK mandiri

Fase 19 · 18 November 2026. Pemilik memegang **app signing key** yang sama untuk setiap update APK langsung. Tidak diperlukan upload key atau Play App Signing untuk jalur ini. **PENDING:** kredensial pemilik dan fingerprint sertifikat belum diberikan; tidak ada production keystore yang dibuat.

## Konfigurasi lokal atau CI

Pilih satu sumber lengkap. Keberadaan salah satu environment variable memilih seluruh sumber environment; field yang hilang menyebabkan build gagal. Sumber tidak dicampur dengan file lokal.

| `android/key.properties` | Environment variable |
| --- | --- |
| `storeFile` | `ROUTINA_KEYSTORE_FILE` |
| `storePassword` | `ROUTINA_KEYSTORE_PASSWORD` |
| `keyAlias` | `ROUTINA_KEY_ALIAS` |
| `keyPassword` | `ROUTINA_KEY_PASSWORD` |

Salin [template tanpa rahasia](../android/key.properties.example) ke `android/key.properties` dan isi hanya secara lokal. Simpan keystore di luar repository, batasi ACL ke akun pemilik/build, dan gunakan path absolut dengan `/` pada Windows. Path relatif dibaca dari `android/`. Java properties memerlukan escaping `\` dan karakter khusus; jangan mengutip password dengan tanda petik karena petik menjadi bagian nilainya. Alternatif CI: secret store runner menyuntikkan keempat environment variable pada proses build sementara. Jangan menaruh nilai pada argumen command line, log, screenshot, artefak CI, atau file Gradle terlacak. Jangan menggunakan Gradle `--debug`/build scan saat kredensial tersedia.

`.gitignore` root melindungi `key.properties`, `.jks`, `.keystore`, `.p12`, `.pfx`, `.key`, `.pk8`, `.pem`, dan `.env*` lokal. `.gitignore` bukan perlindungan bagi rahasia yang pernah terlacak. Sebelum stage, periksa `git diff --cached`, `git ls-files` dan isi file yang akan dikomit; jangan memaksa `git add -f` pada rahasia.

Release tanpa kredensial gagal, termasuk `flutter build apk --release`. Alias debug standar ditolak. Tidak ada fallback debug signing. Opsi `ROUTINA_ALLOW_UNSIGNED_RELEASE=true` hanya membuka build audit unsigned; hasilnya tidak bisa dipasang sebagai rilis dan tidak boleh didistribusikan. Pipeline normal menghapus bypass tersebut untuk proses build dan memulihkan environment pemanggil sesudahnya.

## Verifikasi identitas signing

Pemilik mencatat fingerprint SHA-256 sertifikat dari keystore tepercaya, bukan mengambil nilai pertama dari APK yang belum dipercaya. Gunakan `keytool -list -v -keystore <path> -alias <alias>` secara lokal; masukkan password melalui prompt. Fingerprint sertifikat merupakan metadata publik; private key serta password tetap rahasia.

Setelah build, wajib jalankan `apksigner verify --verbose --print-certs <apk>` dari Android Build Tools. Hasil harus sukses, sertifikat harus cocok dengan catatan pemilik/versi terdahulu, dan bukan sertifikat Android Debug. Pipeline [prepare_android_apk.ps1](../tool/prepare_android_apk.ps1) menolak sertifikat debug, signer tambahan, dan fingerprint yang tidak sesuai. Pengecekan alias saja tidak membuktikan key produksi. Jangan mengubah APK setelah penandatanganan. [Signing Android](https://developer.android.com/studio/publish/app-signing) · [apksigner](https://developer.android.com/tools/apksigner)

## Kepemilikan, backup, dan pemulihan key

1. Pemilik menyetujui applicationId, penanggung jawab key, dan masa berlaku sertifikat sebelum membuat atau menyediakan key. Pembuatan key produksi memerlukan persetujuan tersendiri; fase ini tidak membuatnya.
2. Simpan keystore terenkripsi pada sedikitnya dua lokasi terpisah yang dikendalikan pemilik; satu salinan offline. Simpan password dan petunjuk pemulihan dalam password manager terpisah dari salinan key.
3. Catat alias, fingerprint sertifikat, tanggal kedaluwarsa, applicationId, penanggung jawab serta daftar versi yang ditandatangani. Jangan memasukkan private key/password dalam register publik.
4. Uji pemulihan backup pada lingkungan terisolasi: buka salinan keystore dan cocokkan sertifikat. Setelah key tersedia, tandatangani artefak uji dan verifikasi tanpa menerbitkannya. Catat tanggal uji.
5. Gunakan key yang sama untuk semua update. Kehilangan key dapat menghentikan jalur update in-place; mengganti key sembarangan menyebabkan signature mismatch. Insiden kompromi memerlukan rencana pemulihan/rotasi dan uji kompatibilitas tersendiri, bukan uninstall otomatis atau pembuatan pengganti diam-diam.

Backup signing key berbeda dari backup data `.routina`. Mengembalikan file planner tidak memulihkan identitas penandatanganan.
