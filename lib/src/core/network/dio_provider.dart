import 'package:dio/dio.dart';
// `select` は拡張なので、riverpod_annotation だけでは入らない。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../settings/app_settings.dart';

part 'dio_provider.g.dart';

/// 現在選択中バックエンド向けの Dio。
///
/// baseUrl は設定画面で正規化済みの値をそのまま使う。
///
/// **ベースURLだけを選択する。** `appSettingsProvider` を丸ごと購読すると、
/// 接続先と無関係な設定 (弾幕・字幕の表示設定など) を変えるたびに Dio  ->
/// `TvRepository` -> チャンネル一覧 -> ライブストリーム が作り直され、
/// 視聴中のプレイヤーが作り直される。
@riverpod
Dio backendDio(Ref ref) {
  final baseUrl = ref.watch(
    appSettingsProvider.select(
      (settings) => settings.value?.activeBaseUrl ?? '',
    ),
  );
  return Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
}
