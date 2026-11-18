# Verifikasi perangkat Routina · Fase 18

Gunakan emulator terisolasi atau perangkat uji dengan data sintetis. Catat model, versi OS/API, build, zona awal, status izin dan kanal, serta apakah layar dikunci secara aman. Simpan bukti tanpa menyertakan password backup atau isi agenda pribadi.

## Cakupan otomatis

| Area | Bukti yang disiapkan |
| --- | --- |
| Timer dan SQLite | `test/data/routine_workspace_test.dart` menguji pergeseran jam maju dan mundur, perubahan zona dan tanggal, pembukaan ulang database, Jeda/Lanjut/Hentikan, penghentian ganda, dan konfirmasi status eksplisit. Pengujian backup memeriksa akumulasi waktu, format portable dan preservasi stamp timer lokal saat record tersebut dipertahankan. |
| Lifecycle native | `integration_test/device_lifecycle_test.dart` membaca jam monotonik Android dan membuka kembali SQLite native. Lifecycle, waktu dinding dan zona disimulasikan di harness. |
| Notifikasi | `test/data/local_reminders_test.dart` menguji izin dan fallback, berbagai jenis pengingat, pergeseran zona, Jam Tenang dan pengecualian, batas 60, optimasi ulang antrean setelah kegagalan, serta perubahan dan penghapusan aktivitas. Uji timer memeriksa identitas pengingat ketika jam dinding bergeser. |
| Aksesibilitas | `test/design_system_test.dart` memeriksa kontras token, label, target sentuh, layout dan dialog. `test/routine_screens_test.dart` memeriksa lima tab produksi dan semantik durasi pada 320 dp/200%. Tes layar lainnya mencakup state kosong, error, izin ditolak, form dan restore. |
| Regresi integritas | Suite host mencakup recurrence, DST, lintas tengah malam, Smart Scheduling, KPI dan minggu, filter, Tempat Sampah dan backup. Tes native offline, pencarian, serta backup menjalankan SQLite Android. |

## Hasil host dan emulator

Host Windows menjalankan format Dart, `flutter analyze --no-pub`, serta **117 unit test dan 45 widget test**. Harness memompa frame saat assertion SQLite menunggu dan memberi waktu bagi kontrol yang menunggu operasi SQLite. Percobaan awal terhenti pada lock harness dan satu pengulangan paralel dengan build Android melewati batas tunggu tombol validasi estimasi Smart Scheduling.

Empat tes integrasi Android lulus pada eksekusi per berkas. Cakupan mencakup alur offline, FR-09, restore v1 dengan rollback SQLite, dan lifecycle timer Android. Simulasi lifecycle diperbaiki agar mengikuti urutan state Flutter dan menggunakan penundaan nyata saat paused. Percobaan build gabungan kehilangan koneksi VM sebelum menjalankan assertion.

Emulator menerapkan Android 16/API 36 x86_64 dengan Wi-Fi dan data seluler mati. Fixture debug memakai profil, seri mingguan, tugas, dan rutinitas sintetis di SQLite. Android melaporkan cold dan warm start. Sleep/wake mempertahankan PID dan durasi bertambah dari 03:18 ke 03:33 termasuk waktu pemeriksaan. Jam dinding maju 20 menit. Setelah penghentian proses biasa timer masih mencatat 230 detik dan ID tetap sama. Force-stop menghasilkan `stopped=true`. Pembukaan eksplisit mengembalikan aplikasi dengan timer yang sama. Zona Bangkok → Tokyo melewati tengah malam. Profil, seri, tugas, occurrence, tanggal asal, dan status tetap konsisten. Salinan database sebelum dan setelah rekreasi lulus `integrity_check` dan `foreign_key_check`.

