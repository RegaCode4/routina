# Routina

Flutter Android/iOS untuk perencana aktivitas personal offline. Shell menyediakan Home, Kalender, To-Do List, Rutinitas, Profil, akses Statistik, dan panel Tambah aktivitas. Layar fitur dan formulir yang belum diimplementasikan menampilkan pesan sementara.

## Menjalankan proyek

Gunakan Flutter stable 3.41.2 dengan Dart 3.11.0 sebagai baseline pengembangan. Jalankan dari root proyek dengan perangkat atau emulator Android, atau simulator/perangkat iOS dari macOS dengan Xcode.

```sh
flutter pub get
flutter devices
flutter run
```

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

## Galeri design system

```sh
flutter run -t lib/presentation/design_system/widget_gallery.dart
```

Galeri menampilkan token, varian tombol dan kartu, status, input, aksi modal, dan navigasi dengan data contoh. Token dan tema tersimpan di `lib/presentation/design_system/neo_tokens.dart` dan `lib/presentation/design_system/neo_theme.dart`.

Acuan FigCraft menggunakan definisi komponen halaman 00 (ID 24–107), Home 390×844 (175), daftar tugas (5428), rutinitas (6958), Tambah aktivitas (13262), dan konfirmasi destruktif (14152). Ukuran dasar menggunakan margin 24 dp, FAB 56 dp dengan bayangan 4×4, dan navigasi 64 dp sebelum inset sistem. Kartu dan panel modal bertambah tinggi mengikuti teks. Saat teks besar, label To-Do List membungkus per kata dan label tab menyesuaikan lebar agar kelimanya tetap terlihat. Ikon memakai padanan Material dari ikon garis FigCraft.

Lihat [arsitektur](docs/ARCHITECTURE.md), [rencana fase](docs/IMPLEMENTATION_PLAN.md), dan [peta FigCraft](docs/FIGCRAFT_SCREEN_MAP.md).
