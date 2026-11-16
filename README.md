# Routina

Flutter Android/iOS untuk perencana aktivitas personal offline. Fase 01 menyediakan shell navigasi Home, Kalender, To-Do List, Rutinitas, Profil, dan akses Statistik dari Home. Layar fitur yang belum diimplementasikan menampilkan pesan sementara.

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

Lihat [arsitektur](docs/ARCHITECTURE.md), [rencana fase](docs/IMPLEMENTATION_PLAN.md), dan [peta FigCraft](docs/FIGCRAFT_SCREEN_MAP.md).
