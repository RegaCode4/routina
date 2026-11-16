import 'package:flutter/material.dart';
import 'package:routina/presentation/design_system/neo_tokens.dart';

enum NeoStatus {
  pending('Menunggu konfirmasi', Icons.schedule, NeoColors.yellowTint),
  active('Berlangsung', Icons.play_arrow_rounded, NeoColors.blueTint),
  completed('Selesai', Icons.check_circle_outline, NeoColors.greenTint),
  postponed('Ditunda', Icons.update, NeoColors.yellowTint),
  skipped('Dilewatkan', Icons.skip_next_outlined, NeoColors.disabled),
  overdue('Overdue', Icons.warning_amber_rounded, NeoColors.coralTint),
  conflicted('Bentrok', Icons.warning_amber_rounded, NeoColors.coralTint),
  missed('Terlewat', Icons.event_busy_outlined, NeoColors.coralTint);

  const NeoStatus(this.label, this.icon, this.fill);

  final String label;
  final IconData icon;
  final Color fill;
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.status, super.key});

  final NeoStatus status;

  @override
  Widget build(BuildContext context) {
    return _Badge(
      fill: status.fill,
      child: _BadgeLabel(label: status.label, icon: status.icon),
    );
  }
}

class CategoryChip extends StatelessWidget {
  const CategoryChip({
    this.label = 'Tanpa kategori',
    this.icon = Icons.label_outline,
    this.color,
    this.selected = false,
    this.onSelected,
    super.key,
  });

  final String label;
  final IconData icon;
  final Color? color;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) {
    final fill = selected ? NeoColors.yellow : NeoColors.paper;
    final content = _BadgeLabel(label: label, icon: icon, swatch: color);
    final select = onSelected;
    if (select == null) return _Badge(fill: fill, child: content);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: () => select(!selected),
      excludeSemantics: true,
      child: Material(
        color: fill,
        shape: const RoundedRectangleBorder(
          borderRadius: NeoRadius.small,
          side: NeoLine.thin,
        ),
        child: InkWell(
          excludeFromSemantics: true,
          borderRadius: NeoRadius.small,
          onTap: () => select(!selected),
          hoverColor: NeoColors.hover,
          focusColor: NeoColors.hover,
          highlightColor: NeoColors.pressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: NeoSize.touch,
              minHeight: NeoSize.touch,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: NeoSpace.xxs,
                horizontal: NeoSpace.xs,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.fill, required this.child});

  final Color fill;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: NeoRadius.small,
        border: const Border.fromBorderSide(NeoLine.thin),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: NeoSpace.xs,
          vertical: NeoSpace.xxs,
        ),
        child: child,
      ),
    );
  }
}

class _BadgeLabel extends StatelessWidget {
  const _BadgeLabel({required this.label, required this.icon, this.swatch});

  final String label;
  final IconData icon;
  final Color? swatch;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (swatch case final color?) ...[
          DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: const Border.fromBorderSide(NeoLine.thin),
            ),
            child: const SizedBox.square(dimension: NeoSpace.xs),
          ),
          const SizedBox(width: NeoSpace.xxs),
        ],
        ExcludeSemantics(
          child: Icon(icon, size: NeoSize.badgeIcon, color: NeoColors.ink),
        ),
        const SizedBox(width: NeoSpace.xxs),
        Flexible(
          child: Text(
            label,
            style: NeoType.badge.copyWith(color: NeoColors.ink),
          ),
        ),
      ],
    );
  }
}
