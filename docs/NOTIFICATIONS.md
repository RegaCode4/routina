# Pengingat lokal dan Jam Tenang

SQLite menyimpan pilihan pengingat, jam tenang, pengecualian, dan penundaan. Setelah transaksi pengubah jadwal berhasil, Routina menghitung kembali permintaan pengiriman dari agenda aktif dan menyelaraskan antrean sistem. Rutinitas yang memiliki blok waktu memakai aturan pengingat dari rutinitas induknya. Forecast target timer mengikuti Start, Jeda, Lanjut, dan Stop. Penyelesaian, penundaan, pengecualian pengulangan, dan item di Tempat Sampah menghapus permintaan lama yang sudah tidak relevan. Home menampilkan pengingat yang masih relevan dan yang jatuh tempo dalam 24 jam ke depan, termasuk saat pengiriman sistem dinonaktifkan.

## Keputusan fase

Nilai awal, horizon antrean, dan perlakuan pengingat selama Jam Tenang berstatus **PROPOSED** sesuai OPEN-02 dan OPEN-08.

- Jam Tenang memakai jam perangkat setiap hari. Jam mulai termasuk dalam periode, jam selesai berada di luarnya, dan interval dapat melewati tengah malam. Saat pertama diaktifkan, jam yang sudah digunakan pengaturan lokal adalah 22.00–07.00. Pengingat biasa yang jatuh selama Jam Tenang dilewatkan untuk pengiriman sistem dan tetap terlihat di Home selama relevan. Jenis yang dikecualikan tetap tunduk pada izin, Focus, dan Jangan Ganggu.
- Pilihan awal konfirmasi kegiatan dan tugas overdue adalah satu pengingat setelah 30 menit. Pengguna dapat mengatur batas 0–10 serta jeda 1–1.440 menit. Pengingat pra-kegiatan dan tenggat dapat memiliki beberapa offset, termasuk waktu khusus sampai tujuh hari.
- Ringkasan pagi mulai dijadwalkan setelah pengguna memilih jam. Pengingat backup memakai interval yang dipilih dan dihitung dari saat pengaturan itu berubah. Perubahan profil lain mempertahankan jadwal backup. Alur ekspor dan pemulihan nyata merupakan lingkup FR-13.
- Tunda 10 menit tersedia di daftar pengingat Home untuk pengingat yang sudah jatuh tempo. Penundaan tetap mengikuti Jam Tenang dan batal saat pengingat asal kehilangan relevansi. Pengingat bentrok dicatat per pasangan jadwal. Konflik yang sama tidak dijadwalkan ulang setiap kali Home dibuka.
- Jendela pengingat agenda mencakup 45 hari. Ringkasan pagi diproyeksikan untuk 14 hari ke depan, dan pengingat backup terdekat mengikuti intervalnya. Aplikasi mengirim hingga 60 permintaan ke antrean sistem, dengan pengingat yang lebih awal diprioritaskan. Antrean diisi kembali saat aplikasi dibuka, kembali aktif, atau perubahan lokal disimpan. Ketika aplikasi lama tidak dibuka, pengingat di luar antrean tersedia setelah rekonsiliasi berikutnya.

## Android

Android 13 ke atas memakai izin `POST_NOTIFICATIONS` saat pengguna memilih mengaktifkan pengiriman atau menekan **Minta izin**. Layar pengaturan menggunakan status izin dan kanal Routina dari perangkat. Tombol **Buka Pengaturan Sistem** membuka pengaturan notifikasi aplikasi. [Izin runtime Android](https://developer.android.com/develop/ui/compose/notifications/notification-permission)

`AlarmManager.setAndAllowWhileIdle` memakai alarm inexact. Doze, penghemat daya, pengaturan vendor, dan banyak alarm yang berdekatan dapat menunda pengiriman. Receiver memeriksa izin, masa berlaku, zona perangkat, dan Jam Tenang sebelum menampilkan notifikasi. Aplikasi tidak meminta akses alarm eksak atau akses untuk melewati Jangan Ganggu. [Penjadwalan alarm Android](https://developer.android.com/develop/background-work/services/alarms)

Receiver memulihkan antrean yang masih relevan setelah boot normal atau pembaruan paket. Antrean memakai penyimpanan yang tersedia setelah pengguna membuka kunci perangkat seusai boot. Perubahan jam sistem memicu pemasangan ulang alarm. Setelah perubahan zona, alarm dengan waktu absolut tetap berlaku. Alarm yang dihitung dari jam perangkat menunggu proyeksi baru saat Routina dibuka. Force stop dapat membatalkan alarm hingga pengguna membuka aplikasi lagi. [Pengecualian broadcast Android](https://developer.android.com/develop/background-work/background-tasks/broadcasts/broadcast-exceptions) · [Perilaku force stop Android](https://developer.android.com/about/versions/15/behavior-changes-all#stopped-state)

## iOS

Routina meminta otorisasi alert dan suara melalui `UNUserNotificationCenter` setelah tindakan pengguna. iOS 16 ke atas membuka pengaturan notifikasi aplikasi secara langsung. Versi lebih lama membuka halaman pengaturan aplikasi. Focus dan pengaturan tampilan iOS menentukan bagaimana pengingat muncul. [Otorisasi Apple](https://developer.apple.com/documentation/UserNotifications/asking-permission-to-use-notifications) · [Tautan pengaturan Apple](https://developer.apple.com/documentation/uikit/uiapplication/opennotificationsettingsurlstring)

Sistem memegang permintaan lokal yang sudah didaftarkan, termasuk ketika Flutter berhenti berjalan. Saat Routina kembali aktif, aplikasi membaca izin serta antrean, menghitung ulang zona perangkat, dan mengganti permintaan yang berubah. Jika zona berubah ketika aplikasi berada di background, iOS dapat mengirim permintaan lama sebelum rekonsiliasi, termasuk menurut proyeksi Jam Tenang sebelumnya. Pengingat yang belum masuk antrean membutuhkan aplikasi aktif untuk dijadwalkan. [Penjadwalan notifikasi lokal Apple](https://developer.apple.com/documentation/UserNotifications/scheduling-a-notification-locally-from-your-app)

## Cakupan verifikasi

- Emulator Android API 36 menyelesaikan onboarding tanpa prompt. Mengaktifkan pengiriman memunculkan prompt perangkat. Penolakan tampil di SC-25 dan tautan pengaturan membuka notifikasi aplikasi. Setelah izin diaktifkan dari Settings, dua alarm backup terdaftar.
- Dua alarm backup kembali terdaftar setelah reboot dan unlock saat launcher masih aktif. Antrean diperiksa setelah perubahan zona perangkat dan aplikasi dibuka ulang. Dengan waktu emulator dimajukan melewati jadwal pertama, satu notifikasi backup teramati di NotificationManager saat aplikasi berada di background. Pengujian ini memeriksa alur pengiriman dan pemulihan, dengan presisi waktu bergantung pada OS.
- Render SC-25 untuk izin ditolak dan Jam Tenang aktif dibandingkan dengan FigCraft. Pengaturan menyimpan perubahan setelah pengguna mengubah kontrol. Uji widget memeriksa fallback Home dan pengaturan Jam Tenang pada skala teks 200%. Suite SQLite memeriksa pergeseran zona asal/lokal, pengulangan, penghapusan, dan penjadwalan ulang.
- Simulator atau perangkat iOS belum tersedia pada host Windows. Kompilasi, reboot, pengiriman background, izin, dan perubahan zona pada iOS masih perlu verifikasi di perangkat Apple.
