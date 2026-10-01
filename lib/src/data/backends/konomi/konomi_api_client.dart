import 'package:dio/dio.dart';

import 'konomi_dtos.dart';
import 'konomi_video_dtos.dart';

/// KonomiTV RESTクライアント。`dio.options.baseUrl` は正規化済み前提。
class KonomiApiClient {
  KonomiApiClient(this._dio);

  final Dio _dio;

  Future<KonomiChannelsResponse> getChannels() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/channels');
    return KonomiChannelsResponse.fromJson(response.data ?? {});
  }

  /// 接続テスト用。200以外・到達不能は例外送出する。
  Future<void> checkVersion() async {
    await _dio.get<dynamic>('/api/version');
  }

  /// 録画番組一覧を30件ずつ取得する。
  ///
  /// [order] は `desc` (新しい順) か `asc` (古い順)。[page] は1始まり。
  Future<KonomiRecordedProgramsResponse> getVideos({
    String order = 'desc',
    int page = 1,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/videos',
      queryParameters: {'order': order, 'page': page},
    );
    return KonomiRecordedProgramsResponse.fromJson(response.data ?? {});
  }

  /// 録画番組をキーワード検索する (30件ずつ)。
  ///
  /// キーワードは title / series_title / subtitle のいずれかに部分一致した
  /// 番組を返す。スペース区切りで AND 検索になる (サーバー側の仕様)。
  Future<KonomiRecordedProgramsResponse> searchVideos({
    required String query,
    String order = 'desc',
    int page = 1,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/videos/search',
      queryParameters: {'query': query, 'order': order, 'page': page},
    );
    return KonomiRecordedProgramsResponse.fromJson(response.data ?? {});
  }

  /// 録画番組1件を取得する。
  Future<KonomiRecordedProgramDto> getVideo(int videoId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/videos/$videoId',
    );
    return KonomiRecordedProgramDto.fromJson(response.data ?? {});
  }

  /// HLS視聴セッションを維持する。成功時は204で本文なし。
  Future<void> keepVideoStreamAlive({
    required int videoId,
    required String quality,
    required String sessionId,
  }) async {
    await _dio.put<dynamic>(
      '/api/streams/video/$videoId/$quality/keep-alive',
      queryParameters: {'session_id': sessionId},
    );
  }
}
