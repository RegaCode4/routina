import 'package:flutter/material.dart';
import 'package:routina/presentation/design_system/neo_tokens.dart';

enum NeoButtonVariant { primary, secondary, danger }

class NeoButton extends StatelessWidget {
  const NeoButton({
    required this.label,
    required this.onPressed,
    this.variant = NeoButtonVariant.primary,
    this.icon,
    this.loading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final NeoButtonVariant variant;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final color = switch (variant) {
      NeoButtonVariant.primary => NeoColors.blue,
      NeoButtonVariant.secondary => NeoColors.paper,
      NeoButtonVariant.danger => NeoColors.coral,
    };

    return _NeoAction(
      onPressed: loading ? null : onPressed,
      fill: color,
      loading: loading,
      radius: NeoRadius.card,
      minimumSize: const Size(NeoSize.touch, NeoSize.button),
      padding: const EdgeInsets.symmetric(
        horizontal: NeoSpace.md,
        vertical: NeoSpace.sm,
      ),
      shadow: variant == NeoButtonVariant.secondary ? null : NeoShadow.button,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading || icon != null) ...[
            if (loading)
              const ExcludeSemantics(
                child: SizedBox.square(
                  dimension: NeoSpace.md,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: NeoColors.ink,
                  ),
                ),
              )
            else
              Icon(icon, size: NeoSpace.md),
            const SizedBox(width: NeoSpace.xs),
          ],
          Flexible(
            child: Semantics(
              liveRegion: loading,
              child: Text(
                loading ? '$label · Memuat' : label,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NeoIconButton extends StatelessWidget {
  const NeoIconButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.indicator = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool indicator;

  @override
  Widget build(BuildContext context) {
    final accessibleLabel = indicator ? '$label · Ada pembaruan' : label;
    return Tooltip(
      message: accessibleLabel,
      excludeFromSemantics: true,
      child: _NeoAction(
        onPressed: onPressed,
        fill: NeoColors.paper,
        radius: NeoRadius.card,
        minimumSize: const Size.square(NeoSize.touch),
        padding: EdgeInsets.zero,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, size: NeoSize.navIcon, semanticLabel: accessibleLabel),
            if (indicator)
              const PositionedDirectional(
                end: -NeoSpace.xxs,
                top: -NeoSpace.xxs,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: NeoColors.coral,
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(NeoLine.thin),
                  ),
                  child: SizedBox.square(dimension: NeoSpace.xs),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class NeoFabAdd extends StatelessWidget {
  const NeoFabAdd({required this.onPressed, this.expanded = false, super.key});

  final VoidCallback? onPressed;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final label = expanded ? 'Tutup pilihan tambah' : 'Tambah aktivitas';
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: _NeoAction(
        onPressed: onPressed,
        fill: NeoColors.yellow,
        radius: NeoRadius.hero,
        minimumSize: const Size.square(NeoSize.fab),
        padding: EdgeInsets.zero,
        shadow: NeoShadow.hard,
        child: Icon(
          expanded ? Icons.close : Icons.add,
          size: NeoSpace.page,
          semanticLabel: label,
        ),
      ),
    );
  }
}

class _NeoAction extends StatelessWidget {
  const _NeoAction({
    required this.onPressed,
    required this.fill,
    required this.radius,
    required this.minimumSize,
    required this.padding,
    required this.child,
    this.loading = false,
    this.shadow,
  });

  final VoidCallback? onPressed;
  final Color fill;
  final BorderRadius radius;
  final Size minimumSize;
  final EdgeInsets padding;
  final Widget child;
  final bool loading;
  final List<BoxShadow>? shadow;

  @override
  Widget build(BuildContext context) {
    final onAccent = fill != NeoColors.paper;
    final foreground = WidgetStateProperty.resolveWith<Color>(
      (states) => !loading && states.contains(WidgetState.disabled)
          ? NeoColors.muted
          : NeoColors.ink,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: onPressed == null ? null : shadow,
      ),
      child: TextButton(
        onPressed: onPressed,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => !loading && states.contains(WidgetState.disabled)
                ? NeoColors.disabled
                : fill,
          ),
          foregroundColor: foreground,
          iconColor: foreground,
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return onAccent ? NeoColors.accentPressed : NeoColors.pressed;
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return onAccent ? NeoColors.accentHover : NeoColors.hover;
            }
            return Colors.transparent;
          }),
          side: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? NeoLine.focus
                : NeoLine.outline,
          ),
          textStyle: const WidgetStatePropertyAll(NeoType.item),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: radius),
          ),
          padding: WidgetStatePropertyAll(padding),
          minimumSize: WidgetStatePropertyAll(minimumSize),
          visualDensity: VisualDensity.standard,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: child,
      ),
    );
  }
}
