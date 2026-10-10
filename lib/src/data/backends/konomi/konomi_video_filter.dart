import 'dart:math';

import '../../../domain/entities/channel.dart';
import '../../../domain/entities/channel_type.dart';
import '../../../domain/entities/cm_section.dart';
import '../../../domain/entities/recorded_file_info.dart';
import '../../../domain/entities/video_program.dart';
import '../../../domain/entities/video_thumbnail_tiles.dart';
import 'konomi_filter.dart';
import 'konomi_video_dtos.dart';

/// 録画番組1件を [VideoProgram] に変換する純粋関数。
VideoProgram buildVideoProgram({
  required KonomiRecordedProgramDto dto,
  required String baseUrl,
}) {
  Channel? channel;
  final dtoChannel = dto.channel;
  if (dtoChannel != null) {
    final displayId = dtoChannel.displayChannelId ?? '';
    channel = Channel(
      id: displayId,
      name: dtoChannel.name ?? '',
      channelType: channelTypeFromString(dtoChannel.type),
      networkId: dtoChannel.networkId ?? 0,
      serviceId: dtoChannel.serviceId ?? 0,
      channelNumber: dtoChannel.channelNumber ?? '',
      logoUrl: displayId.isEmpty
          ? null
          : '$baseUrl/api/channels/$displayId/logo',
    );
  }
  return VideoProgram(
    id: dto.id,
    title: dto.title,
    seriesTitle: dto.seriesTitle,
    episodeNumber: dto.episodeNumber,
    subtitle: dto.subtitle,
    description: dto.description,
    detail: Map<String, String>.of(dto.detail),
    startAt: dto.startTime,
    endAt: dto.endTime,
    genres: konomiGenreLabels(dto.genres),
    channel: channel,
    thumbnailUrl: videoThumbnailUrl(baseUrl: baseUrl, videoId: dto.id),
    thumbnailTiles: buildVideoThumbnailTiles(
      dto: dto.recordedVideo?.thumbnailInfo?.tile,
      durationSec: dto.duration,
      baseUrl: baseUrl,
      videoId: dto.id,
    ),
    recordedFile: buildRecordedFileInfo(dto.recordedVideo),
  );
}

/// 録画ファイル情報を [RecordedFileInfo] に変換する純粋関数。
///
/// DTO が null (録画中などで情報が無い) のときは null を返す。
/// CM区間は未解析 (null)・CMなし (空) とも空一覧に畳み、正規化する。
RecordedFileInfo? buildRecordedFileInfo(KonomiRecordedVideoDto? dto) {
  if (dto == null) return null;
  return RecordedFileInfo(
    filePath: dto.filePath,
    fileSize: dto.fileSize,
    recordingStartTime: dto.recordingStartTime,
    recordingEndTime: dto.recordingEndTime,
    fileModifiedAt: dto.fileModifiedAt,
    videoCodec: dto.videoCodec,
    resolutionWidth: dto.videoResolutionWidth,
    resolutionHeight: dto.videoResolutionHeight,
    frameRate: dto.videoFrameRate,
    scanType: dto.videoScanType,
    audioCodec: dto.primaryAudioCodec,
    audioChannel: dto.primaryAudioChannel,
    samplingRate: dto.primaryAudioSamplingRate,
    cmSections: buildCmSections(dto.cmSections),
  );
}

/// CM区間DTOを表示用 [CmSection] に変換する純粋関数。
///
/// null (未解析) は空一覧に畳む。不正値の除去・整列・結合は
/// [normalizeCmSections] に委ねる。
List<CmSection> buildCmSections(List<KonomiCmSectionDto>? dtos) {
  if (dtos == null || dtos.isEmpty) return const [];
  return normalizeCmSections([
    for (final dto in dtos)
      CmSection(startTime: dto.startTime, endTime: dto.endTime),
  ]);
}

