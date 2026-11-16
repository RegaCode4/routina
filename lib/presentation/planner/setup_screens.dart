import 'package:flutter/material.dart';
import 'package:routina/application/planner_preview.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:routina/presentation/design_system/neo_button.dart';
import 'package:routina/presentation/design_system/neo_card.dart';
import 'package:routina/presentation/design_system/neo_form_field.dart';
import 'package:routina/presentation/design_system/neo_navigation.dart';
import 'package:routina/presentation/design_system/neo_tokens.dart';
import 'package:routina/presentation/planner/preview_ui.dart';

class PlannerStartup extends StatefulWidget {
  const PlannerStartup({
    required this.repository,
    required this.shell,
    super.key,
  });
  final PlannerPreviewRepository repository;
  final Widget shell;

  @override
  State<PlannerStartup> createState() => _PlannerStartupState();
}

class _PlannerStartupState extends State<PlannerStartup> {
  late Future<void> _load = widget.repository.load(PreviewSurface.startup);
  bool _started = false;

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _load,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done &&
          !snapshot.hasError) {
        if (widget.repository.profile != null) return widget.shell;
        if (_started) {
          return PlannerOnboarding(
            repository: widget.repository,
            onReady: () => setState(() {}),
          );
        }
      }
      final resumed =
          !snapshot.hasError && widget.repository.onboardingStep > 0;
      return PreviewPage(
        footerSpace: 64,
        footer: snapshot.connectionState != ConnectionState.done
            ? null
            : NeoButton(
                label: snapshot.hasError
                    ? 'Coba lagi'
                    : resumed
                    ? 'Lanjutkan'
                    : 'Mulai',
                onPressed: () => setState(() {
                  if (snapshot.hasError) {
                    _load = widget.repository.load(PreviewSurface.startup);
                  } else {
                    _started = true;
                  }
                }),
              ),
        body: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: const EdgeInsets.all(NeoSpace.page),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (box.maxHeight - 2 * NeoSpace.page).clamp(
                  0,
                  double.infinity,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: _BrandMark()),
                  const SizedBox(height: NeoSpace.section),
                  const Text(
                    'Routina',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: NeoType.sans,
                      fontWeight: FontWeight.w700,
                      fontSize: 56,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: NeoSpace.xs),
                  const Text(
                    'Perencana aktivitas personal',
                    textAlign: TextAlign.center,
                    style: NeoType.body,
                  ),
                  if (snapshot.hasError) ...[
                    const SizedBox(height: NeoSpace.page),
                    const PreviewNotice(
                      title: 'Data lokal belum terbaca',
                      message: 'Coba lagi untuk memulai penyiapan.',
                      warning: true,
                      icon: Icons.error_outline,
                    ),
                  ] else if (snapshot.connectionState !=
                      ConnectionState.done) ...[
                    const SizedBox(height: NeoSpace.page),
                    const Center(
                      child: CircularProgressIndicator(
                        semanticsLabel: 'Memuat Routina',
                        color: NeoColors.ink,
                      ),
                    ),
                  ] else if (resumed) ...[
                    const SizedBox(height: NeoSpace.page),
                    const PreviewNotice(
                      title: 'Lanjutkan penyiapan',
                      message: 'Lanjutkan dari langkah onboarding terakhir.',
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 100,
    height: 92,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 4,
          top: 7,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: NeoColors.blue,
              borderRadius: NeoRadius.hero,
              border: Border.fromBorderSide(NeoLine.outline),
              boxShadow: NeoShadow.hard,
            ),
            child: const SizedBox.square(
              dimension: 84,
              child: Icon(Icons.calendar_today_outlined, size: 30),
            ),
          ),
        ),
        Positioned(
          right: 1,
          top: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: NeoColors.yellow,
              borderRadius: NeoRadius.small,
              border: Border.fromBorderSide(NeoLine.thin),
            ),
            child: const SizedBox.square(
              dimension: 29,
              child: Icon(Icons.check, size: 20),
            ),
          ),
        ),
      ],
    ),
  );
}

class PlannerOnboarding extends StatefulWidget {
  const PlannerOnboarding({
    required this.repository,
    required this.onReady,
    super.key,
  });
  final PlannerPreviewRepository repository;
  final VoidCallback onReady;
  @override
  State<PlannerOnboarding> createState() => _PlannerOnboardingState();
}

