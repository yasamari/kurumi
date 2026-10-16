import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/network_type.dart';
import '../../core/settings/app_settings.dart';
import '../../data/backends/konomi/konomi_live.dart' show konomiLiveQualities;
import '../../data/backends/konomi/konomi_video_stream.dart'
    show konomiVideoQualities, originalKonomiVideoQuality;
import '../../domain/entities/backend_type.dart';
import 'url_edit_dialog.dart';

/// KonomiTV 専用の設定画面。
///
/// バックエンド設定の「KonomiTV」行から遷移する。サーバーURLと、テレビ/ビデオ ×
/// Wi-Fi/モバイル回線の画質を設定する。画質は再生開始時に現在の回線種別で選ばれ、
/// 再生中の回線切替ではユーザーの画質メニュー操作に任せる。
class KonomiSettingsScreen extends ConsumerWidget {
  const KonomiSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('KonomiTV')),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('設定の読み込みに失敗: $error')),
        data: (state) {
          // この画面は選択中バックエンドに関係なく KonomiTV の設定を編集する。
          // そのため利用可能な画質は KonomiTV の定数から取る (アクティブな
          // リポジトリの `getLiveQualities` は Mirakurun 選択時に空になる)。
          final videoOptions = [
            originalKonomiVideoQuality,
            ...konomiVideoQualities,
          ];
          return ListView(
            children: [
              ListTile(
                title: const Text('サーバーURL'),
                subtitle: Text(
                  state.konomiBaseUrl.isEmpty ? '未設定' : state.konomiBaseUrl,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showUrlDialog(context, ref, state.konomiBaseUrl),
              ),
              const Divider(),
              const _SectionHeader('テレビの画質'),
              _QualityTile(
                title: 'Wi-Fi接続時',
                quality: state.konomiLiveQualityWifi,
                options: konomiLiveQualities,
                onSelected: (quality) => ref
                    .read(appSettingsProvider.notifier)
                    .setKonomiLiveQuality(
                      networkType: NetworkType.wifi,
                      quality: quality,
                    ),
              ),
              _QualityTile(
                title: 'モバイル回線時',
                quality: state.konomiLiveQualityMobile,
                options: konomiLiveQualities,
                onSelected: (quality) => ref
                    .read(appSettingsProvider.notifier)
                    .setKonomiLiveQuality(
                      networkType: NetworkType.mobile,
                      quality: quality,
                    ),
              ),
              const Divider(),
              const _SectionHeader('ビデオの画質'),
              _QualityTile(
                title: 'Wi-Fi接続時',
                quality: state.konomiVideoQualityWifi,
                options: videoOptions,
                onSelected: (quality) => ref
                    .read(appSettingsProvider.notifier)
                    .setKonomiVideoQuality(
                      networkType: NetworkType.wifi,
                      quality: quality,
                    ),
              ),
              _QualityTile(
                title: 'モバイル回線時',
                quality: state.konomiVideoQualityMobile,
                options: videoOptions,
                onSelected: (quality) => ref
                    .read(appSettingsProvider.notifier)
                    .setKonomiVideoQuality(
                      networkType: NetworkType.mobile,
                      quality: quality,
                    ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// サーバーURLの編集ダイアログ。確定時に即保存する。
  Future<void> _showUrlDialog(
    BuildContext context,
    WidgetRef ref,
    String initialValue,
  ) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => UrlEditDialog(
        backendType: BackendType.konomiTv,
        initialValue: initialValue,
        hintText: 'http://192.168.1.2:7000',
        onInvalid: () => showUrlErrorDialog(context, 'URLの形式が正しくありません'),
        onSave: (url) =>
            ref.read(appSettingsProvider.notifier).setKonomiBaseUrl(url),
      ),
    );
  }
}

/// セクション見出し。
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

/// 画質1項目。タップで画質一覧のダイアログを開く。
class _QualityTile extends StatelessWidget {
  const _QualityTile({
    required this.title,
    required this.quality,
    required this.options,
    required this.onSelected,
  });

  final String title;
  final String quality;
  final List<String> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text(quality),
      trailing: const Icon(Icons.chevron_right),
      onTap: options.isEmpty ? null : () => _showQualityDialog(context),
    );
  }

  Future<void> _showQualityDialog(BuildContext context) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text(title),
          children: [
            RadioGroup<String>(
              groupValue: quality,
              onChanged: (value) {
                if (value != null) Navigator.of(context).pop(value);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final option in options)
                    RadioListTile<String>(title: Text(option), value: option),
                ],
              ),
            ),
          ],
        );
      },
    );
    if (selected != null) onSelected(selected);
  }
}
