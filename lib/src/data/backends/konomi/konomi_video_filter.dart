import '../../../domain/entities/channel.dart';
import '../../../domain/entities/channel_type.dart';
import '../../../domain/entities/recorded_file_info.dart';
import '../../../domain/entities/video_program.dart';
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
    recordedFile: buildRecordedFileInfo(dto.recordedVideo),
  );
}

/// 録画ファイル情報を [RecordedFileInfo] に変換する純粋関数。
///
/// DTO が null (録画中などで情報が無い) のときは null を返す。
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
  );
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

/// サムネイル画像のURLを組み立てる純粋関数。
String videoThumbnailUrl({
  required String baseUrl,
  required int videoId,
}) =>
    '$baseUrl/api/videos/$videoId/thumbnail';
