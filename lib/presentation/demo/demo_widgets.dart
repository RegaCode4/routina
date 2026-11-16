import 'package:flutter/material.dart';
import 'package:routina/presentation/design_system/neo_badges.dart';
import 'package:routina/presentation/design_system/neo_button.dart';
import 'package:routina/presentation/design_system/neo_card.dart';
import 'package:routina/presentation/design_system/neo_form_field.dart';
import 'package:routina/presentation/design_system/neo_navigation.dart';
import 'package:routina/presentation/design_system/neo_overlays.dart';
import 'package:routina/presentation/design_system/neo_tokens.dart';
import 'package:routina/presentation/planner/preview_ui.dart';

import 'package:routina/presentation/demo/demo_session.dart';

Future<T?> openDemo<T>(BuildContext context, Widget page, {String? route}) =>
    Navigator.of(context).push<T>(
      MaterialPageRoute(
        settings: RouteSettings(name: route),
        builder: (_) => page,
      ),
    );

void demoFeedback(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class DemoTab extends StatelessWidget {
  const DemoTab(this.title, this.body, {this.action, super.key});
  final String title;
  final Widget body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      AppHeader(title: title, action: action),
      Expanded(child: body),
    ],
  );
}

class DemoList extends StatelessWidget {
  const DemoList(this.children, {this.tab = false, super.key});
  final List<Widget> children;
  final bool tab;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      NeoSpace.page,
      NeoSpace.sm,
      NeoSpace.page,
      tab ? NeoSpace.section * 3 : NeoSpace.section,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final child in children)
          Padding(
            padding: const EdgeInsets.only(bottom: NeoSpace.md),
            child: child,
          ),
      ],
    ),
  );
}

class DemoHeading extends StatelessWidget {
  const DemoHeading(this.title, {this.subtitle, super.key});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(header: true, child: Text(title, style: NeoType.display)),
      if (subtitle case final details?) ...[
        const SizedBox(height: NeoSpace.xxs),
        Text(details, style: NeoType.body.copyWith(color: NeoColors.muted)),
      ],
    ],
  );
}

class DemoActions extends StatelessWidget {
  const DemoActions(this.actions, {super.key});
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var index = 0; index < actions.length; index++) ...[
        if (index != 0) const SizedBox(height: NeoSpace.xs),
        actions[index],
      ],
    ],
  );
}

class DemoPair extends StatelessWidget {
  const DemoPair(this.first, this.second, {super.key});
  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 305 ||
          MediaQuery.textScalerOf(context).scale(16) > 22) {
        return DemoActions([first, second]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: first),
          const SizedBox(width: NeoSpace.xs),
          Expanded(child: second),
        ],
      );
    },
  );
}

class DemoRow extends StatelessWidget {
  const DemoRow(
    this.title, {
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.color = NeoColors.blueTint,
    super.key,
  });
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final String? subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) => NeoCard(
    dense: true,
    onTap: onTap,
    child: Row(
      children: [
        ExcludeSemantics(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: NeoRadius.input,
            ),
            child: SizedBox.square(
              dimension: NeoSize.cardIcon,
              child: Icon(icon, size: NeoSize.navIcon),
            ),
          ),
        ),
        const SizedBox(width: NeoSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: NeoType.item),
              if (subtitle case final value?)
                Text(
                  value,
                  style: NeoType.caption.copyWith(color: NeoColors.muted),
                ),
            ],
          ),
        ),
        const ExcludeSemantics(child: Icon(Icons.chevron_right)),
      ],
    ),
  );
}

class DemoFacts extends StatelessWidget {
  const DemoFacts(this.facts, {this.tone = NeoCardTone.plain, super.key});
  final List<(String, String)> facts;
  final NeoCardTone tone;

  @override
  Widget build(BuildContext context) => NeoCard(
    tone: tone,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, value) in facts)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: NeoSpace.xxs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: NeoType.caption),
                Text(value, style: NeoType.item),
              ],
            ),
          ),
      ],
    ),
  );
}

