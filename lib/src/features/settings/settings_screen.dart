import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 設定カテゴリの一覧。各カテゴリの詳細画面へ遷移する。
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: const Text('バックエンド'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/backend'),
          ),
          ListTile(
            leading: const Icon(Icons.info_outlined),
            title: const Text('このアプリについて'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/about'),
          ),
        ],
      ),
    );
  }
}
