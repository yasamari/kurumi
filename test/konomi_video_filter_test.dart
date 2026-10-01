import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/data/backends/konomi/konomi_dtos.dart';
import 'package:kurumi/src/data/backends/konomi/konomi_video_dtos.dart';
import 'package:kurumi/src/data/backends/konomi/konomi_video_filter.dart';
import 'package:kurumi/src/domain/entities/video_program.dart';

const _baseUrl = 'http://example.test:7000';

KonomiRecordedProgramDto _video({
  required int id,
  required String title,
  KonomiVideoChannelDto? channel,
}) {
  return KonomiRecordedProgramDto(
    id: id,
    title: title,
    description: '概要',
    startTime: DateTime(2026, 10, 1, 1, 0),
    endTime: DateTime(2026, 10, 1, 1, 48),
    channel: channel,
  );
}

KonomiVideoChannelDto _channel({
  required String displayId,
  required String name,
}) {
  return KonomiVideoChannelDto(
    displayChannelId: displayId,
    name: name,
    type: 'BS',
    networkId: 4,
    serviceId: 211,
    channelNumber: '211',
  );
}

void main() {
  test('サーバーの返却順を維持し、サムネイルURLを組み立てる', () {
    final response = KonomiRecordedProgramsResponse(
      total: 2,
      recordedPrograms: [
        _video(
          id: 3,
          title: '新しい番組',
          channel: _channel(displayId: 'bs211', name: 'BS11イレブン'),
        ),
        _video(
          id: 1,
          title: '古い番組',
          channel: _channel(displayId: 'bs141', name: 'BS日テレ'),
        ),
      ],
    );

    final items = buildVideoPrograms(response: response, baseUrl: _baseUrl);

    expect(items.map((e) => e.id).toList(), [3, 1]);
    expect(
      items[0].thumbnailUrl,
      '$_baseUrl/api/videos/3/thumbnail',
    );
    expect(items[0].channel?.name, 'BS11イレブン');
    expect(
      items[0].channel?.logoUrl,
      '$_baseUrl/api/channels/bs211/logo',
    );
  });

  test('チャンネル不明の録画はチャンネルなしで残す', () {
    final response = KonomiRecordedProgramsResponse(
      total: 1,
      recordedPrograms: [_video(id: 7, title: '不明局の番組')],
    );

    final items = buildVideoPrograms(response: response, baseUrl: _baseUrl);

    expect(items.single.channel, isNull);
    expect(items.single.title, '不明局の番組');
  });

  test('ジャンル・詳細・字幕が引き継がれる', () {
    final dto = KonomiRecordedProgramDto(
      id: 5,
      title: 'アニメ番組',
      subtitle: 'シャウラ/英雄',
      description: '概要',
      startTime: DateTime(2026, 10, 1, 1, 0),
      endTime: DateTime(2026, 10, 1, 1, 48),
      genres: const [
        KonomiGenreDto(major: 'アニメ', middle: '国内アニメ'),
      ],
      detail: const {'出演者': 'テスト太郎'},
      channel: _channel(displayId: 'bs211', name: 'BS11イレブン'),
    );

    final video = buildVideoProgram(dto: dto, baseUrl: _baseUrl);

    expect(video.genres, ['アニメ・国内アニメ']);
    expect(video.detail, {'出演者': 'テスト太郎'});
    expect(video.subtitle, 'シャウラ/英雄');
    final program = video.toTvProgram();
    expect(program.title, 'アニメ番組');
    expect(program.genres, ['アニメ・国内アニメ']);
  });

  test('サムネイルURLを組み立てる', () {
    expect(
      videoThumbnailUrl(baseUrl: _baseUrl, videoId: 42),
      '$_baseUrl/api/videos/42/thumbnail',
    );
  });

  test('録画ファイル情報が引き継がれる', () {
    final dto = KonomiRecordedProgramDto(
      id: 9,
      title: '録画番組',
      description: '概要',
      startTime: DateTime(2026, 10, 1, 1, 0),
      endTime: DateTime(2026, 10, 1, 1, 48),
      recordedVideo: KonomiRecordedVideoDto(
        filePath: '/recorded/test.m2ts',
        fileSize: 8589934592,
        recordingStartTime: DateTime(2026, 10, 1, 1, 0),
        recordingEndTime: DateTime(2026, 10, 1, 1, 48),
        fileModifiedAt: DateTime(2026, 10, 1, 2, 0),
        videoCodec: 'H.264',
        videoResolutionWidth: 1920,
        videoResolutionHeight: 1080,
        videoFrameRate: 29.97,
        videoScanType: 'Interlaced',
        primaryAudioCodec: 'AAC-LC',
        primaryAudioChannel: 'Stereo',
        primaryAudioSamplingRate: 48000,
      ),
    );

    final video = buildVideoProgram(dto: dto, baseUrl: _baseUrl);

    final file = video.recordedFile;
    expect(file, isNotNull);
    expect(file!.filePath, '/recorded/test.m2ts');
    expect(file.fileSize, 8589934592);
    expect(file.videoCodec, 'H.264');
    expect(file.resolutionWidth, 1920);
    expect(file.resolutionHeight, 1080);
    expect(file.frameRate, 29.97);
    expect(file.scanType, 'Interlaced');
    expect(file.audioCodec, 'AAC-LC');
    expect(file.audioChannel, 'Stereo');
    expect(file.samplingRate, 48000);
  });

  test('録画ファイル情報が無いときはnull', () {
    final video = buildVideoProgram(
      dto: _video(id: 11, title: '録画中の番組'),
      baseUrl: _baseUrl,
    );

    expect(video.recordedFile, isNull);
  });
}
