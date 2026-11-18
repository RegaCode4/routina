# Peta layar FigCraft Routina

Audit Fase 00, 16 November 2026. Sumber pemetaan [DESIGN.md §5](../DESIGN.md#5-spesifikasi-layar-dan-state). Keputusan produk dan dampak fase dicatat di [rencana implementasi](IMPLEMENTATION_PLAN.md).

## Artefak dan cara memeriksa

| Artefak | Observasi audit | Penggunaan |
| --- | --- | --- |
| [Personal Planner - Flutter UI Design.figcraft](../Personal%20Planner%20-%20Flutter%20UI%20Design.figcraft) | Arsip ZIP berisi `document.json` dan `thumbnail.png` (296×400). FigCraft MCP membukanya sebagai dokumen 12 halaman, 11.878 layer di luar node halaman, 27 variabel, 35 definisi komponen dan 315 artboard layar. Semua 315 artboard berukuran 390×844. | Referensi struktur, node ID, token, bounds, tipe, teks, vektor, state dan interaksi. Tidak ada raster tertanam pada struktur dokumen yang dilaporkan MCP. |
| [Personal Planner - Preview.png](../Personal%20Planner%20-%20Preview.png) | Raster PNG 390×844. Visual Home memuat lima KPI, agenda, FAB, dan lima tab. Preview sesuai contoh layar Home yang diperiksa. | Ekspor acuan visual Home. |
| [referensi.webp](../referensi.webp) | Kolase raster WebP planner eksternal. Memuat contoh onboarding, kalender, FAB dan kartu, termasuk CTA `Create Account`. | Inspirasi komposisi. **CONFIRMED** · MVP memakai palet Routina, profil lokal dan penggunaan offline. CTA akun dari kolase tidak berlaku. |
| [assets/font/](../assets/font/) | 113 berkas terlacak. Bricolage Grotesque menyediakan 1 TTF variabel, 105 TTF statis, README dan OFL. Space Mono menyediakan 4 TTF dan OFL. Kedua lisensi yang disertakan adalah SIL OFL 1.1. | Kedua keluarga digunakan pada node teks FigCraft. **OPEN** · Pilihan tipografi, ikon, identitas dan packaging font final. |
| Ikon dan token | Ikon dapat diperiksa sebagai layer vektor. Tidak ditemukan ekspor SVG atau paket ikon terpisah di repo. Halaman `00 · Design System` memuat frame token (ID 2, 1344×480) serta komponen. | **PROPOSED** · Petakan ikon/token ke widget dan aset lokal yang dibutuhkan setelah review, tanpa bergantung pada screenshot. |

Halaman MCP diperiksa secara rekursif untuk nama, ukuran, teks, komponen, dan relasi navigasi. Sumber dibuka tanpa menyimpan perubahan. Bukti visual berupa pemeriksaan preview Home, kolase referensi, serta render sampel MCP untuk Home, profil lokal, detail tugas, timer rutinitas, proposal split, Statistik mingguan, izin notifikasi, dan konflik restore. Pengujian visual Flutter dan validasi pixel-per-pixel belum berlaku.

## Tambahan branding · 18 November 2026

FigCraft MCP headless menambahkan halaman **12 · Branding & Launch** (14726) pada dokumen sumber, dengan **18 frame branding**. Halaman 00–11, 315 artboard layar dan flow sebelumnya dipertahankan. Ini tambahan desain setelah Fase 19, bukan penggantian pemetaan SC-01–SC-30 atau implementasi startup.

Rekomendasi untuk review: `BRAND_Icon_Final` (14762, 1024×1024), berdasarkan `BRAND_Icon_Exploration_01`, dan `BRAND_Splash_Final` (14756, 390×844). Tiga eksplorasi ikon, dua splash, adaptive foreground/background/composite, tiga preview mask, monochrome, safe zone, proof ukuran kecil, aset splash Android 12+, dan papan review tersedia. [Inventory seluruh nama/ID frame dan ekspor](BRANDING.md#sumber-desain-dan-inventory-frame).

**CONFIRMED Fase 20A:** pemilik menyetujui seluruh paket 01 / Ember, adaptive + monochrome, Ember `#EE613E`, dan splash tanpa wordmark. ID `com.regacode.routina` serta aset diterapkan ke Android. Token tambahan kini bernama `brand/ember` (VariableID:28). Catatan persetujuan pada halaman 12 diperbarui tanpa mengubah bentuk mark atau frame SC-01–SC-30. [Bukti render launcher, native splash, Flutter dan integrasi API 36](BRANDING_QA.md) tersedia; mask selain circle dan themed rendering launcher tetap tercatat belum diverifikasi.

## Komponen yang dapat dibaca

| Area | Nama komponen aktual pada halaman 00 |
| --- | --- |
| Shell | `AppHeader` (24), `BottomNav` (29), `FABAdd` (42) |
| Aksi, form, dan kalender | `NeoButton / Primary` (45), `NeoButton / Secondary` (48), `NeoButton / Disabled` (51), `NeoButton / Danger` (54), `FormInput` (87), `DatePicker` (91), `TimePicker` (95), `CalendarCell` (99), `RecurrencePicker` (136), `ReminderEditor` (140) |
| Kartu, label dan progres | `NeoCard` (57), `KpiTile` (61), `ActivityCard` (65), `TaskCard` (69), `RoutineCard` (73), `CategoryChip` (77), `StatusBadge` (82), `ProgressBar` (111) |
| State dan overlay | `ConfirmDialog` (103), `BottomSheet` (107), `InlineNotificationWarning` (116), `EmptyState` (124), `LoadingState` (128), `ErrorState` (132), `ConflictBanner` (144) |
| Domain | `TimeSlotSuggestion` (120), `SessionPlanCard` (148), `TimerPanel` (152), `ComparisonChart` (156), `TrashItemCard` (160), `PasswordField` (164), `BackupConflictDiff` (168) |

**CONFIRMED** · Palet utama, outline tebal, shadow keras, dan status yang dapat dipahami lewat teks/ikon mengikuti [DESIGN.md §2–3](../DESIGN.md#2-design-tokens). `DateTimePicker` pada inventory DESIGN direpresentasikan sebagai `DatePicker` + `TimePicker` di FigCraft. Tidak ada definisi mandiri bernama `NeoButton / Loading`. State loading tersedia sebagai komponen umum dan frame, sehingga **PROPOSED** · evaluasi konstruksi state tombol saat menyiapkan widget dan semantik.

## Pemetaan 30 kelompok layar

`Terpetakan` berarti ditemukan grup frame aktual yang cocok dengan kelompok layar. Kolom frame menunjukkan ID yang dapat dibuka dengan FigCraft MCP. Hitungan meliputi varian, termasuk overlay atau frame lintas halaman. Pemetaan struktural belum merupakan review seluruh isi dan semua jalur klik.

| Kelompok DESIGN | Halaman FigCraft | Status · jumlah | Frame utama dan varian pilihan | Cakupan dan catatan |
| --- | --- | --- | --- | --- |
| SC-01 · Splash Screen | 02 | Terpetakan · 4 | `SC01_Splash_Default` (950), `SC01_Splash_Returning` (14683), `SC01_Splash_Loading` (968), `SC01_Splash_LocalError` (987) | Startup, pengguna kembali, loading, dan kegagalan data lokal. |
| SC-02 · Onboarding | 02 | Terpetakan · 5 | `SC02_Onboarding_Introduction` (1008), `SC02_Onboarding_Scheduling` (1071), `SC02_Onboarding_Offline` (1136), `SC02_Onboarding_LargeText` (1201), `SC02_Onboarding_Resume` (1266) | Tiga langkah, teks besar, dan resume. Kebijakan skip **OPEN**. |
| SC-03 · Profil lokal & preferensi awal | 02 | Terpetakan · 7 | `SC03_Setup_Profile` (1287), `SC03_Setup_ActiveHours` (1331), `SC03_Setup_InvalidInterval` (1437), `SC03_Setup_Saved` (1490), `SC03_Setup_OptionalPermission` (1511) | Profil, tujuh hari, validasi dan izin opsional. Field profil dan nilai awal **OPEN**. |
| SC-04 · Home Dashboard | 01 | Terpetakan · 12 | `SC04_Home_Default` (175), `SC04_Home_Empty` (252), `SC04_Home_Loading` (308), `SC04_Home_Error` (366), `SC04_Home_PendingConfirmation` (498), `SC04_Home_NotificationDenied` (649) | Lima KPI, agenda, pending dan fallback izin. Tautan ikon pengingat perlu ditinjau. |
| SC-05 · Kalender Bulanan | 03 | Terpetakan · 10 | `SC05_Calendar_Month` (1535), `SC05_Calendar_EmptyDay` (1868), `SC05_Calendar_ManyItems` (2027), `SC05_Calendar_BusyAllDay` (2187), `SC05_Calendar_CrossMidnight` (2507), `SC05_Calendar_DatePicker` (3119) | Bulan, daftar tanggal, Sibuk all-day, lintas hari, dan date picker. |
| SC-06 · Kalender Mingguan | 03 | Terpetakan · 6 | `SC06_Calendar_Week` (1695), `SC06_Calendar_Overlap` (3159), `SC06_Calendar_Buffer` (3260), `SC06_Calendar_Timezone` (3358), `SC06_Calendar_CrossMidnight` (3455), `SC06_Calendar_WeekStartSunday` (3556) | Sibuk/Tersedia, overlap, buffer, zona, lintas hari, awal Minggu. Panah periode perlu ditinjau. |
| SC-07 · Kalender Harian | 03 | Terpetakan · 6 | `SC07_Calendar_Day` (1792), `SC07_Calendar_Empty` (3653), `SC07_Calendar_Loading` (3706), `SC07_Calendar_Overlap` (3759), `SC07_Calendar_DeadlineSameHour` (3839), `SC07_Calendar_OutsideActive` (3916) | Linimasa, loading, kosong, overlap, deadline bersamaan dan di luar jam aktif. |
| SC-08 · Detail Kegiatan | 04 | Terpetakan · 9 | `SC08_Event_Upcoming` (3996), `SC08_Event_Pending` (4183), `SC08_Event_Postponed` (4255), `SC08_Event_Skipped` (4292), `SC08_Event_Trashed` (4329), `SC08_Event_RecurringException` (4366) | Status temporal/hasil, trash, exception. Cakupan edit/hapus di SC-30. |
| SC-09 · Quick Add Kegiatan | 04 | Terpetakan · 8 | `SC09_EventQuick_Default` (4033), `SC09_EventQuick_Required` (4437), `SC09_EventQuick_InvalidEnd` (4473), `SC09_EventQuick_Conflict` (4509), `SC09_EventQuick_BufferWarning` (4548), `SC09_EventQuick_OutsideActive` (4587) | Input wajib, validasi urutan waktu, serta warning konflik, buffer, dan jam aktif. |
| SC-10 · Form Lengkap Kegiatan | 04 | Terpetakan · 12 | `SC10_EventForm_Default` (4069), `SC10_EventForm_Preserved` (4647), `SC10_EventForm_MultipleReminders` (4725), `SC10_EventForm_MonthlyCustom` (4803), `SC10_EventForm_SplitSeries` (4963), `SC10_EventForm_AllDayFree` (5202), `SC10_EventForm_AllDayBusy` (5277) | Draft, reminder multipel, recurrence, all-day Tersedia/Sibuk, serta field lanjutan. |
| SC-11 · To-Do List | 05 | Terpetakan · 10 | `SC11_Todo_Default` (5428), `SC11_Todo_Empty` (5638), `SC11_Todo_Overdue` (5749), `SC11_Todo_NoMatch` (5929), `SC11_Todo_Search` (6035), `SC11_Todo_Filters` (6092) | Daftar kosong/selesai/overdue, pencarian, filter dan error. |
| SC-12 · Detail Tugas | 05 | Terpetakan · 8 | `SC12_Task_Default` (5495), `SC12_Task_ChecklistComplete` (6133), `SC12_Task_WithSessions` (6244), `SC12_Task_Mismatch` (6299), `SC12_Task_NoSessions` (6354), `SC12_Task_ManualSession` (6409) | Checklist 100%, metrik aktual, sesi dan selisih. Input aktual dan detail sesi tersimpan masih memiliki celah. |
| SC-13 · Quick Add & Form Lengkap Tugas | 05 | Terpetakan · 14 | `SC13_TaskQuick_Default` (5550), `SC13_TaskForm_Default` (5582), `SC13_TaskQuick_PastDeadline` (6504), `SC13_TaskForm_Preserved` (6616), `SC13_TaskForm_TimezoneFloating` (6672), `SC13_TaskForm_PermissionOff` (6784), `SC13_TaskForm_Subtasks` (6917) | Tanggal/jam tenggat, draft, validasi, mode waktu, izin dan checklist. |
| SC-14 · Rutinitas | 06 | Terpetakan · 6 | `SC14_Routines_Default` (6958), `SC14_Routines_Empty` (7140), `SC14_Routines_GoalPending` (7182), `SC14_Routines_Missed` (7245), `SC14_Routines_TimerRunning` (7308), `SC14_Routines_PartialHistory` (7371) | Daftar, target tercapai menunggu status, timer dan riwayat parsial. |
| SC-15 · Quick Add & Form Lengkap Rutinitas | 06 | Terpetakan · 11 | `SC15_RoutineQuick_Default` (7021), `SC15_RoutineForm_Duration` (7087), `SC15_RoutineForm_Checklist` (7538), `SC15_RoutineForm_Count` (7591), `SC15_RoutineForm_Weekly` (7644), `SC15_RoutineForm_Invalid` (7697) | Quick Add dan form dengan tipe target, validasi, dan draft. |
| SC-16 · Detail Rutinitas & Timer | 06 | Terpetakan · 10 | `SC16_Timer_Idle` (7053), `SC16_Timer_Running` (7825), `SC16_Timer_Paused` (7862), `SC16_Timer_Stopped` (7899), `SC16_Timer_Restored` (7932), `SC16_Timer_GoalNoPermission` (8000), `SC16_Timer_Manual` (8068), `SC16_Timer_History` (8097) | Start/Pause/Stop, pemulihan, target tanpa izin, input manual, dan riwayat. |
| SC-17 · Smart Scheduling · Pra-pencarian | 07 | Terpetakan · 6 | `SC17_Smart_Default` (8138), `SC17_Smart_Replanning` (8342), `SC17_Smart_EstimateConfirmed` (8385), `SC17_Smart_DeadlineInvalid` (8428), `SC17_Smart_MissingEstimate` (8474) | Tenggat, estimasi dan batas sesi. Nilai numerik contoh. Alur edit estimasi perlu ditinjau. |
| SC-18 · Smart Scheduling · Hasil rekomendasi | 07, 11 | Terpetakan · 8 | `SC18_Smart_Split` (8181), `SC18_Smart_OneSlot` (8564), `SC18_Smart_Selected` (8599), `SC18_Smart_Stale` (8641), `SC18_Smart_NoFeasible` (8703), `SC18_Smart_Saved` (8724), `SC18_Smart_OneSaved` (14365) | Satu/split, dipilih, stale, gagal, tersimpan. Konfirmasi di SC-30. |
| SC-19 · Smart Scheduling · Kendala dan alternatif | 07 | Terpetakan · 7 | `SC19_Smart_NoSlot` (8221), `SC19_Smart_Insufficient` (8745), `SC19_Smart_MaxSessions` (8789), `SC19_Smart_MinDuration` (8833), `SC19_Smart_Persistent` (8877), `SC19_Smart_Adjust` (8921) | Alasan kegagalan, alternatif dan pengubahan batasan. |
| SC-20 · Smart Scheduling · Konflik dan optimasi ulang | 07 | Terpetakan · 7 | `SC20_Smart_Conflict` (8265), `SC20_Smart_MultiConflict` (8988), `SC20_Smart_NoSolution` (9027), `SC20_Smart_Retained` (9064), `SC20_Smart_Scope` (9101), `SC20_Smart_ReplanOnly` (9137), `SC20_Smart_ReplanAll` (9174) | Konflik tunggal/jamak, cakupan, rencana dipertahankan, preview dan hasil. |
| SC-21 · Smart Scheduling · Selisih sisa durasi | 07 | Terpetakan · 8 | `SC21_Smart_Shortage` (8303), `SC21_Smart_Match` (9218), `SC21_Smart_Surplus` (9253), `SC21_Smart_NoAdjustment` (9292), `SC21_Smart_Retained` (9331), `SC21_Smart_Proposed` (9366), `SC21_Smart_Approved` (9393), `SC21_Smart_Cancelled` (9414) | Sesuai/kurang/lebih, pertahankan, perubahan usulan, disetujui dan batal. |
| SC-22 · Statistik Produktivitas | 08 | Terpetakan · 15 | `SC22_Stats_Week` (9438), `SC22_Stats_Day` (9501), `SC22_Stats_Month` (9556), `SC22_Stats_Comparison` (9610), `SC22_Stats_EmptyDay` (9722), `SC22_Stats_Partial` (9792), `SC22_Stats_WeekStartChanged` (9846) | Hari/minggu/bulan, pembanding, hari kosong, dua metrik, perubahan awal minggu. |
| SC-23 · Profil & Pengaturan | 09 | Terpetakan · 10 | `SC23_Profile_Default` (10115), `SC23_Profile_Saved` (10330), `SC23_Profile_Incomplete` (10403), `SC23_Profile_BackupDue` (10476), `SC23_Profile_NotificationsDenied` (10549), `SC23_Profile_CalendarSettings` (10715), `SC23_Profile_Timezone` (10749) | Profil lokal, status, kalender/zona waktu, buffer dan entry point fitur. |
| SC-24 · Pengaturan Jam Aktif | 09 | Terpetakan · 6 | `SC24_ActiveHours_Edit` (10188), `SC24_ActiveHours_InvalidOverlap` (10865), `SC24_ActiveHours_TimezoneChanged` (10919), `SC24_ActiveHours_Day` (10973), `SC24_ActiveHours_Preferences` (10999) | Editor tujuh hari, overlap, zona dan preferensi. Peringatan jam aktif manual di SC-09/30. |
| SC-25 · Notifikasi & Quiet Hours | 09 | Terpetakan · 13 | `SC25_Notifications_Default` (10242), `SC25_Notifications_Denied` (11029), `SC25_Notifications_Granted` (11119), `SC25_Notifications_FocusCaveat` (11162), `SC25_Notifications_SchedulingError` (11248), `SC25_Notifications_QuietHours` (11293), `SC25_Notifications_Exceptions` (11336) | Izin, fallback, Focus, Jam Tenang, pengecualian dan error. |
| SC-26 · Kategori Bersama | 09 | Terpetakan · 8 | `SC26_Category_Default` (10285), `SC26_Category_Empty` (11513), `SC26_Category_Error` (11538), `SC26_Category_Edit` (11563), `SC26_Category_Duplicate` (11588), `SC26_Category_Picker` (11613), `SC26_Category_Reassigned` (11665) | CRUD, pilih ikon/warna dan hasil reassignment. Dialog di SC-30, nama duplikat **OPEN**. |
| SC-27 · Backup Ekspor | 10 | Terpetakan · 16 | `SC27_Backup_Default` (11689), `SC27_Backup_Export` (11729), `SC27_Backup_PasswordMismatch` (11908), `SC27_Backup_Encrypting` (11942), `SC27_Backup_Location` (11963), `SC27_Backup_ShareSheet` (12078), `SC27_Backup_WriteError` (12156), `SC27_Backup_Reminder` (12177) | Password, enkripsi, tujuan sistem, keberhasilan, pembatalan, error dan cadence. |
| SC-28 · Backup Restore & Konflik Merge | 10 | Terpetakan · 26 | `SC28_Restore_FilePicker` (11762), `SC28_Restore_MergeConflict` (11793), `SC28_Restore_WrongPassword` (12418), `SC28_Restore_InvalidFile` (12473), `SC28_Restore_UnsupportedSchema` (12494), `SC28_Restore_Corrupt` (12515), `SC28_Restore_Mode` (12536), `SC28_Restore_MergeConfirm` (12949), `SC28_Restore_Rollback` (13039) | Validasi, mode, pilihan per konflik dan rollback. Review aksi destruktif di SC-30. |
| SC-29 · Tempat Sampah | 10 | Terpetakan · 8 | `SC29_Trash_Default` (11840), `SC29_Trash_Empty` (13060), `SC29_Trash_Expiring` (13083), `SC29_Trash_Expired` (13118), `SC29_Trash_RestoreConflict` (13181), `SC29_Trash_PermanentlyDeleted` (13238) | Kosong, retensi, restore conflict dan hasil hapus. Kebijakan purge **OPEN**. |
| SC-30 · Dialog dan overlay universal | 11 | Terpetakan · 39 | `SC30_Add_ChooseType` (13262), `SC30_Dialog_EventStatus` (13304), `SC30_Dialog_RecurringEdit` (13371), `SC30_Dialog_TaskFinished` (13800), `SC30_Dialog_SmartReview` (13890), `SC30_Dialog_Q80` (13986), `SC30_Dialog_WeekStart` (14026), `SC30_Dialog_CategoryDelete` (14062), `SC30_Dialog_RestoreReplace` (14152), `SC30_Dialog_TrashPermanent` (14206), `SC30_Dialog_NotificationDenied` (14233) | FAB, status, scope, overlap/buffer/jam aktif, sesi task, review/Q80, minggu, kategori, backup, trash, dan izin. |

### Indeks lengkap frame aktual

Nomor di kiri setiap nama adalah ID node FigCraft. Daftar mengikuti urutan dokumen dalam setiap kelompok. Semua nama frame memakai kapitalisasi sumber.

<details>
<summary>SC-01 · 4 frame</summary>

- 950 · `SC01_Splash_Default`
- 968 · `SC01_Splash_Loading`
- 987 · `SC01_Splash_LocalError`
- 14683 · `SC01_Splash_Returning`

</details>

<details>
<summary>SC-02 · 5 frame</summary>

- 1008 · `SC02_Onboarding_Introduction`
- 1071 · `SC02_Onboarding_Scheduling`
- 1136 · `SC02_Onboarding_Offline`
- 1201 · `SC02_Onboarding_LargeText`
- 1266 · `SC02_Onboarding_Resume`

</details>

<details>
<summary>SC-03 · 7 frame</summary>

- 1287 · `SC03_Setup_Profile`
- 1309 · `SC03_Setup_Empty`
- 1331 · `SC03_Setup_ActiveHours`
- 1384 · `SC03_Setup_Incomplete`
- 1437 · `SC03_Setup_InvalidInterval`
- 1490 · `SC03_Setup_Saved`
- 1511 · `SC03_Setup_OptionalPermission`

</details>

<details>
<summary>SC-04 · 12 frame</summary>

- 175 · `SC04_Home_Default`
- 252 · `SC04_Home_Empty`
- 308 · `SC04_Home_Loading`
- 366 · `SC04_Home_Error`
- 424 · `SC04_Home_AllDone`
- 498 · `SC04_Home_PendingConfirmation`
- 575 · `SC04_Home_ScheduleConflict`
- 649 · `SC04_Home_NotificationDenied`
- 723 · `SC04_Home_CrossMidnight`
- 798 · `SC04_Home_Categories`
- 873 · `SC04_Home_Overdue`
- 14470 · `SC04_Home_AfterConfirmation`

</details>

<details>
<summary>SC-05 · 10 frame</summary>

- 1535 · `SC05_Calendar_Month`
- 1868 · `SC05_Calendar_EmptyDay`
- 2027 · `SC05_Calendar_ManyItems`
- 2187 · `SC05_Calendar_BusyAllDay`
- 2347 · `SC05_Calendar_Recurring`
- 2507 · `SC05_Calendar_CrossMidnight`
- 2667 · `SC05_Calendar_DeadlineTimezone`
- 2827 · `SC05_Calendar_PreviousMonth`
- 2973 · `SC05_Calendar_NextMonth`
- 3119 · `SC05_Calendar_DatePicker`

</details>

<details>
<summary>SC-06 · 6 frame</summary>

- 1695 · `SC06_Calendar_Week`
- 3159 · `SC06_Calendar_Overlap`
- 3260 · `SC06_Calendar_Buffer`
- 3358 · `SC06_Calendar_Timezone`
- 3455 · `SC06_Calendar_CrossMidnight`
- 3556 · `SC06_Calendar_WeekStartSunday`

</details>

<details>
<summary>SC-07 · 6 frame</summary>

- 1792 · `SC07_Calendar_Day`
- 3653 · `SC07_Calendar_Empty`
- 3706 · `SC07_Calendar_Loading`
- 3759 · `SC07_Calendar_Overlap`
- 3839 · `SC07_Calendar_DeadlineSameHour`
- 3916 · `SC07_Calendar_OutsideActive`

</details>

<details>
<summary>SC-08 · 9 frame</summary>

- 3996 · `SC08_Event_Upcoming`
- 4147 · `SC08_Event_InProgress`
- 4183 · `SC08_Event_Pending`
- 4219 · `SC08_Event_Completed`
- 4255 · `SC08_Event_Postponed`
- 4292 · `SC08_Event_Skipped`
- 4329 · `SC08_Event_Trashed`
- 4366 · `SC08_Event_RecurringException`
- 14544 · `SC08_Event_GroupMeeting`

</details>

<details>
<summary>SC-09 · 8 frame</summary>

- 4033 · `SC09_EventQuick_Default`
- 4402 · `SC09_EventQuick_Filled`
- 4437 · `SC09_EventQuick_Required`
- 4473 · `SC09_EventQuick_InvalidEnd`
- 4509 · `SC09_EventQuick_Conflict`
- 4548 · `SC09_EventQuick_BufferWarning`
- 4587 · `SC09_EventQuick_OutsideActive`
- 4626 · `SC09_EventQuick_Saved`

</details>

<details>
<summary>SC-10 · 12 frame</summary>

- 4069 · `SC10_EventForm_Default`
- 4647 · `SC10_EventForm_Preserved`
- 4725 · `SC10_EventForm_MultipleReminders`
- 4803 · `SC10_EventForm_MonthlyCustom`
- 4881 · `SC10_EventForm_OneOccurrence`
- 4963 · `SC10_EventForm_SplitSeries`
- 5045 · `SC10_EventForm_ValidLink`
- 5123 · `SC10_EventForm_InvalidLink`
- 5202 · `SC10_EventForm_AllDayFree`
- 5277 · `SC10_EventForm_AllDayBusy`
- 5352 · `SC10_EventForm_ChooseDate`
- 5388 · `SC10_EventForm_ChooseTime`

</details>

<details>
<summary>SC-11 · 10 frame</summary>

- 5428 · `SC11_Todo_Default`
- 5638 · `SC11_Todo_Empty`
- 5691 · `SC11_Todo_AllComplete`
- 5749 · `SC11_Todo_Overdue`
- 5806 · `SC11_Todo_WithSessions`
- 5863 · `SC11_Todo_Uncategorized`
- 5929 · `SC11_Todo_NoMatch`
- 5982 · `SC11_Todo_Error`
- 6035 · `SC11_Todo_Search`
- 6092 · `SC11_Todo_Filters`

</details>

<details>
<summary>SC-12 · 8 frame</summary>

- 5495 · `SC12_Task_Default`
- 6133 · `SC12_Task_ChecklistComplete`
- 6189 · `SC12_Task_Overdue`
- 6244 · `SC12_Task_WithSessions`
- 6299 · `SC12_Task_Mismatch`
- 6354 · `SC12_Task_NoSessions`
- 6409 · `SC12_Task_ManualSession`
- 14699 · `SC12_Task_ConfirmNoSessions`

</details>

<details>
<summary>SC-13 · 14 frame</summary>

- 5550 · `SC13_TaskQuick_Default`
- 5582 · `SC13_TaskForm_Default`
- 6439 · `SC13_TaskQuick_Filled`
- 6471 · `SC13_TaskQuick_Invalid`
- 6504 · `SC13_TaskQuick_PastDeadline`
- 6539 · `SC13_TaskQuick_Saved`
- 6560 · `SC13_TaskForm_Edit`
- 6616 · `SC13_TaskForm_Preserved`
- 6672 · `SC13_TaskForm_TimezoneFloating`
- 6728 · `SC13_TaskForm_SubtaskEdit`
- 6784 · `SC13_TaskForm_PermissionOff`
- 6844 · `SC13_TaskForm_Deadline`
- 6881 · `SC13_TaskForm_Zone`
- 6917 · `SC13_TaskForm_Subtasks`

</details>

<details>
<summary>SC-14 · 6 frame</summary>

- 6958 · `SC14_Routines_Default`
- 7140 · `SC14_Routines_Empty`
- 7182 · `SC14_Routines_GoalPending`
- 7245 · `SC14_Routines_Missed`
- 7308 · `SC14_Routines_TimerRunning`
- 7371 · `SC14_Routines_PartialHistory`

</details>

<details>
<summary>SC-15 · 11 frame</summary>

- 7021 · `SC15_RoutineQuick_Default`
- 7087 · `SC15_RoutineForm_Duration`
- 7434 · `SC15_RoutineQuick_Partial`
- 7466 · `SC15_RoutineQuick_Filled`
- 7498 · `SC15_RoutineQuick_Target`
- 7538 · `SC15_RoutineForm_Checklist`
- 7591 · `SC15_RoutineForm_Count`
- 7644 · `SC15_RoutineForm_Weekly`
- 7697 · `SC15_RoutineForm_Invalid`
- 7751 · `SC15_RoutineForm_Preserved`
- 7804 · `SC15_RoutineQuick_Saved`

</details>

<details>
<summary>SC-16 · 10 frame</summary>

- 7053 · `SC16_Timer_Idle`
- 7825 · `SC16_Timer_Running`
- 7862 · `SC16_Timer_Paused`
- 7899 · `SC16_Timer_Stopped`
- 7932 · `SC16_Timer_Restored`
- 7967 · `SC16_Timer_Goal`
- 8000 · `SC16_Timer_GoalNoPermission`
- 8033 · `SC16_Timer_AppResumed`
- 8068 · `SC16_Timer_Manual`
- 8097 · `SC16_Timer_History`

</details>

<details>
<summary>SC-17 · 6 frame</summary>

- 8138 · `SC17_Smart_Default`
- 8342 · `SC17_Smart_Replanning`
- 8385 · `SC17_Smart_EstimateConfirmed`
- 8428 · `SC17_Smart_DeadlineInvalid`
- 8474 · `SC17_Smart_MissingEstimate`
- 8518 · `SC17_Smart_SettingsConflict`

</details>

<details>
<summary>SC-18 · 8 frame</summary>

- 8181 · `SC18_Smart_Split`
- 8564 · `SC18_Smart_OneSlot`
- 8599 · `SC18_Smart_Selected`
- 8641 · `SC18_Smart_Stale`
- 8682 · `SC18_Smart_Loading`
- 8703 · `SC18_Smart_NoFeasible`
- 8724 · `SC18_Smart_Saved`
- 14365 · `SC18_Smart_OneSaved`

</details>

<details>
<summary>SC-19 · 7 frame</summary>

- 8221 · `SC19_Smart_NoSlot`
- 8745 · `SC19_Smart_Insufficient`
- 8789 · `SC19_Smart_MaxSessions`
- 8833 · `SC19_Smart_MinDuration`
- 8877 · `SC19_Smart_Persistent`
- 8921 · `SC19_Smart_Adjust`
- 8954 · `SC19_Smart_InvalidLimits`

</details>

<details>
<summary>SC-20 · 7 frame</summary>

- 8265 · `SC20_Smart_Conflict`
- 8988 · `SC20_Smart_MultiConflict`
- 9027 · `SC20_Smart_NoSolution`
- 9064 · `SC20_Smart_Retained`
- 9101 · `SC20_Smart_Scope`
- 9137 · `SC20_Smart_ReplanOnly`
- 9174 · `SC20_Smart_ReplanAll`

</details>

<details>
<summary>SC-21 · 8 frame</summary>

- 8303 · `SC21_Smart_Shortage`
- 9218 · `SC21_Smart_Match`
- 9253 · `SC21_Smart_Surplus`
- 9292 · `SC21_Smart_NoAdjustment`
- 9331 · `SC21_Smart_Retained`
- 9366 · `SC21_Smart_Proposed`
- 9393 · `SC21_Smart_Approved`
- 9414 · `SC21_Smart_Cancelled`

</details>

<details>
<summary>SC-22 · 15 frame</summary>

- 9438 · `SC22_Stats_Week`
- 9501 · `SC22_Stats_Day`
- 9556 · `SC22_Stats_Month`
- 9610 · `SC22_Stats_Comparison`
- 9659 · `SC22_Stats_Filtered`
- 9722 · `SC22_Stats_EmptyDay`
- 9757 · `SC22_Stats_NoPeriodData`
- 9792 · `SC22_Stats_Partial`
- 9846 · `SC22_Stats_WeekStartChanged`
- 9909 · `SC22_Stats_Loading`
- 9944 · `SC22_Stats_Error`
- 9979 · `SC22_Stats_CategoryPicker`
- 10019 · `SC22_Stats_PeriodPicker`
- 10055 · `SC22_Stats_ManualCompare`
- 10079 · `SC22_Stats_ByType`

</details>

<details>
<summary>SC-23 · 10 frame</summary>

- 10115 · `SC23_Profile_Default`
- 10330 · `SC23_Profile_Saved`
- 10403 · `SC23_Profile_Incomplete`
- 10476 · `SC23_Profile_BackupDue`
- 10549 · `SC23_Profile_NotificationsDenied`
- 10622 · `SC23_Profile_Changed`
- 10695 · `SC23_Profile_Edit`
- 10715 · `SC23_Profile_CalendarSettings`
- 10749 · `SC23_Profile_Timezone`
- 10785 · `SC23_Profile_Buffer`

</details>

<details>
<summary>SC-24 · 6 frame</summary>

- 10188 · `SC24_ActiveHours_Edit`
- 10811 · `SC24_ActiveHours_Changed`
- 10865 · `SC24_ActiveHours_InvalidOverlap`
- 10919 · `SC24_ActiveHours_TimezoneChanged`
- 10973 · `SC24_ActiveHours_Day`
- 10999 · `SC24_ActiveHours_Preferences`

</details>

<details>
<summary>SC-25 · 13 frame</summary>

- 10242 · `SC25_Notifications_Default`
- 11029 · `SC25_Notifications_Denied`
- 11074 · `SC25_Notifications_NotRequested`
- 11119 · `SC25_Notifications_Granted`
- 11162 · `SC25_Notifications_FocusCaveat`
- 11205 · `SC25_Notifications_QuietActive`
- 11248 · `SC25_Notifications_SchedulingError`
- 11293 · `SC25_Notifications_QuietHours`
- 11336 · `SC25_Notifications_Exceptions`
- 11379 · `SC25_Notifications_PermissionPrompt`
- 11406 · `SC25_Notifications_OSSettings`
- 11429 · `SC25_Notifications_ReminderTypes`
- 11485 · `SC25_Notifications_ReminderEditor`

</details>

<details>
<summary>SC-26 · 8 frame</summary>

- 10285 · `SC26_Category_Default`
- 11513 · `SC26_Category_Empty`
- 11538 · `SC26_Category_Error`
- 11563 · `SC26_Category_Edit`
- 11588 · `SC26_Category_Duplicate`
- 11613 · `SC26_Category_Picker`
- 11644 · `SC26_Category_Saved`
- 11665 · `SC26_Category_Reassigned`

</details>

<details>
<summary>SC-27 · 16 frame</summary>

- 11689 · `SC27_Backup_Default`
- 11729 · `SC27_Backup_Export`
- 11875 · `SC27_Backup_PasswordSet`
- 11908 · `SC27_Backup_PasswordMismatch`
- 11942 · `SC27_Backup_Encrypting`
- 11963 · `SC27_Backup_Location`
- 12003 · `SC27_Backup_ShareCanceled`
- 12046 · `SC27_Backup_SystemPicker`
- 12078 · `SC27_Backup_ShareSheet`
- 12114 · `SC27_Backup_Success`
- 12135 · `SC27_Backup_PickerUnavailable`
- 12156 · `SC27_Backup_WriteError`
- 12177 · `SC27_Backup_Reminder`
- 12216 · `SC27_Backup_ReminderEnabled`
- 12255 · `SC27_Backup_ReminderOff`
- 12294 · `SC27_Backup_ReminderCustom`

</details>

<details>
<summary>SC-28 · 26 frame</summary>

- 11762 · `SC28_Restore_FilePicker`
- 11793 · `SC28_Restore_MergeConflict`
- 12337 · `SC28_Restore_NoFile`
- 12360 · `SC28_Restore_Password`
- 12389 · `SC28_Restore_PasswordEntered`
- 12418 · `SC28_Restore_WrongPassword`
- 12452 · `SC28_Restore_Validating`
- 12473 · `SC28_Restore_InvalidFile`
- 12494 · `SC28_Restore_UnsupportedSchema`
- 12515 · `SC28_Restore_Corrupt`
- 12536 · `SC28_Restore_Mode`
- 12569 · `SC28_Restore_ReplaceSelected`
- 12605 · `SC28_Restore_MergeReview`
- 12636 · `SC28_Restore_NoConflicts`
- 12667 · `SC28_Restore_SingleConflict`
- 12714 · `SC28_Restore_SingleSelected`
- 12761 · `SC28_Restore_LocalSelected`
- 12808 · `SC28_Restore_BackupSelected`
- 12855 · `SC28_Restore_SecondConflict`
- 12902 · `SC28_Restore_SecondSelected`
- 12949 · `SC28_Restore_MergeConfirm`
- 12976 · `SC28_Restore_Applying`
- 12997 · `SC28_Restore_Success`
- 13018 · `SC28_Restore_ReplaceSuccess`
- 13039 · `SC28_Restore_Rollback`
- 14580 · `SC28_Restore_SecondBackupSelected`

</details>

<details>
<summary>SC-29 · 8 frame</summary>

- 11840 · `SC29_Trash_Default`
- 13060 · `SC29_Trash_Empty`
- 13083 · `SC29_Trash_Expiring`
- 13118 · `SC29_Trash_Expired`
- 13157 · `SC29_Trash_Item`
- 13181 · `SC29_Trash_RestoreConflict`
- 13217 · `SC29_Trash_Restored`
- 13238 · `SC29_Trash_PermanentlyDeleted`

</details>

<details>
<summary>SC-30 · 39 frame</summary>

- 13262 · `SC30_Add_ChooseType`
- 13304 · `SC30_Dialog_EventStatus`
- 13344 · `SC30_Dialog_ScheduleConflict`
- 13371 · `SC30_Dialog_RecurringEdit`
- 13411 · `SC30_Dialog_RecurringDelete`
- 13451 · `SC30_Dialog_RecurringEditFuture`
- 13491 · `SC30_Dialog_RecurringEditAll`
- 13531 · `SC30_Dialog_RecurringDeleteFuture`
- 13571 · `SC30_Dialog_RecurringDeleteAll`
- 13611 · `SC30_Dialog_Buffer`
- 13638 · `SC30_Dialog_OutsideActive`
- 13665 · `SC30_Dialog_DeleteEvent`
- 13697 · `SC30_Dialog_DeleteSingle`
- 13724 · `SC30_Dialog_EventPostponed`
- 13764 · `SC30_Dialog_EventSkipped`
- 13800 · `SC30_Dialog_TaskFinished`
- 13836 · `SC30_Dialog_TaskPast`
- 13863 · `SC30_Dialog_RoutineDone`
- 13890 · `SC30_Dialog_SmartReview`
- 13927 · `SC30_Dialog_SmartReviewOne`
- 13959 · `SC30_Dialog_SmartReplanReview`
- 13986 · `SC30_Dialog_Q80`
- 14026 · `SC30_Dialog_WeekStart`
- 14062 · `SC30_Dialog_CategoryDelete`
- 14098 · `SC30_Dialog_CategoryMove`
- 14125 · `SC30_Dialog_BackupPassword`
- 14152 · `SC30_Dialog_RestoreReplace`
- 14179 · `SC30_Dialog_MergeConflict`
- 14206 · `SC30_Dialog_TrashPermanent`
- 14233 · `SC30_Dialog_NotificationDenied`
- 14260 · `SC30_Dialog_EventDeleted`
- 14281 · `SC30_Dialog_EventCompleted`
- 14302 · `SC30_Dialog_TaskCancelSessions`
- 14323 · `SC30_Dialog_TaskKeepSessions`
- 14344 · `SC30_Dialog_RoutineCompleted`
- 14386 · `SC30_Dialog_SmartReplanned`
- 14407 · `SC30_Dialog_CategoryMoved`
- 14428 · `SC30_Dialog_SmartRechecking`
- 14449 · `SC30_Dialog_RestoreReplacing`

</details>

## Alur prototipe dan batas verifikasi

Inspeksi struktural menemukan **10 flow start** dan **2.208 aksi node bertujuan frame** pada 315 artboard. Semua ID tujuan ada. Dari sepuluh titik awal, graf aksi ber-ID mencakup **196 frame** termasuk titik awal. **119 frame** lain tersedia sebagai referensi state di kanvas, tanpa jalur dalam graf bertujuan ID dari titik awal. Aksi kembali tanpa ID mengikuti konteks pemain. Penghitungan tautan memakai metadata dan tidak menguji klik pada setiap kontrol, urutan fokus, validasi input, atau perubahan state runtime.

| Flow start FigCraft | Frame awal | Tautan yang diperiksa dalam metadata |
| --- | --- | --- |
| 01 · Pemasangan baru | 950 · `SC01_Splash_Default` | Splash → tiga slide onboarding → profil → jam aktif → penyiapan selesai → Home. |
| 02 · Home dan lima tab | 175 · `SC04_Home_Default` | Home memiliki tujuan semua lima tab, Statistik dan FAB. |
| 03 · Quick Add dan Form Lengkap | 13262 · `SC30_Add_ChooseType` | FAB membuka tiga tujuan Quick Add, masing-masing memiliki tujuan Form Lengkap. |
| 04 · Edit kegiatan berulang | 3996 · `SC08_Event_Upcoming` | Aksi edit menuju pemilih cakupan recurrence SC-30. |
| 05 · Tugas dan Smart Scheduling | 5495 · `SC12_Task_Default` | Cari slot menuju SC-17 dan hasil SC-18. Review split SC-30 memiliki aksi Setujui & Simpan Sesi serta Batal. |
| 06 · Statistik dan perbandingan | 9438 · `SC22_Stats_Week` | Segmented hari/minggu/bulan, kategori, filter pembanding, dan rincian tersedia. |
| 07 · Ekspor dan pemulihan backup | 11689 · `SC27_Backup_Default` | Menu ekspor/restore tersedia. Mode restore mengarah ke replace/merge, konflik memperlihatkan pilihan lokal/backup. |
| 08 · Timer rutinitas | 7053 · `SC16_Timer_Idle` | Timer menuju state running. Manual dan riwayat memiliki frame tujuan masing-masing. |
| 09 · Konfirmasi hasil kegiatan | 13304 · `SC30_Dialog_EventStatus` | Dialog mengarah ke hasil selesai, opsi tunda dan opsi lewati. Tunda memuat pilihan manual/saran/jadwalkan nanti. |
| 10 · Buka profil yang sudah disiapkan | 14683 · `SC01_Splash_Returning` | Splash pengguna kembali menuju Home. |

## Selisih dan keputusan yang perlu ditindaklanjuti

| Area | Bukti dan dampak | Status dan tindak lanjut |
| --- | --- | --- |
| Repository vs desain | Source dan desain tersedia, tetapi belum ada scaffold atau runtime Flutter. Artboard memakai satu viewport portrait 390×844, termasuk contoh teks besar. | **CONFIRMED** · Uji Android/iOS dan text scaling pada implementasi ketika tersedia. **OPEN** · Perilaku tablet/landscape dan breakpoint. |
| Bahasa, branding, dan default | FigCraft memakai `Routina`, Bricolage Grotesque/Space Mono, nama profil opsional, `WIB`, jam aktif contoh, serta batas 45 menit/3 sesi. Kolase eksternal memiliki CTA akun. | **CONFIRMED** · Bahasa Indonesia untuk UI kerja, profil lokal dan offline. **OPEN** · Brand, font/ikon, ketentuan profil, lokal waktu, dan nilai baku selain mode deadline zona asal. Simpan pilihan pengguna sesuai keputusan. |
| Home dan fallback notifikasi | `Pengingat` di `SC04_Home_Default` (175) menuju `SC04_Home_NotificationDenied` (649). Flow demonya selalu membuka varian izin ditolak. | **CONFIRMED** · Status izin sebenarnya mengendalikan banner serta pengaturan OS. **PROPOSED** · Tinjau tujuan untuk kondisi izin aktif dan entry point pengingat dalam aplikasi. |
| Navigasi tanggal mingguan | Di `SC06_Calendar_Week` (1695), panah sebelumnya menuju varian awal Minggu (3556) dan panah berikutnya menuju kalender harian (1792). | **CONFIRMED** · Navigasi tanggal dan perubahan awal minggu mempunyai fungsi berbeda. **PROPOSED** · Review transisi demo sebelum memetakan tombol Flutter. |
| Detail sesi tersimpan | `SC12_Task_WithSessions` (6244) dan slot pada `SC06_Calendar_Week` (1695) menuju `SC18_Smart_Split` (8181), yang berlabel `Usulan · belum tersimpan`. | **CONFIRMED** · Pisahkan sesi tersimpan dari usulan. **PROPOSED** · Review tujuan untuk sesi tersimpan dan pertahankan proposal pada alur saran. |
| Durasi aktual sesi tugas | `SC12_Task_WithSessions` (6244) memperlihatkan 30 menit aktual, dan `SC21_Smart_Shortage` (8303) menampilkan durasi aktual sebagai input estimasi. `SC12_Task_ManualSession` (6409) memasukkan jadwal. Frame timer/manual SC-16 milik rutinitas. Belum ditemukan frame input/log aktual yang khusus untuk sesi tugas. | **OPEN** · Tentukan manual/timer/hibrida dan hubungan TimeLog (calon Q81, lihat OPEN-01). **CONFIRMED** · Durasi aktual, rencana, sisa, checklist, dan status terpisah. |
| Konteks penjadwalan ulang event | `Cari slot kosong` pada `SC30_Dialog_EventPostponed` (13724) menuju pra-pencarian dengan contoh task Laporan E-Commerce (8138). | **CONFIRMED** · Rekomendasi pengganti harus mempertahankan konteks occurrence asal dan memerlukan persetujuan. **PROPOSED** · Review frame atau varian alur pengganti event. |
| Pratinjau dan persetujuan Smart Scheduling | `SC18_Smart_Split` (8181) memakai daftar slot. DESIGN SC-18 juga meminta linimasa agenda. `SC30_Dialog_SmartRechecking` (14428) memicu navigasi demo ke sukses. Frame stale (8641) tersedia terpisah. | **CONFIRMED** · Revalidasi aktual sebelum transaksi; proposal stale ditolak dan dapat diperbarui. **PROPOSED** · Review representasi linimasa, jalur stale dari validasi dan interaksi koreksi estimasi SC-17. |
| Frame kondisi vs akses dari flow | Pemeriksaan graf menemukan state standalone, termasuk Home empty/loading/error. Nama frame menetapkan referensi UI, sedangkan pembuktian perilaku membutuhkan interaksi di preview/perangkat. | **PROPOSED** · Review state wajib DESIGN §8, cek kontrol interaktif dan tautkan state yang perlu didemokan pada flow D0. Tetapkan kriteria visual sesuai DESIGN §9. |
| Copy keamanan serta Trash | Mode restore dan state korup/salah sandi tersedia, label varian tidak menetapkan kebijakan klasifikasi error. `SC29_Trash_Expired` (13118) eksplisit menyebut jadwal hapus otomatis masih ditinjau. | **CONFIRMED** · Validasi sebelum mutasi, pemulihan transaksional, password aman dan retensi 30 hari. **OPEN** · Format/kompatibilitas file, kebijakan purge dan snapshot histori. |
