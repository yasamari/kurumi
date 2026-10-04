// `select` は拡張なので、riverpod_annotation だけでは入らない。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/dio_provider.dart';
import '../../core/settings/app_settings.dart';
import '../entities/backend_type.dart';
import '../repositories/tv_repository.dart';
import '../repositories/video_repository.dart';
import '../../data/backends/konomi/konomi_repository.dart';
import '../../data/backends/konomi/konomi_video_repository.dart';
import '../../data/backends/mirakurun/mirakurun_repository.dart';

part 'backend_provider.g.dart';

/// 設定のバックエンド種別に応じた [TvRepository] を返す factory。
///
/// 新バックエンド追加時はこの switch に1行追加するだけ。
///
/// **接続先 (種別とベースURL) だけを選ぶ。** [appSettingsProvider] を丸ごと
/// 購読すると、接続先と無関係な設定 (弾幕・字幕の表示設定など) を変えるたびに
/// リポジトリが作り直され、チャンネル一覧 → ライブストリームと伝って、視聴中の
/// プレイヤーまで作り直される (プレイヤーの破棄はセッションの切断を伴う)。
/// [videoRepository] と [backendDio] も同じ考えで接続先だけを見ている。
@riverpod
TvRepository tvRepository(Ref ref) {
  final endpoint = ref.watch(
    appSettingsProvider.select(
      (settings) => (
        type: settings.value?.backendType ?? BackendType.mirakurun,
        baseUrl: settings.value?.activeBaseUrl ?? '',
      ),
    ),
  );
  final dio = ref.watch(backendDioProvider);
  return switch (endpoint.type) {
    BackendType.mirakurun => MirakurunTvRepository(
      dio,
      baseUrl: endpoint.baseUrl,
    ),
    BackendType.konomiTv => KonomiTvRepository(
      dio,
      baseUrl: endpoint.baseUrl,
    ),
  };
}

/// ビデオ (録画番組) 用の [VideoRepository] を返す factory。
///
/// 録画番組に対応するのはKonomiTVのみ。Mirakurun選択時は空URLのリポジトリを
/// 返し、利用時に [BackendUnconfiguredException] として扱う。ビデオ画面自体は
/// router の redirect で Mirakurun 時に `/tv` へ戻されるため、通常は到達しない。
///
/// [tvRepository] と同じく接続先だけを選ぶ。
@riverpod
VideoRepository videoRepository(Ref ref) {
  final endpoint = ref.watch(
    appSettingsProvider.select(
      (settings) => (
        type: settings.value?.backendType ?? BackendType.mirakurun,
        baseUrl: settings.value?.activeBaseUrl ?? '',
      ),
    ),
  );
  final dio = ref.watch(backendDioProvider);
  return switch (endpoint.type) {
    BackendType.mirakurun => KonomiVideoRepository(dio, baseUrl: ''),
    BackendType.konomiTv => KonomiVideoRepository(
      dio,
      baseUrl: endpoint.baseUrl,
    ),
  };
}