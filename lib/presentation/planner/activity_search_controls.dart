import 'package:flutter/material.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/presentation/design_system/neo_badges.dart';
import 'package:routina/presentation/design_system/neo_button.dart';
import 'package:routina/presentation/design_system/neo_card.dart';
import 'package:routina/presentation/design_system/neo_form_field.dart';
import 'package:routina/presentation/design_system/neo_tokens.dart';
import 'package:routina/presentation/planner/preview_ui.dart';

class ActivitySearchControls extends StatelessWidget {
  const ActivitySearchControls({
    required this.label,
    required this.controller,
    required this.onChanged,
    required this.chips,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      NeoFormField(
        label: label,
        hint: 'Cari berdasarkan judul',
        icon: Icons.search,
        controller: controller,
        onChanged: onChanged,
      ),
      const SizedBox(height: NeoSpace.xs),
      Wrap(spacing: NeoSpace.xs, runSpacing: NeoSpace.xxs, children: chips),
    ],
  );
}

class ActivitySearchEmpty extends StatelessWidget {
  const ActivitySearchEmpty({
    required this.title,
    required this.onClear,
    super.key,
  });

  final String title;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => NeoCard(
    emphasis: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(
          child: ExcludeSemantics(
            child: NeoCard(
              tone: NeoCardTone.yellow,
              emphasis: true,
              child: Icon(Icons.search_off),
            ),
          ),
        ),
        const SizedBox(height: NeoSpace.md),
        Semantics(
          liveRegion: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: NeoType.section,
          ),
        ),
        const SizedBox(height: NeoSpace.xs),
        Text(
          'Ubah kata pencarian atau bersihkan filter.',
          textAlign: TextAlign.center,
          style: NeoType.body.copyWith(color: NeoColors.muted),
        ),
        const SizedBox(height: NeoSpace.md),
        NeoButton(label: 'Bersihkan filter', onPressed: onClear),
      ],
    ),
  );
}

class SearchCategoryChip extends StatelessWidget {
  const SearchCategoryChip({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
    super.key,
  });

  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  Future<void> _pick(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final choices = {
      '*': 'Semua kategori',
      '': 'Tanpa kategori',
      for (final category in categories) category.id: category.name,
    };
    final choice = await previewChoices(
      context,
      'Kategori',
      choices.keys.toList(),
      (id) => choices[id]!,
    );
    if (context.mounted && choice != null) {
      onSelected(choice == '*' ? null : choice);
    }
  }

  @override
  Widget build(BuildContext context) => CategoryChip(
    label: selectedId == ''
        ? 'Tanpa kategori'
        : categories
                  .where((category) => category.id == selectedId)
                  .firstOrNull
                  ?.name ??
              'Kategori',
    selected: selectedId != null,
    onSelected: (_) => _pick(context),
  );
}
