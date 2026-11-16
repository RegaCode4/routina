# Routina

Flutter Android/iOS untuk perencana aktivitas personal offline. Fase 03 menyediakan penyiapan awal, Home, kalender tiga tampilan, detail kegiatan, serta Quick Add dan Form Lengkap kegiatan. Tugas, Rutinitas, dan Statistik tetap dapat dibuka dari shell sesuai lingkup fase.

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

## Pratinjau SC-01 sampai SC-10

Peluncuran biasa membuka Splash dan onboarding. Gunakan contoh berikut untuk langsung membuka Home dengan profil contoh.

```sh
flutter run --dart-define=ROUTINA_PREVIEW=returning
```

| Skenario | Keadaan yang ditampilkan |
| --- | --- |
| `splash-error`, `onboarding-resume` | Gagal saat mulai dengan retry, atau melanjutkan onboarding dari langkah kedua. |
| `loading`, `home-error`, `calendar-error` | Baca mock secara tertunda atau gagal sekali dengan aksi muat ulang. |
| `empty`, `allDone`, `notifications-off`, `overdue` | Agenda kosong, semua selesai, pengingat dalam aplikasi, atau tugas overdue. |
| `conflict`, `buffer`, `crossMidnight`, `outsideHours` | Bentrok, peringatan buffer, lintas tengah malam, atau kegiatan di luar jam aktif di kalender. |
| `sunday-first`, `active` | Minggu dimulai Minggu atau kegiatan sedang berlangsung yang bisa dibuka dari agenda. |

Profil, pengingat pratinjau, hasil konfirmasi, dan kegiatan contoh hanya berlaku selama proses aplikasi. Hari contoh ditetapkan saat aplikasi dimulai. Peringatan jadwal membaca fixture dan rentang yang dipilih selama sesi. Pilihan zona kalender menampilkan pergeseran contoh WIB/WITA.

Lihat [arsitektur](docs/ARCHITECTURE.md), [rencana fase](docs/IMPLEMENTATION_PLAN.md), dan [peta FigCraft](docs/FIGCRAFT_SCREEN_MAP.md).
