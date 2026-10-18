import 'package:flutter/material.dart';

import '../../../core/widgets/program_symbol_text.dart';
import '../../../domain/entities/tv_program.dart';
import '../timetable_layout.dart';

/// 番組表の番組ブロック1件。背景はテーマ色、ジャンル色は左端の線のみ。
///
/// 上から放送時間、続けてタイトル+番組概要を1つの段落に流し込む。
/// タイトルと概要の間に行数制限はなく、セル末尾でまとめて省略する。
/// 段落が入らない短い番組は切り詰め表示 (見切れ上等) になる。
/// タップは常に有効。
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
    final showText = timetableCellShowsText(heightPx);
    final description = program.description;
    final timeLabel = formatTimetableCellTime(program.startAt, program.endAt);

    return Container(
      color: colorScheme.surfaceContainerHigh,
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: seed),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: _CellBody(
                  showText: showText,
                  timeLabel: timeLabel,
                  title: program.title,
                  description: description,
                  isOnAir: isOnAir,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// セル内の文章部分。短い番組では切り詰め表示になる。
class _CellBody extends StatelessWidget {
  const _CellBody({
    required this.showText,
    required this.timeLabel,
    required this.title,
    required this.description,
    required this.isOnAir,
  });

  final bool showText;
  final String timeLabel;
  final String title;
  final String description;
  final bool isOnAir;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontWeight: isOnAir ? FontWeight.bold : FontWeight.w600,
      color: colorScheme.onSurface,
      height: 1.25,
    );
    final timeStyle = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: colorScheme.onSurfaceVariant, height: 1.2);
    if (showText) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            timeLabel,
            style: timeStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Expanded(
            child: ProgramSymbolText(
              title,
              style: titleStyle,
              trailingText: description.isNotEmpty ? description : null,
              trailingStyle: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant, height: 1.3),
              // セル高が bounds になるため実質無制限。
              // maxLines なしの ellipsis は1行化するため必須。
              maxLines: 1000,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
    // 段落が入らない短い番組は切り詰め表示にする。
    // OverflowBox で自然な高さを許し、ClipRect で黙って切る。
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topCenter,
        maxHeight: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(timeLabel, style: timeStyle, maxLines: 1),
            ProgramSymbolText(
              title,
              style: titleStyle,
              maxLines: 1000,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
