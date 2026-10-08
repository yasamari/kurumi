import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/time_format.dart';
import '../../../core/widgets/program_symbol_text.dart';
import '../../../domain/entities/timetable.dart';
import '../../../domain/entities/tv_program.dart';

/// 番組詳細のボトムシートを開く。
Future<void> showTimetableProgramSheet({
  required BuildContext context,
  required TimetableChannel column,
  required TvProgram program,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => _TimetableProgramSheet(
      column: column,
      program: program,
      onWatch: () {
        Navigator.of(sheetContext).pop();
        context.push('/watch/${column.channel.id}');
      },
    ),
  );
}

class _TimetableProgramSheet extends StatelessWidget {
  const _TimetableProgramSheet({
    required this.column,
    required this.program,
    required this.onWatch,
  });

  final TimetableChannel column;
  final TvProgram program;
  final VoidCallback onWatch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              column.channel.name,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            ProgramSymbolText(
              program.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              formatProgramSlot(program.startAt, program.endAt),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (program.genres.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final genre in program.genres) Chip(label: Text(genre)),
                ],
              ),
            ],
            if (program.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              SelectableText(
                program.description,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            for (final entry in program.detail.entries) ...[
              const SizedBox(height: 12),
              Text(
                entry.key,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(entry.value, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('閉じる'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onWatch,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('視聴する'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