Swipe menghapus task Routina dari recent apps dari satu menjadi nol dan paket tetap `stopped=false`. Pada reboot normal, SQLite tetap utuh dengan ID dan status yang sama. Pengujian menyisipkan satu alarm tenggat mendatang yang masih `armed=false` untuk merepresentasikan interupsi pemasangan. Android mengeksekusi receiver sekitar 30 detik setelah mulai mendistribusikan `BOOT_COMPLETED`. Baris berubah ke `armed=true` ketika Launcher masih di depan. Pengukuran awal sebelum broadcast tiba menunjukkan baris masih menunggu.

Probe pertama yang menggabungkan perubahan jam dan reboot membawa pergeseran lama ke estimasi lintas boot. Implementasi akhir menyimpan ulang acuan waktu dinding saat perubahan teramati melalui rekonsiliasi dalam boot yang sama. Suite memeriksa acuan dan waktu aktual sebelum dan sesudah pembukaan SQLite.

Prompt Android muncul setelah menekan **Minta izin**. Penolakan menampilkan fallback Home dan tautan Settings. Pemberian dari Settings mengaktifkan antrean. Pencabutan dari Settings menghasilkan status ditolak dan antrean kosong setelah aplikasi dibuka. Alarm untuk kegiatan, deadline, pengulangan overdue, konfirmasi, target timer, dan backup terdaftar. Android mencatat pengiriman kegiatan, tenggat dan backup setelah loncatan waktu di background. Pengiriman tepat waktu, setiap jenis saat layar terkunci, Doze dan OEM tetap memerlukan verifikasi perangkat.

Jam Tenang 22.00–07.00 mengeluarkan pengingat tenggat dari antrean native pada data uji. Memilih pengecualian **Tenggat tugas** menambahkan kembali dua entri. Batas 60, pembatalan, perubahan jadwal dan tipe pengingat lain diperiksa oleh suite host.

SC-16 berjalan dan dipulihkan serta SC-25 izin ditolak dibandingkan dengan raster FigCraft 7825, 7932, dan 11029. Render timer mempertahankan kartu biru, angka monospaced, aksi berlabel dan hard shadow. Pesan pemulihan tampil sebelum riwayat. Render penolakan menempatkan tombol Settings di kartu peringatan dan memberi label terpisah pada preferensi pengiriman. Tree Android menampilkan posisi dan pilihan tab, label tindakan, dan satu nilai timer dalam jam, menit dan detik. Sampling ini melengkapi tinjauan struktur seluruh kelompok SC-01–SC-30. Urutan baca yang diucapkan dan pengumuman TalkBack tetap MANUAL PENDING.

## Checklist perangkat

Seluruh baris di bagian ini berstatus **MANUAL PENDING** untuk perangkat Android fisik. Ulangi di iOS pada perangkat yang didukung. Simpan hasil per baris berikut waktu dan bukti.