class DemoSegments<T> extends StatelessWidget {
  const DemoSegments({
    required this.items,
    required this.selected,
    required this.label,
    required this.onChange,
    super.key,
  });
  final List<T> items;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChange;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: NeoSpace.xs,
    runSpacing: NeoSpace.xxs,
    children: [
      for (final item in items)
        CategoryChip(
          label: label(item),
          selected: item == selected,
          onSelected: (_) => onChange(item),
        ),
    ],
  );
}

Widget? demoFeed(DemoSession demo, String key, String noun) =>
    switch (demo.feed(key)) {
      DemoFeed.loading => PreviewNotice(
        title: 'Memuat $noun',
        message: 'Menyiapkan data contoh.',
        loading: true,
        button: NeoButton(
          label: 'Lanjutkan pratinjau',
          onPressed: () => demo.retry(key),
        ),
      ),
      DemoFeed.error => PreviewNotice(
        title: '$noun tidak dapat dimuat',
        message: 'Coba baca kembali data contoh.',
        warning: true,
        button: NeoButton(label: 'Coba lagi', onPressed: () => demo.retry(key)),
      ),
      _ => null,
    };

Future<void> demoPick(
  BuildContext context,
  String label,
  List<String> choices,
  ValueChanged<String> update,
) async {
  final picked = await previewChoices(
    context,
    label,
    choices,
    (value) => value,
  );
  if (context.mounted && picked != null) update(picked);
}

Future<T?> demoSheet<T>(
  BuildContext context,
  String title,
  List<Widget> Function(BuildContext) children, {
  String? description,
}) => showNeoBottomSheet<T>(
  context,
  builder: (sheet) => NeoBottomSheet(
    title: title,
    description: description,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final child in children(sheet))
          Padding(
            padding: const EdgeInsets.only(bottom: NeoSpace.sm),
            child: child,
          ),
      ],
    ),
  ),
);

Future<int?> demoNumber(
  BuildContext context,
  String label, {
  int? value,
  int min = 1,
  int max = 1440,
}) => demoSheet<int>(context, label, (sheet) {
  final key = GlobalKey<FormState>();
  var input = value?.toString() ?? '';
  return [
    Form(
      key: key,
      child: NeoFormField(
        label: label,
        initialValue: input,
        keyboardType: TextInputType.number,
        onChanged: (value) => input = value,
        validator: (value) {
          final count = int.tryParse(value ?? '');
          return count == null || count < min || count > max
              ? 'Masukkan angka $min–$max.'
              : null;
        },
      ),
    ),
    NeoButton(
      label: 'Terapkan',
      onPressed: () {
        if (key.currentState!.validate()) {
          Navigator.pop(sheet, int.parse(input));
        }
      },
    ),
  ];
});

Future<String?> demoText(
  BuildContext context,
  String title,
  String label, {
  String initial = '',
}) => demoSheet<String>(context, title, (sheet) {
  final key = GlobalKey<FormState>();
  var input = initial;
  return [
    Form(
      key: key,
      child: NeoFormField(
        label: label,
        initialValue: input,
        onChanged: (value) => input = value,
        validator: (value) => value == null || value.trim().isEmpty
            ? 'Isi ${label.toLowerCase()}.'
            : null,
      ),
    ),
    NeoButton(
      label: 'Simpan',
      onPressed: () {
        if (key.currentState!.validate()) Navigator.pop(sheet, input.trim());
      },
    ),
  ];
});

String demoSlotLabel(DemoSlot slot) =>
    '${dateLabel(slot.start)} · ${clockLabel(slot.start.hour * 60 + slot.start.minute)}–${clockLabel(slot.end.hour * 60 + slot.end.minute)}';
final demoCategoryColors = [
  NeoColors.blue,
  NeoColors.yellow,
  NeoColors.coral,
  NeoColors.greenTint,
];
const demoReminders = [
  'Tanpa pengingat',
  'Saat mulai',
  '10 menit sebelumnya',
  '30 menit sebelumnya',
];
