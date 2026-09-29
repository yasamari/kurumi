import 'package:dio/dio.dart';

import 'konomi_dtos.dart';

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
}
