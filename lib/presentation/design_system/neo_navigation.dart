import 'package:flutter/material.dart';
import 'package:routina/presentation/design_system/neo_button.dart';
import 'package:routina/presentation/design_system/neo_tokens.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    required this.title,
    this.showBack = false,
    this.action,
    super.key,
  });

  final String title;
  final bool showBack;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: NeoSize.header),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: NeoSpace.page,
          vertical: NeoSpace.xxs,
        ),
        child: Row(
          children: [
            if (showBack) ...[
              NeoIconButton(
                icon: Icons.chevron_left,
                label: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: NeoSpace.xs),
            ],
            Expanded(
              child: Semantics(
                header: true,
                child: Text(title, style: NeoType.title),
              ),
            ),
            if (action case final action?) ...[
              const SizedBox(width: NeoSpace.xs),
              action,
            ],
          ],
        ),
      ),
    );
  }
}

enum RoutinaTab {
  home('Home', Icons.home_outlined),
  calendar('Kalender', Icons.calendar_month_outlined),
  tasks('To-Do List', Icons.fact_check_outlined),
  routines('Rutinitas', Icons.sync),
  profile('Profil', Icons.person_outline);

  const RoutinaTab(this.label, this.icon);

  final String label;
  final IconData icon;
}

class RoutinaBottomNavigation extends StatelessWidget {
  const RoutinaBottomNavigation({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final RoutinaTab selected;
  final ValueChanged<RoutinaTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: NeoColors.paper,
        border: Border(top: NeoLine.thin),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(NeoSpace.xxs),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: NeoSize.nav - 2 * NeoSpace.xxs,
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final tab in RoutinaTab.values)
                    Expanded(
                      child: _NavDestination(
                        tab: tab,
                        selected: tab == selected,
                        onTap: () => onSelected(tab),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavDestination extends StatelessWidget {
  const _NavDestination({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final RoutinaTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final position = MaterialLocalizations.of(
      context,
    ).tabLabel(tabIndex: tab.index + 1, tabCount: RoutinaTab.values.length);
    final largeText =
        MediaQuery.textScalerOf(context).scale(NeoType.navSize) >=
        NeoType.navMultilineSize;
    final visibleLabel = tab == RoutinaTab.tasks && largeText
        ? 'To-Do\nList'
        : tab.label;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: NeoSpace.xxs / 2),
      child: Semantics(
        label: '${tab.label}, $position',
        button: true,
        selected: selected,
        onTap: onTap,
        excludeSemantics: true,
        child: Material(
          color: selected ? NeoColors.yellow : NeoColors.paper,
          borderRadius: NeoRadius.input,
          child: InkWell(
            borderRadius: NeoRadius.input,
            excludeFromSemantics: true,
            hoverColor: NeoColors.hover,
            focusColor: NeoColors.hover,
            highlightColor: NeoColors.pressed,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: NeoSpace.xs),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(tab.icon, size: NeoSize.navIcon, color: NeoColors.ink),
                  const SizedBox(height: NeoSpace.xxs),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      visibleLabel,
                      textAlign: TextAlign.center,
                      style: NeoType.nav.copyWith(
                        color: NeoColors.ink,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
