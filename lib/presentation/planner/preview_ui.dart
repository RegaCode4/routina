import 'package:flutter/material.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:routina/presentation/design_system/neo_badges.dart';
import 'package:routina/presentation/design_system/neo_button.dart';
import 'package:routina/presentation/design_system/neo_card.dart';
import 'package:routina/presentation/design_system/neo_navigation.dart';
import 'package:routina/presentation/design_system/neo_overlays.dart';
import 'package:routina/presentation/design_system/neo_tokens.dart';

const monthNames = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];
const dayNames = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];
const shortDays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

String timeModeLabel(TimeMode mode) => switch (mode) {
  TimeMode.originalZone => 'Pertahankan zona asal',
  TimeMode.localWallTime => 'Ikuti jam lokal',
};

String dateLabel(DateTime date, {bool year = false, bool long = false}) =>
    '${(long ? dayNames : shortDays)[date.weekday - 1]}, ${date.day} ${monthNames[date.month - 1]}${year ? ' ${date.year}' : ''}';

String clockLabel(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}.${(minutes % 60).toString().padLeft(2, '0')}';

String decimalMetric(double value) {
  final tenths = (value * 10).round();
  return tenths % 10 == 0
      ? '${tenths ~/ 10}'
      : '${tenths ~/ 10},${tenths % 10}';
}

String completionPercentage(double? value) =>
    value == null ? 'Tidak Ada Aktivitas' : '${decimalMetric(value * 100)}%';

String eventTime(PreviewEvent event) {
  if (event.kind == PreviewKind.routine && event.allDay) {
    return 'Progres rutinitas';
  }
  if (event.allDay) {
    return 'Sepanjang hari · ${event.options.availability == DayAvailability.busy ? 'Sibuk' : 'Tersedia'}';
  }
  if (event.kind == PreviewKind.deadline) {
    return 'Tenggat ${clockLabel(minutesAt(event.start))}';
  }
  final end = dateOnly(event.start) == dateOnly(event.end)
      ? clockLabel(minutesAt(event.end))
      : '${shortDays[event.end.weekday - 1]} ${clockLabel(minutesAt(event.end))}';
  return '${clockLabel(minutesAt(event.start))}–$end';
}

NeoStatus? badgeFor(PreviewEventState state) => switch (state) {
  PreviewEventState.active => NeoStatus.active,
  PreviewEventState.pending => NeoStatus.pending,
  PreviewEventState.done => NeoStatus.completed,
  PreviewEventState.postponed => NeoStatus.postponed,
  PreviewEventState.skipped => NeoStatus.skipped,
  _ => null,
};

NeoStatus? agendaStatus(PreviewEvent entry) =>
    entry.kind == PreviewKind.deadline &&
        entry.state == PreviewEventState.pending
    ? NeoStatus.overdue
    : badgeFor(entry.state);

String warningTitle(ScheduleWarning warning) => switch (warning) {
  ScheduleWarning.overlap => 'Jadwal bertabrakan',
  ScheduleWarning.buffer => 'Jeda belum terpenuhi',
  ScheduleWarning.activeHours => 'Di luar jam aktif',
};

String warningBody(ScheduleWarning warning) => switch (warning) {
  ScheduleWarning.overlap => 'Jadwal ini bertabrakan dengan kegiatan lain.',
  ScheduleWarning.buffer =>
    'Jeda sebelum atau sesudah kegiatan tidak terpenuhi.',
  ScheduleWarning.activeHours => 'Waktu ini berada di luar jam aktifmu.',
};

class PreviewPage extends StatelessWidget {
  const PreviewPage({
    required this.body,
    this.title,
    this.footer,
    this.action,
    this.footerSpace = NeoSpace.section,
    super.key,
  });
  final Widget body;
  final String? title;
  final Widget? footer;
  final Widget? action;
  final double footerSpace;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title case final title?)
            AppHeader(title: title, showBack: true, action: action),
          Expanded(child: body),
          if (footer case final footer?)
            Padding(
              padding: EdgeInsets.fromLTRB(
                NeoSpace.page,
                NeoSpace.sm,
                NeoSpace.page,
                footerSpace,
              ),
              child: footer,
            ),
        ],
      ),
    ),
  );
}

