import 'package:flutter/material.dart';
import 'package:routina/presentation/design_system/neo_badges.dart';
import 'package:routina/presentation/design_system/neo_card.dart';
import 'package:routina/presentation/design_system/neo_tokens.dart';

class ActivityCard extends StatelessWidget {
  const ActivityCard({
    required this.title,
    required this.time,
    this.category,
    this.status,
    this.recurring = false,
    this.highlighted = false,
    this.onTap,
    super.key,
  });

  final String title;
  final String time;
  final String? category;
  final NeoStatus? status;
  final bool recurring;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final warning =
        status == NeoStatus.conflicted || status == NeoStatus.pending;
    return _PlannerCard(
      title: title,
      icon: recurring ? Icons.repeat : Icons.schedule,
      iconFill: warning ? NeoColors.coral : NeoColors.yellow,
      tone: warning
          ? NeoCardTone.warning
          : highlighted
          ? NeoCardTone.highlighted
          : NeoCardTone.plain,
      dense: !warning && !highlighted,
      onTap: onTap,
      details: [
        _Metadata(category == null ? time : '$time · $category'),
        if (recurring) const _Metadata('Berulang'),
        if (status case final status?) StatusBadge(status: status),
      ],
    );
  }
}

class TaskCard extends StatelessWidget {
  const TaskCard({
    required this.title,
    required this.due,
    this.priority,
    this.subtasks,
    this.subtaskProgress,
    this.sessions,
    this.status,
    this.onTap,
    super.key,
  });

  final String title;
  final String due;
  final String? priority;
  final String? subtasks;
  final double? subtaskProgress;
  final String? sessions;
  final NeoStatus? status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _PlannerCard(
      title: title,
      icon: status == NeoStatus.completed
          ? Icons.check_box_outlined
          : Icons.check_box_outline_blank_rounded,
      iconFill: NeoColors.paper,
      dense: status != NeoStatus.overdue,
      onTap: onTap,
      details: [
        _Metadata(due),
        Wrap(
          spacing: NeoSpace.xs,
          runSpacing: NeoSpace.xxs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (status case final status?) StatusBadge(status: status),
            if (priority case final priority?)
              CategoryChip(label: priority, icon: Icons.auto_awesome_outlined),
            if (subtasks case final subtasks?) _Metadata(subtasks),
            if (sessions case final sessions?) _Metadata(sessions),
          ],
        ),
        if (subtaskProgress case final progress?)
          NeoProgressBar(value: progress, label: 'Progres subtugas $title'),
      ],
    );
  }
}

class RoutineCard extends StatelessWidget {
  const RoutineCard({
    required this.title,
    required this.target,
    required this.actual,
    this.progress,
    this.timer,
    this.status,
    this.onTap,
    super.key,
  });

  final String title;
  final String target;
  final String actual;
  final double? progress;
  final String? timer;
  final NeoStatus? status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _PlannerCard(
      title: title,
      icon: Icons.repeat,
      iconFill: NeoColors.greenTint,
      dense: true,
      onTap: onTap,
      details: [
        _Metadata('Target · $target'),
        _Metadata('Aktual · $actual'),
        if (progress case final progress?)
          NeoProgressBar(value: progress, label: 'Progres $title'),
        if (timer case final timer?) Text(timer, style: NeoType.numericCaption),
        if (status case final status?) StatusBadge(status: status),
      ],
    );
  }
}

class _PlannerCard extends StatelessWidget {
  const _PlannerCard({
    required this.title,
    required this.icon,
    required this.iconFill,
    required this.details,
    required this.onTap,
    this.tone = NeoCardTone.plain,
    this.dense = false,
  });

  final String title;
  final IconData icon;
  final Color iconFill;
  final List<Widget> details;
  final VoidCallback? onTap;
  final NeoCardTone tone;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return NeoCard(
      dense: dense,
      tone: tone,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: iconFill,
                borderRadius: NeoRadius.input,
              ),
              child: SizedBox.square(
                dimension: NeoSize.cardIcon,
                child: Icon(icon, size: NeoSize.navIcon, color: NeoColors.ink),
              ),
            ),
          ),
          const SizedBox(width: NeoSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: NeoType.item),
                for (final detail in details) ...[
                  const SizedBox(height: NeoSpace.xxs),
                  detail,
                ],
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: NeoSpace.xxs),
            const ExcludeSemantics(child: Icon(Icons.chevron_right)),
          ],
        ],
      ),
    );
  }
}

class _Metadata extends StatelessWidget {
  const _Metadata(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: NeoType.caption.copyWith(color: NeoColors.muted));
  }
}