/// 録画番組一覧レスポンスから表示用 [VideoProgram] を組み立てる純粋関数。
///
/// 出力順はサーバーの返却順 (並び順 `order` どおり) を維持する。
List<VideoProgram> buildVideoPrograms({
  required KonomiRecordedProgramsResponse response,
  required String baseUrl,
}) {
  return [
    for (final dto in response.recordedPrograms)
      buildVideoProgram(dto: dto, baseUrl: baseUrl),
  ];
}

/// 旧仕様のタイルの幅 (px)。
const _legacyTileWidth = 480;

/// 旧仕様のタイルの高さ (px)。
const _legacyTileHeight = 270;

/// 旧仕様の1行のタイル枚数。
const _legacyTileColumnCount = 34;

/// シークバー用のサムネイル並びを組み立てる純粋関数。
///
/// `thumbnail_info.tile` があればその並びを使う。無い録画 (DB移行前の
/// サーバー) は旧仕様 (1枚480x270・1行34枚) を仮定し、間隔だけ尺から求める
/// (KonomiTV の Web クライアントと同じフォールバック)。
///
/// 尺が取れない録画 (録画中など) は旧仕様の枚数が出せないため null にする。
VideoThumbnailTiles? buildVideoThumbnailTiles({
  required KonomiThumbnailTileInfoDto? dto,
  required double durationSec,
  required String baseUrl,
  required int videoId,
}) {
  final tileWidth = dto?.tileWidth ?? 0;
  final tileHeight = dto?.tileHeight ?? 0;
  final columnCount = dto?.columnCount ?? 0;
  final totalTiles = dto?.totalTiles ?? 0;
  final intervalSec =
      dto?.intervalSec ?? legacyThumbnailTileIntervalSec(durationSec: durationSec);
  if (tileWidth > 0 &&
      tileHeight > 0 &&
      columnCount > 0 &&
      totalTiles > 0) {
    return VideoThumbnailTiles(
      url: videoThumbnailTiledUrl(baseUrl: baseUrl, videoId: videoId),
      tileWidth: tileWidth,
      tileHeight: tileHeight,
      columnCount: columnCount,
      totalTiles: totalTiles,
      intervalSec: intervalSec,
    );
  }
  // 旧仕様を仮定する。尺が無いと枚数が出せないので諦める。
  if (durationSec <= 0) return null;
  return VideoThumbnailTiles(
    url: videoThumbnailTiledUrl(baseUrl: baseUrl, videoId: videoId),
    tileWidth: _legacyTileWidth,
    tileHeight: _legacyTileHeight,
    columnCount: _legacyTileColumnCount,
    totalTiles: max(1, (durationSec / intervalSec).ceil()),
    intervalSec: intervalSec,
  );
}

/// 旧仕様のサムネイル間隔 (秒) を尺から求める純粋関数。
///
/// server/app/metadata/ThumbnailGenerator.py の旧仕様と同じ式: 30分以下は
/// 一律5秒、30分超は対数的に増加を抑えて最大30秒。
double legacyThumbnailTileIntervalSec({required double durationSec}) {
  const baseDurationMin = 30;
  const baseIntervalSec = 5.0;
  const maxIntervalSec = 30.0;
  final minutes = durationSec ~/ 60;
  if (minutes <= baseDurationMin) return baseIntervalSec;
  final ratio = minutes / baseDurationMin;
  final interval = baseIntervalSec * ratio / (log(1 + ratio / 2) / log(2));
  return min(maxIntervalSec, interval);
}

/// サムネイル画像のURLを組み立てる純粋関数。
String videoThumbnailUrl({
  required String baseUrl,
  required int videoId,
}) => '$baseUrl/api/videos/$videoId/thumbnail';

/// シークバー用のサムネイル並び画像のURLを組み立てる純粋関数。
String videoThumbnailTiledUrl({
  required String baseUrl,
  required int videoId,
}) => '$baseUrl/api/videos/$videoId/thumbnail/tiled';
