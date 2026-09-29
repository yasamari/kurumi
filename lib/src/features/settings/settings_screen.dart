import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/settings/app_settings.dart';

/// 設定カテゴリの一覧。各カテゴリの詳細画面へ遷移する。
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    final backendSummary = settings.when(
      data: (state) {
        final url = state.activeBaseUrl;
        return url.isEmpty
            ? '${state.backendType.label}・未設定'
            : '${state.backendType.label}・$url';
      },
      loading: () => '読み込み中',
      error: (_, _) => '読み込み失敗',
    );

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: const Text('バックエンド'),
            subtitle: Text(backendSummary),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/backend'),
          ),
        ],
      ),
    );
  }
}
