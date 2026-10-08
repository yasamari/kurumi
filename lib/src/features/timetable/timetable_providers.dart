// `select` / `selectAsync` は拡張なので、riverpod_annotation だけでは入らない。
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/dio_provider.dart';
import '../../core/settings/app_settings.dart';
import '../../data/backends/konomi/konomi_api_client.dart';
import '../../data/backends/konomi/konomi_timetable_filter.dart';
import '../../data/backends/mirakurun/mirakurun_timetable.dart';
import '../../domain/entities/backend_type.dart';
import '../../domain/entities/timetable.dart';
import '../../domain/repositories/tv_repository.dart';
import '../tv/epg_providers.dart';
import 'timetable_layout.dart';

part 'timetable_providers.g.dart';

/// 番組表1日分。未設定時は [BackendUnconfiguredException] を送出する。
///
/// `[dayStartMs, dayStartMs + 24時間)` の期間を返す。KonomiTV は番組表API
/// から都度取得し、Mirakurun はEPGキャッシュから組み立てる (通信なし)。
/// 次の番組境界で自分を作り直す (未来の境界が無い過去日には張らない)。
///
/// **設定の有無と接続先だけを選ぶ。** [appSettingsProvider.future] をそのまま
/// 購読すると、接続先と無関係な設定 (弾幕・字幕の表示設定など) を変えるたびに
/// future のインスタンスが変わって取り直しが始まる。
@riverpod
Future<TimetableData> timetableData(Ref ref, int dayStartMs) async {
  final isConfigured = await ref.watch(
    appSettingsProvider.selectAsync((settings) => settings.isConfigured),
  );
  if (!isConfigured) {
    throw const BackendUnconfiguredException();
  }
  final endpoint = ref.watch(
    appSettingsProvider.select(
      (settings) => (
        type: settings.value?.backendType ?? BackendType.mirakurun,
        mirakurunBaseUrl: settings.value?.mirakurunBaseUrl ?? '',
        konomiBaseUrl: settings.value?.konomiBaseUrl ?? '',
      ),
    ),
  );
  final dayEndMs = dayStartMs + timetableDayLengthMs;
  final List<TimetableChannel> columns;
  if (endpoint.type == BackendType.konomiTv) {
    final dio = ref.watch(backendDioProvider);
    final client = KonomiApiClient(dio);
    final start = DateTime.fromMillisecondsSinceEpoch(dayStartMs);
    final end = DateTime.fromMillisecondsSinceEpoch(dayEndMs);
    final (timetable, channels) = await (
      client.getTimetable(start: start, end: end),
      client.getChannels(),
    ).wait;
    columns = buildKonomiTimetableColumns(
      timetable: timetable,
      channels: channels,
      baseUrl: endpoint.konomiBaseUrl,
      startMs: dayStartMs,
      endMs: dayEndMs,
    );
  } else {
    // Mirakurun: 同期を済ませてからキャッシュを読む。通信は起きない。
    await ref.watch(mirakurunEpgSyncProvider.future);
    final dao = ref.watch(epgDatabaseProvider).epgDao;
    final channels = await dao.timetableChannels(
      sourceBackend: BackendType.mirakurun.name,
    );
    final programs = await dao.timetablePrograms(
      sourceBackend: BackendType.mirakurun.name,
      startMs: dayStartMs,
      endMs: dayEndMs,
    );
    columns = buildMirakurunTimetableColumns(
      channels: channels,
      programs: programs,
      baseUrl: endpoint.mirakurunBaseUrl,
    );
  }
  // 次の番組境界で自分を作り直す。過去日のように未来の境界が無ければ
  // タイマーを張らない (nowラインの移動は自律更新ウィジェットが行う)。
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  final tickMs = nextTimetableTickMs(columns: columns, nowMs: nowMs);
  if (tickMs != null) {
    final timer = Timer(
      Duration(milliseconds: tickMs - nowMs),
      ref.invalidateSelf,
    );
    ref.onDispose(timer.cancel);
  }
  return TimetableData(startMs: dayStartMs, endMs: dayEndMs, channels: columns);
}
