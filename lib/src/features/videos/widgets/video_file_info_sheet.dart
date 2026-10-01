import 'package:flutter/material.dart';

import '../../../core/utils/media_format.dart';
import '../../../domain/entities/recorded_file_info.dart';

/// 録画ファイル情報を表示するBottomSheetを開く。
///
/// 内容はファイル / 映像 / 音声の3区画に分け、[Divider] で区切る。
Future<void> showVideoFileInfoSheet({
  required BuildContext context,
  required RecordedFileInfo info,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) =>
          _VideoFileInfoBody(info: info, scrollController: scrollController),
    ),
  );
}

/// BottomSheetの中身。ファイル区画 / 映像区画 / 音声区画の3区画構成。
class _VideoFileInfoBody extends StatelessWidget {
  const _VideoFileInfoBody({
    required this.info,
    required this.scrollController,
  });

  final RecordedFileInfo info;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        Text(
          '録画ファイル情報',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        _InfoRow(label: 'ファイルパス', value: info.filePath, selectable: true),
        _InfoRow(
          label: 'ファイルサイズ',
          value: formatFileSize(info.fileSize),
        ),
        _InfoRow(
          label: '録画期間',
          value: formatRecordingPeriod(
            info.recordingStartTime,
            info.recordingEndTime,
          ),
        ),
        _InfoRow(
          label: '最終更新日時',
          value: formatFileDateTime(info.fileModifiedAt),
        ),
        const Divider(height: 32),
        _InfoRow(
          label: '動画コーデック',
          value: formatMediaText(info.videoCodec),
        ),
        _InfoRow(
          label: '解像度',
          value: formatResolution(info.resolutionWidth, info.resolutionHeight),
        ),
        _InfoRow(
          label: 'フレームレート',
          value: info.frameRate == null
              ? unknownMediaValue
              : formatFrameRate(info.frameRate!),
        ),
        _InfoRow(
          label: 'スキャン方式',
          value: formatScanType(info.scanType),
        ),
        const Divider(height: 32),
        _InfoRow(
          label: '音声コーデック',
          value: formatMediaText(info.audioCodec),
        ),
        _InfoRow(
          label: '音声チャンネル',
          value: formatAudioChannel(info.audioChannel),
        ),
        _InfoRow(
          label: 'サンプリングレート',
          value: info.samplingRate == null
              ? unknownMediaValue
              : formatSamplingRate(info.samplingRate!),
        ),
      ],
    );
  }
}

/// ファイル情報の1項目 (見出し+値)。ファイルパスは選択・コピー可能にする。
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.selectable = false,
  });

  final String label;
  final String value;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayValue = value.isEmpty ? unknownMediaValue : value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          if (selectable)
            SelectableText(displayValue, style: theme.textTheme.bodyMedium)
          else
            Text(displayValue, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
