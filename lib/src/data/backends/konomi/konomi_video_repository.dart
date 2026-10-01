import 'package:dio/dio.dart';

import '../../../domain/entities/video_program.dart';
import '../../../domain/repositories/tv_repository.dart';
import '../../../domain/repositories/video_repository.dart';
import 'konomi_api_client.dart';
import 'konomi_video_filter.dart';
import 'konomi_video_stream.dart';

/// KonomiTV向け [VideoRepository] 実装。
///
/// 一覧は `/api/videos`、キーワードありは `/api/videos/search` を使う。
/// ページサイズはサーバー固定で30件。
class KonomiVideoRepository implements VideoRepository {
  KonomiVideoRepository(Dio dio, {required this.baseUrl})
      : _client = KonomiApiClient(dio);

  final String baseUrl;
  final KonomiApiClient _client;

  @override
  Future<VideoPage> listVideos({
    String query = '',
    VideoSortOrder order = VideoSortOrder.newest,
    int page = 1,
  }) async {
    if (baseUrl.isEmpty) {
      throw const BackendUnconfiguredException();
    }
    final trimmed = query.trim();
    final response = trimmed.isEmpty
        ? await _client.getVideos(order: order.queryParam, page: page)
        : await _client.searchVideos(
            query: trimmed,
            order: order.queryParam,
            page: page,
          );
    return VideoPage(
      items: buildVideoPrograms(response: response, baseUrl: baseUrl),
      total: response.total,
    );
  }

  @override
  Future<VideoProgram> getVideo(int id) async {
    if (baseUrl.isEmpty) {
      throw const BackendUnconfiguredException();
    }
    final dto = await _client.getVideo(id);
    return buildVideoProgram(dto: dto, baseUrl: baseUrl);
  }

  @override
  VideoStreamInfo getVideoStream({
    required int videoId,
    required String quality,
    required String sessionId,
  }) {
    if (baseUrl.isEmpty) {
      throw const BackendUnconfiguredException();
    }
    final normalized = normalizeKonomiVideoQuality(quality);
    if (isOriginalKonomiVideoQuality(normalized)) {
      return VideoStreamInfo(
        url: buildKonomiVideoDownloadUrl(baseUrl: baseUrl, videoId: videoId),
        isHls: false,
        deinterlace: true,
      );
    }
    return VideoStreamInfo(
      url: buildKonomiVideoHlsUrl(
        baseUrl: baseUrl,
        videoId: videoId,
        quality: normalized,
        sessionId: sessionId,
      ),
      isHls: true,
      deinterlace: false,
    );
  }

  @override
  Future<void> keepVideoStreamAlive({
    required int videoId,
    required String quality,
    required String sessionId,
  }) async {
    if (baseUrl.isEmpty) {
      throw const BackendUnconfiguredException();
    }
    await _client.keepVideoStreamAlive(
      videoId: videoId,
      quality: normalizeKonomiVideoQuality(quality),
      sessionId: sessionId,
    );
  }
}
