import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/settings/app_settings.dart';
import '../../domain/entities/backend_type.dart';
import '../../domain/providers/backend_provider.dart';

part 'backend_settings_screen.g.dart';

/// 接続テストの実行状態。
@riverpod
class ConnectionTest extends _$ConnectionTest {
  @override
  FutureOr<void> build() {}

  Future<void> run() async {
    state = const AsyncLoading();
    try {
      final repository = ref.read(tvRepositoryProvider);
      await repository.testConnection();
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}

/// バックエンド設定画面。
///
/// 種別の選択と、バックエンド別の設定画面 (Mirakurun / KonomiTV) への入口、
/// 接続テストを並べる。行は ListTile、区切りは Divider、編集・結果表示は
/// Dialog のみで構成する。
class BackendSettingsScreen extends ConsumerWidget {
  const BackendSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final connectionTest = ref.watch(connectionTestProvider);

    ref.listen(connectionTestProvider, (previous, next) {
      if (previous?.isLoading == true && !next.isLoading) {
        final message = next.when(
          data: (_) => '接続に成功しました',
          loading: () => '',
          error: (error, _) => '接続失敗: $error',
        );
        if (message.isNotEmpty) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(message)));
        }
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('バックエンド')),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('設定の読み込みに失敗: $error')),
        data: (state) {
          return ListView(
            children: [
              ListTile(
                title: const Text('バックエンド種別'),
                subtitle: Text(state.backendType.label),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    _showBackendTypeDialog(context, ref, state.backendType),
              ),
              const Divider(),
              ListTile(
                title: const Text('Mirakurun'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/settings/backend/mirakurun'),
              ),
              ListTile(
                title: const Text('KonomiTV'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/settings/backend/konomi'),
              ),
              const Divider(),
              ListTile(
                title: const Text('接続テスト'),
                subtitle: Text(
                  connectionTest.isLoading ? 'テスト中…' : '現在の設定で接続を確認',
                ),
                trailing: connectionTest.isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: connectionTest.isLoading
                    ? null
                    : () => ref.read(connectionTestProvider.notifier).run(),
              ),
            ],
          );
        },
      ),
    );
  }

  /// バックエンド種別の選択ダイアログ。
  Future<void> _showBackendTypeDialog(
    BuildContext context,
    WidgetRef ref,
    BackendType current,
  ) {
    return showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('バックエンド種別'),
          children: [
            RadioGroup<BackendType>(
              groupValue: current,
              onChanged: (value) {
                if (value != null) {
                  ref.read(appSettingsProvider.notifier).setBackendType(value);
                }
                Navigator.of(context).pop();
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final type in BackendType.values)
                    RadioListTile<BackendType>(
                      title: Text(type.label),
                      value: type,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
