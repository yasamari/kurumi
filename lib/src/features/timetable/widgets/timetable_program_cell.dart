import 'package:flutter/material.dart';

import '../../../core/widgets/program_symbol_text.dart';
import '../../../domain/entities/tv_program.dart';
import '../timetable_layout.dart';

/// 番組表の番組ブロック1件。ジャンル色のティント + 左アクセントバーの
/// Material 3 カード。
///
/// [heightPx] に応じて表示内容を変える (短い番組はタイトルのみ、
/// ごく短い番組は色ブロックのみ)。タップは常に有効。
///
/// 波紋のための `Material` は祖先 (列単位) が持つ。セルごとに作ると
/// 初回構築のウィジェット数が膨らむ。
class TimetableProgramCell extends StatelessWidget {
  const TimetableProgramCell({
    super.key,
    required this.program,
    required this.heightPx,
    required this.isOnAir,
    required this.onTap,
  });

  final TvProgram program;
  final double heightPx;
  final bool isOnAir;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final seed = timetableGenreSeedColor(timetableGenreMajor(program.genres));
    final background = Color.alphaBlend(
      seed.withValues(alpha: isOnAir ? 0.30 : 0.14),
      colorScheme.surfaceContainerHigh,
    );
    final maxLines = timetableCellTitleMaxLines(heightPx);
    final showTime = timetableCellShowsTime(heightPx);

    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(timetableCellRadius),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(timetableCellRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color: seed,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              const SizedBox(width: 5),
              if (maxLines > 0)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ProgramSymbolText(
                        program.title,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: isOnAir ? FontWeight.bold : FontWeight.w600,
                          color: colorScheme.onSurface,
                          height: 1.25,
                        ),
                        maxLines: maxLines,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (showTime)
                        Text(
                          formatTimetableCellTime(
                            program.startAt,
                            program.endAt,
                          ),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
