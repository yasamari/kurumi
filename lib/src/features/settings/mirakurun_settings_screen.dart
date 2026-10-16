import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/app_settings.dart';
import '../../core/settings/app_settings_state.dart';
import '../../domain/entities/backend_type.dart';
import 'url_edit_dialog.dart';

/// Mirakurun 専用の設定画面。
///
/// バックエンド設定の「Mirakurun」行から遷移する。サーバーURLとEPGキャッシュ
/// (番組データ) の更新間隔を設定する。
class MirakurunSettingsScreen extends ConsumerWidget {
  const MirakurunSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mirakurun')),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('設定の読み込みに失敗: $error')),
        data: (state) {
          return ListView(
            children: [
              ListTile(
                title: const Text('サーバーURL'),
                subtitle: Text(
                  state.mirakurunBaseUrl.isEmpty
                      ? '未設定'
                      : state.mirakurunBaseUrl,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    _showUrlDialog(context, ref, state.mirakurunBaseUrl),
              ),
              const Divider(),
              ListTile(
                title: const Text('番組データの更新間隔'),
                subtitle: Text(
                  '${state.mirakurunEpgRefreshIntervalHours}時間ごとに更新',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showEpgIntervalDialog(
                  context,
                  ref,
                  state.mirakurunEpgRefreshIntervalHours,
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
        backendType: BackendType.mirakurun,
        initialValue: initialValue,
        hintText: 'http://192.168.1.2:40772',
        // エラーダイアログはダイアログ自身のコンテキストではなく呼び出し元の
        // コンテキストで出す（pop 済みでも使用可能なため）。
        onInvalid: () => showUrlErrorDialog(context, 'URLの形式が正しくありません'),
        onSave: (url) =>
            ref.read(appSettingsProvider.notifier).setMirakurunBaseUrl(url),
      ),
    );
  }

  /// EPG更新間隔の選択ダイアログ。1〜24時間のスライダーで選ぶ。
  Future<void> _showEpgIntervalDialog(
    BuildContext context,
    WidgetRef ref,
    int current,
  ) {
    return showDialog(
      context: context,
      builder: (context) {
        return _EpgIntervalDialog(
          initialValue: current,
          onSave: (hours) => ref
              .read(appSettingsProvider.notifier)
              .setMirakurunEpgRefreshIntervalHours(hours),
        );
      },
    );
  }
}

/// EPG更新間隔の選択ダイアログ。
class _EpgIntervalDialog extends StatefulWidget {
  const _EpgIntervalDialog({required this.initialValue, required this.onSave});

  final int initialValue;
  final ValueChanged<int> onSave;

  @override
  State<_EpgIntervalDialog> createState() => _EpgIntervalDialogState();
}

class _EpgIntervalDialogState extends State<_EpgIntervalDialog> {
  late double _hours;

  @override
  void initState() {
    super.initState();
    _hours = widget.initialValue.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('番組データの更新間隔'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${_hours.round()}時間ごとに更新'),
          Slider(
            min: AppSettingsState.minMirakurunEpgRefreshIntervalHours
                .toDouble(),
            max: AppSettingsState.maxMirakurunEpgRefreshIntervalHours
                .toDouble(),
            divisions:
                AppSettingsState.maxMirakurunEpgRefreshIntervalHours -
                AppSettingsState.minMirakurunEpgRefreshIntervalHours,
            label: '${_hours.round()}時間',
            value: _hours,
            onChanged: (value) => setState(() => _hours = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        TextButton(
          onPressed: () {
            widget.onSave(_hours.round());
            Navigator.of(context).pop();
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