- [ ] Lakukan onboarding dan tambah agenda berulang dengan pengecualian, agenda lewat tengah malam, tugas, rutinitas dan satu catatan aktual saat jaringan mati. Catat ID atau detail pembeda serta jumlah sebelum dan sesudah cold start, pindah ke Home Android, kembali aktif, swiping dari recent apps, penghentian proses saat background, dan reboot.
- [ ] Mulai timer. Kunci layar dengan metode perangkat, tunggu dengan stopwatch pembanding lalu buka kembali. Gunakan Jeda, Lanjutkan dan Hentikan. Ulangi dengan process recreation dan loncatan waktu maju/mundur dalam boot yang sama. Periksa durasi aktif, riwayat tunggal, serta konfirmasi target tanpa Selesai otomatis. Ulangi perubahan tanggal dan zona. Kembalikan pengaturan waktu setelah tes.
- [ ] Coba izin belum diminta, penolakan lewat dialog, pemberian dari Settings dan pencabutan. Periksa fallback Home, pengaturan kanal, respons ketika kembali ke aplikasi, dan pengiriman nyata pada layar biasa serta lock screen. Catat Android 12 atau lebih lama serta Android 13 atau lebih baru bila tersedia.
- [ ] Jadwalkan pengingat kegiatan, tenggat dan overdue, konfirmasi, target timer, serta backup. Amati Jam Tenang lintas tengah malam dan pengecualian. Geser jadwal, tunda, selesaikan dan hapus; periksa notifikasi lama hilang. Uji Doze, penghemat baterai, DND dan pengaturan OEM, serta iOS Focus.
- [ ] Uji tiga kondisi terpisah untuk notifikasi. Setelah penghentian proses biasa, periksa alarm yang sudah didaftarkan. Setelah reboot dan unlock, amati rearm sebelum membuka Routina. Setelah force-stop, cek keadaan paket dan alarm, lalu buka Routina dan periksa rekonsiliasi.
- [ ] Ulangi restore Ganti Semua dan Merge memakai fixture uji. Periksa jumlah, relasi, recurrence, histori dan backup setelah salah password, data rusak, kekurangan ruang serta operasi terputus. Transfer file yang sama Android ↔ iOS.
- [ ] Dengan TalkBack atau VoiceOver, jelajahi onboarding, lima tab, Statistik, Pengaturan/izin, Backup/Restore, Tempat Sampah dan Quick Add. Catat urutan baca, fokus dialog dan bottom sheet, tombol berlabel, error dan pengumuman setelah aksi. Ulangi pada 320 dp atau ekuivalen, teks 200%, dengan keyboard eksternal dan keyboard layar. Gunakan keadaan dipilih, badge status dan pesan untuk memastikan makna tersedia melalui teks atau semantik.

## Perilaku platform dan keputusan terbuka

- Timer Android memakai `elapsedRealtimeNanos()` selama sampel berasal dari boot yang sama. Pengukuran ini mencakup suspend. Rekonsiliasi menyelaraskan acuan cadangan saat loncatan jam sempat teramati dalam boot yang sama. Setelah boot berubah atau sampel tidak tersedia, timer memakai estimasi waktu dinding yang dibatasi minimum nol. Loncatan jam yang belum teramati sebelum reboot dan waktu perangkat mati dapat memengaruhi estimasi. Kebijakan durasi lintas boot dan UX force-stop tetap OPEN-08. [Android SystemClock](https://developer.android.com/reference/android/os/SystemClock)
- Antrean dapat dipasang ulang oleh receiver Android setelah boot normal dan unlock. Force-stop dan pembatasan latar belakang membatasi pemulihan/pengiriman. Estimasi alarm target timer yang kehilangan acuan boot atau jam dinding menunggu rekonsiliasi ketika aplikasi aktif kembali. [Batas notifikasi](NOTIFICATIONS.md)
- VoiceOver, build native iOS, permintaan izin, pengiriman, pemindahan DB dan transfer silang platform berstatus **PENDING** pada host Windows.
- Kebijakan produk tentang nama kategori duplikat tetap OPEN. Kasus lain yang menahan distribusi publik dilacak pada [kesiapan rilis](RELEASE_READINESS.md).

## Fase 20A · identitas dan branding

Enam skenario integrasi pada lima berkas lulus menggunakan ID baru `com.regacode.routina`: offline setup/input/reload/statistik, search, lifecycle, backup v1/rollback, native picker valid/terlalu besar/batal, serta identity/clock/zona/receiver. Notifikasi sintetis tercatat pada NotificationManager dengan package ID baru. AVD API 36 terisolasi digunakan setelah emulator awal kekurangan ruang; data instalasi lama tidak dihapus.

[BRANDING_QA.md](BRANDING_QA.md) memuat screenshot launcher circle, native splash, Flutter startup, onboarding, Home dan pemilih dokumen. Cakupan ini memverifikasi inti visual brand pada API 36; themed rendering, mask OEM lain, runtime API 24–30 dan perangkat fisik tetap MANUAL PENDING. Eksplorasi onboarding 320 dp/200% menunjukkan overflow layout lama, sedangkan state startup baru pada ukuran tersebut lulus tes. Checklist perangkat di atas tetap berlaku.
