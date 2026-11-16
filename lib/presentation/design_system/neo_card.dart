import 'package:flutter/material.dart';
import 'package:routina/presentation/design_system/neo_tokens.dart';

enum NeoCardTone { plain, highlighted, warning, selected, accent, yellow }

class NeoCard extends StatelessWidget {
  const NeoCard({
    required this.child,
    this.tone = NeoCardTone.plain,
    this.emphasis = false,
    this.dense = false,
    this.onTap,
    super.key,
  });

  final Widget child;
  final NeoCardTone tone;
  final bool emphasis;
  final bool dense;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fill = switch (tone) {
      NeoCardTone.plain => NeoColors.paper,
      NeoCardTone.highlighted => NeoColors.yellowTint,
      NeoCardTone.warning => NeoColors.coralTint,
      NeoCardTone.selected => NeoColors.blueTint,
      NeoCardTone.accent => NeoColors.blue,
      NeoCardTone.yellow => NeoColors.yellow,
    };
    final shape = RoundedRectangleBorder(
      borderRadius: emphasis ? NeoRadius.hero : NeoRadius.card,
      side: dense ? NeoLine.subtle : NeoLine.outline,
    );
    final content = Padding(
      padding: EdgeInsets.all(dense ? NeoSpace.sm : NeoSpace.md),
      child: child,
    );
    final material = Material(
      shape: shape,
      color: fill,
      child: onTap == null
          ? content
          : InkWell(
              customBorder: shape,
              onTap: onTap,
              focusColor: tone == NeoCardTone.accent
                  ? NeoColors.accentHover
                  : NeoColors.hover,
              hoverColor: tone == NeoCardTone.accent
                  ? NeoColors.accentHover
                  : NeoColors.hover,
              highlightColor: tone == NeoCardTone.accent
                  ? NeoColors.accentPressed
                  : NeoColors.pressed,
              splashColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: NeoSize.touch),
                child: content,
              ),
            ),
    );

    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        shadows: emphasis ? NeoShadow.hard : null,
      ),
      child: Semantics(
        button: onTap != null,
        selected: tone == NeoCardTone.selected ? true : null,
        child: material,
      ),
    );
  }
}

class KpiTile extends StatelessWidget {
  const KpiTile({
    required this.label,
    this.value,
    this.description,
    this.progress,
    this.onTap,
    super.key,
  });

  final String label;
  final String? value;
  final String? description;
  final double? progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return NeoCard(
      emphasis: value != null,
      tone: value == null ? NeoCardTone.plain : NeoCardTone.accent,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: NeoType.item),
          const SizedBox(height: NeoSpace.xs),
          if (value case final value?)
            Text(value, style: NeoType.metric.copyWith(color: NeoColors.ink))
          else
            const Text('Tidak Ada Aktivitas', style: NeoType.body),
          if (description case final description?) ...[
            const SizedBox(height: NeoSpace.xxs),
            Text(description, style: NeoType.numericCaption),
          ],
          if (progress case final progress?) ...[
            const SizedBox(height: NeoSpace.sm),
            NeoProgressBar(
              value: progress,
              label: label,
              onAccent: value != null,
            ),
          ],
        ],
      ),
    );
  }
}

class NeoProgressBar extends StatelessWidget {
  const NeoProgressBar({
    required this.value,
    required this.label,
    this.onAccent = false,
    super.key,
  }) : assert(value >= 0 && value <= 1);

  final double value;
  final String label;
  final bool onAccent;

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: value,
      semanticsLabel: label,
      minHeight: NeoSize.progress,
      borderRadius: NeoRadius.small,
      backgroundColor: onAccent ? NeoColors.blueTint : NeoColors.disabled,
      color: onAccent ? NeoColors.ink : NeoColors.blue,
      stopIndicatorColor: Colors.transparent,
      trackGap: 0,
    );
  }
}