class PreviewNotice extends StatelessWidget {
  const PreviewNotice({
    required this.title,
    required this.message,
    this.icon = Icons.info_outline,
    this.warning = false,
    this.loading = false,
    this.button,
    super.key,
  });
  final String title;
  final String message;
  final IconData icon;
  final bool warning;
  final bool loading;
  final Widget? button;

  @override
  Widget build(BuildContext context) => NeoCard(
    tone: warning ? NeoCardTone.warning : NeoCardTone.plain,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (loading)
          const SizedBox.square(
            dimension: NeoSpace.page,
            child: CircularProgressIndicator(
              color: NeoColors.ink,
              strokeWidth: 2,
            ),
          )
        else
          ExcludeSemantics(child: Icon(icon)),
        const SizedBox(height: NeoSpace.xs),
        Semantics(liveRegion: true, child: Text(title, style: NeoType.section)),
        const SizedBox(height: NeoSpace.xxs),
        Text(message, style: NeoType.body.copyWith(color: NeoColors.muted)),
        if (button case final button?) ...[
          const SizedBox(height: NeoSpace.sm),
          button,
        ],
      ],
    ),
  );
}

class PreviewField extends StatelessWidget {
  const PreviewField({
    required this.label,
    required this.value,
    required this.onTap,
    this.icon = Icons.keyboard_arrow_down,
    this.numeric = false,
    super.key,
  });
  final String label;
  final String value;
  final VoidCallback onTap;
  final IconData icon;
  final bool numeric;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label, style: NeoType.caption.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: NeoSpace.xxs),
      Semantics(
        label: '$label, $value',
        button: true,
        onTap: onTap,
        excludeSemantics: true,
        child: Material(
          color: NeoColors.paper,
          shape: const RoundedRectangleBorder(
            borderRadius: NeoRadius.input,
            side: NeoLine.outline,
          ),
          child: InkWell(
            excludeFromSemantics: true,
            onTap: onTap,
            borderRadius: NeoRadius.input,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: NeoSize.touch),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: NeoSpace.sm,
                  vertical: NeoSpace.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        style: numeric ? NeoType.numericCaption : NeoType.body,
                      ),
                    ),
                    const SizedBox(width: NeoSpace.xxs),
                    Icon(icon, size: NeoSize.navIcon),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

Future<T?> previewChoices<T>(
  BuildContext context,
  String title,
  List<T> choices,
  String Function(T) label,
) => showNeoBottomSheet<T>(
  context,
  builder: (sheet) => NeoBottomSheet(
    title: title,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final value in choices)
          Padding(
            padding: const EdgeInsets.only(bottom: NeoSpace.sm),
            child: NeoButton(
              label: label(value),
              variant: NeoButtonVariant.secondary,
              onPressed: () => Navigator.pop(sheet, value),
            ),
          ),
      ],
    ),
  ),
);

Future<DateTime?> pickPreviewDate(
  BuildContext context,
  DateTime around, {
  DateTime? selected,
}) {
  final first = DateTime(around.year - 3);
  final last = DateTime(around.year + 4, 12, 31);
  return showDatePicker(
    context: context,
    firstDate: first,
    lastDate: last,
    initialDate: selected ?? around,
    currentDate: around,
    cancelText: 'Batal',
    confirmText: 'Pilih tanggal',
  );
}

Future<int?> pickPreviewTime(BuildContext context, {int? initial}) async {
  final value = initial == 1440 ? 1439 : (initial ?? 12 * 60);
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: value ~/ 60, minute: value % 60),
    cancelText: 'Batal',
    confirmText: 'Pilih jam',
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );
  return time == null ? null : time.hour * 60 + time.minute;
}