class _PlannerOnboardingState extends State<PlannerOnboarding> {
  late int _step = widget.repository.onboardingStep.clamp(0, 2);
  static const _slides = [
    (
      'Atur hari dalam satu tempat',
      'Lihat jadwal, tenggat, dan rutinitas dari satu agenda.',
      'Agenda hari ini',
      Icons.event_outlined,
      NeoCardTone.accent,
    ),
    (
      'Temukan waktu untuk fokus',
      'Smart Scheduling menyarankan slot sebelum tenggat. Kamu yang menyetujui rencananya.',
      'Usulan sesi fokus',
      Icons.schedule,
      NeoCardTone.highlighted,
    ),
    (
      'Bawa rencanamu ke mana saja',
      'Data contoh tersedia offline. Backup terenkripsi akan tersedia di fase terkait.',
      'Backup terenkripsi',
      Icons.lock_outline,
      NeoCardTone.warning,
    ),
  ];

  void _select(int step) {
    widget.repository.rememberStep(step);
    setState(() => _step = step);
  }

  Future<void> _advance() async {
    if (_step < 2) {
      _select(_step + 1);
      return;
    }
    final setup = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PlannerProfileSetup(repository: widget.repository),
      ),
    );
    if (mounted && setup == true) widget.onReady();
  }

  @override
  Widget build(BuildContext context) {
    final (title, message, sample, icon, tone) = _slides[_step];
    return PreviewPage(
      footerSpace: 64,
      footer: NeoButton(
        label: _step == 2 ? 'Siapkan profil' : 'Lanjut',
        onPressed: _advance,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: NeoSpace.page),
        children: [
          AppHeader(
            title: 'Routina',
            action: _step == 0
                ? null
                : NeoIconButton(
                    icon: Icons.chevron_left,
                    label: 'Kembali',
                    onPressed: () => _select(_step - 1),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              NeoSpace.page,
              NeoSpace.sm,
              NeoSpace.page,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NeoCard(
                  tone: tone,
                  emphasis: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 59,
                      horizontal: 36,
                    ),
                    child: NeoCard(
                      emphasis: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(icon, size: 28),
                          const SizedBox(height: NeoSpace.sm),
                          Text(sample, style: NeoType.item),
                          const SizedBox(height: NeoSpace.xs),
                          NeoProgressBar(
                            value: 0.65,
                            label: 'Ilustrasi agenda',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: NeoSpace.section),
                Text(title, style: NeoType.display.copyWith(fontSize: 39)),
                const SizedBox(height: NeoSpace.md),
                Text(
                  message,
                  style: NeoType.body.copyWith(color: NeoColors.muted),
                ),
                const SizedBox(height: NeoSpace.section),
                Row(
                  children: [
                    for (var index = 0; index < 3; index++)
                      Padding(
                        padding: const EdgeInsets.only(right: NeoSpace.xxs),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: index == _step
                                ? NeoColors.ink
                                : NeoColors.line,
                            borderRadius: NeoRadius.small,
                          ),
                          child: SizedBox(
                            width: index == _step ? 16 : 8,
                            height: 8,
                          ),
                        ),
                      ),
                    const Spacer(),
                    Text('Langkah ${_step + 1} dari 3', style: NeoType.caption),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PlannerProfileSetup extends StatefulWidget {
  const PlannerProfileSetup({required this.repository, super.key});
  final PlannerPreviewRepository repository;
  @override
  State<PlannerProfileSetup> createState() => _PlannerProfileSetupState();
}

class _PlannerProfileSetupState extends State<PlannerProfileSetup> {
  late final _name = TextEditingController(
    text: widget.repository.profile?.name ?? '',
  );
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _openHours() async {
    final ready = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PlannerActiveHours(
          repository: widget.repository,
          name: _name.text.trim(),
        ),
      ),
    );
    if (mounted && ready == true) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => PreviewPage(
    title: 'Profil lokal',
    footerSpace: 64,
    footer: NeoButton(label: 'Atur jam aktif', onPressed: _openHours),
    body: ListView(
      padding: const EdgeInsets.all(NeoSpace.page),
      children: [
        const Text('Kenalan dulu', style: NeoType.display),
        const SizedBox(height: NeoSpace.xs),
        const Text('Nama tampilan membantu mempersonalisasi Home.'),
        const SizedBox(height: NeoSpace.page),
        NeoFormField(
          label: 'Nama tampilan (opsional)',
          hint: 'Contoh: Nara',
          controller: _name,
          labelAbove: true,
        ),
        const SizedBox(height: NeoSpace.page),
        Text(
          'Profil contoh tersedia selama sesi ini.',
          style: NeoType.caption.copyWith(color: NeoColors.muted),
        ),
      ],
    ),
  );
}

class PlannerActiveHours extends StatefulWidget {
  const PlannerActiveHours({
    required this.repository,
    required this.name,
    this.settings = false,
    super.key,
  });
  final PlannerPreviewRepository repository;
  final String name;
  final bool settings;
  @override
  State<PlannerActiveHours> createState() => _ActiveHoursState();
}

class _ActiveHoursState extends State<PlannerActiveHours> {
  late final _hours = Map<int, ActiveInterval>.of(
    widget.repository.profile?.activeHours ?? {},
  );
  late String _study = widget.repository.profile?.study ?? 'Sore';
  late String _workout = widget.repository.profile?.workout ?? 'Pagi';
  late bool _sunday = widget.repository.profile?.sundayFirst ?? false;
  bool _submitted = false;
  bool _saving = false;

  Future<void> _editDay(int day) async {
    final interval = await Navigator.of(context).push<ActiveInterval>(
      MaterialPageRoute(
        builder: (_) => _EditHours(day: day, initial: _hours[day]),
      ),
    );
    if (mounted && interval != null) setState(() => _hours[day] = interval);
  }

  void _examples() {
    setState(() {
      for (var day = 1; day <= 7; day++) {
        _hours[day] = ActiveInterval(8 * 60, (day < 6 ? 21 : 20) * 60);
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _submitted = true);
    if (_hours.length != 7 ||
        _hours.values.any((interval) => !interval.isValid)) {
      return;
    }
    setState(() => _saving = true);
    _writeProfile(widget.repository.profile?.notifications ?? false);
    if (widget.settings) {
      Navigator.of(context).pop(true);
      return;
    }
    final notifications = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const _ProfileSaved()));
    if (!mounted) return;
    if (notifications != null) _writeProfile(notifications);
    Navigator.of(context).pop(true);
  }

  void _writeProfile(bool notifications) {
    widget.repository.saveProfile(
      PreviewProfile(
        name: widget.name,
        activeHours: _hours,
        study: _study,
        workout: _workout,
        sundayFirst: _sunday,
        notifications: notifications,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PreviewPage(
    title: 'Jam aktif',
    footer: NeoButton(
      label: widget.settings ? 'Simpan jam aktif' : 'Simpan dan buka Home',
      onPressed: _saving ? null : _save,
    ),
    body: ListView(
      padding: const EdgeInsets.all(NeoSpace.page),
      children: [
        const Text('Kapan kamu aktif?', style: NeoType.display),
        const SizedBox(height: NeoSpace.xs),
        const Text(
          'Smart Scheduling memakai rentang ini saat mencari slot yang cocok.',
        ),
        const SizedBox(height: NeoSpace.page),
        for (var day = 1; day <= 7; day++) ...[
          NeoCard(
            dense: true,
            onTap: () => _editDay(day),
            child: Row(
              children: [
                Expanded(child: Text(dayNames[day - 1], style: NeoType.item)),
                Flexible(
                  child: Text(
                    _hours[day] == null
                        ? 'Pilih rentang'
                        : '${clockLabel(_hours[day]!.start)}–${clockLabel(_hours[day]!.end)}',
                    style: NeoType.numericCaption,
                    textAlign: TextAlign.end,
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
          const SizedBox(height: NeoSpace.xxs),
        ],
        if (_submitted && _hours.length != 7)
          const Text(
            'Lengkapi rentang jam aktif untuk semua hari.',
            style: TextStyle(color: NeoColors.errorText),
          ),
        const SizedBox(height: NeoSpace.xs),
        Text(
          'Contoh jam aktif · dapat berbeda untuk setiap hari.',
          style: NeoType.caption.copyWith(color: NeoColors.muted),
        ),
        const SizedBox(height: NeoSpace.xs),
        NeoButton(
          label: 'Pakai rentang contoh',
          variant: NeoButtonVariant.secondary,
          onPressed: _examples,
        ),
        const SizedBox(height: NeoSpace.sm),
        _preference('Belajar', _study, (value) => _study = value),
        const SizedBox(height: NeoSpace.sm),
        _preference('Workout', _workout, (value) => _workout = value),
        if (!widget.settings)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Minggu dimulai hari Minggu'),
            value: _sunday,
            onChanged: (value) => setState(() => _sunday = value),
          ),
      ],
    ),
  );

  Widget _preference(String name, String value, ValueChanged<String> select) =>
      PreviewField(
        label: 'Preferensi $name',
        value: value,
        onTap: () async {
          final next = await previewChoices(context, 'Preferensi $name', [
            'Pagi',
            'Siang',
            'Sore',
            'Malam',
          ], (value) => value);
          if (mounted && next != null) setState(() => select(next));
        },
      );
}

class _EditHours extends StatefulWidget {
  const _EditHours({required this.day, this.initial});
  final int day;
  final ActiveInterval? initial;
  @override
  State<_EditHours> createState() => _EditHoursState();
}

class _EditHoursState extends State<_EditHours> {
  late int? _start = widget.initial?.start;
  late int? _end = widget.initial?.end;
  String? _error;
  Future<void> _pick(bool start) async {
    final result = await pickPreviewTime(
      context,
      initial: start ? _start : _end,
    );
    if (mounted && result != null) {
      setState(() {
        if (start) {
          _start = result;
        } else {
          _end = result;
        }
        _error = null;
      });
    }
  }

  void _save() {
    final start = _start;
    final end = _end;
    if (start == null || end == null || start >= end) {
      setState(
        () => _error = start == null || end == null
            ? 'Lengkapi waktu mulai dan selesai.'
            : 'Waktu selesai harus sesudah waktu mulai.',
      );
      return;
    }
    Navigator.pop(context, ActiveInterval(start, end));
  }

  @override
  Widget build(BuildContext context) => PreviewPage(
    title: 'Jam aktif ${dayNames[widget.day - 1]}',
    footer: NeoButton(label: 'Simpan rentang', onPressed: _save),
    body: ListView(
      padding: const EdgeInsets.all(NeoSpace.page),
      children: [
        PreviewField(
          label: 'Mulai',
          value: _start == null ? 'Pilih jam' : clockLabel(_start!),
          icon: Icons.schedule,
          onTap: () => _pick(true),
        ),
        const SizedBox(height: NeoSpace.md),
        PreviewField(
          label: 'Selesai',
          value: _end == null ? 'Pilih jam' : clockLabel(_end!),
          icon: Icons.schedule,
          onTap: () => _pick(false),
        ),
        if (_error case final error?) ...[
          const SizedBox(height: NeoSpace.md),
          PreviewNotice(
            title: 'Rentang belum valid',
            message: error,
            warning: true,
          ),
        ],
      ],
    ),
  );
}

class _ProfileSaved extends StatefulWidget {
  const _ProfileSaved();
  @override
  State<_ProfileSaved> createState() => _ProfileSavedState();
}

class _ProfileSavedState extends State<_ProfileSaved> {
  bool _permissions = false;
  @override
  Widget build(BuildContext context) => PreviewPage(
    title: _permissions ? 'Pengingat' : 'Penyiapan selesai',
    footer: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_permissions) ...[
          NeoButton(
            label: 'Aktifkan untuk pratinjau',
            onPressed: () => Navigator.pop(context, true),
          ),
          const SizedBox(height: NeoSpace.sm),
        ],
        NeoButton(
          label: _permissions ? 'Lanjut ke Home' : 'Buka Home',
          variant: _permissions
              ? NeoButtonVariant.secondary
              : NeoButtonVariant.primary,
          onPressed: () => _permissions
              ? Navigator.pop(context, false)
              : setState(() => _permissions = true),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(NeoSpace.page),
      children: [
        Icon(
          _permissions ? Icons.notifications_none : Icons.check_circle_outline,
          size: 56,
        ),
        const SizedBox(height: NeoSpace.page),
        Text(
          _permissions ? 'Aktifkan pengingat?' : 'Profil tersimpan',
          style: NeoType.display,
        ),
        const SizedBox(height: NeoSpace.sm),
        Text(
          _permissions
              ? 'Kamu bisa melewati pratinjau ini. Pengingat tetap dapat dilihat di Home.'
              : 'Jam aktif dan preferensi siap digunakan selama sesi ini.',
        ),
      ],
    ),
  );
}
