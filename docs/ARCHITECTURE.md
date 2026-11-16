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
| Routing | Gunakan `IndexedStack` dan `NavigationBar` untuk menjaga pohon widget lima tab. Statistik adalah `MaterialPageRoute` yang didorong dari Home, sehingga Back kembali ke Home dan tab keenam tidak diperlukan. `/statistik` adalah identitas route internal dan belum menjadi deep link. Tinjau router deklaratif kalau alur notifikasi, deep link atau stack per tab muncul pada fase berikutnya. [Navigasi Flutter](https://docs.flutter.dev/ui/navigation) |
| Dependency injection | Gunakan injeksi konstruktor dan satu composition root. Dependency terlihat di API dan mudah diganti dalam unit/widget test. Objek dibuat sedekat mungkin dengan pemilik lifecycle. |
| Penyimpanan | Pilih SQLite melalui Drift sebagai pendekatan untuk fase data. ID dan foreign key cocok untuk relasi task/sesi/rutinitas dan deduplikasi. Transaksi mendukung perubahan multi-sesi dan restore atomik, query terindeks mendukung kalender dan statistik, dan schema berversi mendukung migrasi. Database menjadi satu sumber data lokal. [Dokumentasi Drift](https://drift.simonbinder.eu/) |
| Dependency storage | Package, executor SQLite dan skema belum dipasang. Verifikasi kompatibilitas Android/iOS, constraint relasi, dan migrasi sebelum mengaktifkan schema pertama. Pembentukan kontrak bisnis dan keputusan OPEN tetap mengikuti PRD. |
| Tema dan bahasa | Gunakan palet FigCraft untuk shell light dan font Bricolage Grotesque yang tersedia lokal. SDK `flutter_localizations` memberi locale `id` untuk tanggal, tooltip Back dan semantik widget standar. App icon, pilihan font final dan rincian visual masih mengikuti review desain. |

Pilihan di tabel adalah keputusan teknis Fase 01. Aturan produk yang **CONFIRMED**, rincian yang **PROPOSED**, dan keputusan bisnis yang **OPEN** tetap tercatat di [PRD.md](../PRD.md) dan rencana implementasi.

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
