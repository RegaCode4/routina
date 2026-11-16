import 'package:flutter/material.dart';
import 'package:routina/presentation/design_system/neo_button.dart';
import 'package:routina/presentation/design_system/neo_tokens.dart';

Future<T?> showNeoBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: NeoColors.scrim,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: builder(context),
    ),
  );
}

class NeoBottomSheet extends StatelessWidget {
  const NeoBottomSheet({
    required this.title,
    required this.child,
    this.description,
    this.leading,
    this.showClose = true,
    super.key,
  });

  final String title;
  final Widget child;
  final String? description;
  final Widget? leading;
  final bool showClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NeoColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: NeoRadius.sheet,
        side: NeoLine.outline,
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            NeoSpace.page,
            NeoSpace.sm,
            NeoSpace.page,
            NeoSpace.page,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: NeoColors.muted,
                    borderRadius: NeoRadius.small,
                  ),
                  child: SizedBox(
                    width: NeoSize.sheetHandleWidth,
                    height: NeoSpace.xxs,
                  ),
                ),
              ),
              const SizedBox(height: NeoSpace.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (leading case final leading?) ...[
                    leading,
                    const SizedBox(width: NeoSpace.xs),
                  ],
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(title, style: NeoType.title),
                    ),
                  ),
                  if (showClose)
                    NeoIconButton(
                      icon: Icons.close,
                      label: 'Tutup',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                ],
              ),
              if (description case final description?) ...[
                const SizedBox(height: NeoSpace.xs),
                Text(
                  description,
                  style: NeoType.body.copyWith(color: NeoColors.muted),
                ),
              ],
              const SizedBox(height: NeoSpace.md),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool?> showNeoDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = false,
}) {
  return showNeoBottomSheet<bool>(
    context,
    builder: (context) => NeoDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      danger: danger,
    ),
  );
}

class NeoDialog extends StatelessWidget {
  const NeoDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.danger = false,
    super.key,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return NeoBottomSheet(
      title: title,
      description: message,
      leading: danger
          ? const ExcludeSemantics(
              child: Icon(Icons.warning_amber_rounded, color: NeoColors.ink),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          NeoButton(
            label: confirmLabel,
            variant: danger
                ? NeoButtonVariant.danger
                : NeoButtonVariant.primary,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: NeoSpace.md),
          NeoButton(
            label: 'Batal',
            variant: NeoButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}
