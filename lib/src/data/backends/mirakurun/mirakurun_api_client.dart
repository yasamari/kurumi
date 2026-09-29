import 'package:dio/dio.dart';

import 'mirakurun_program_dto.dart';
import 'mirakurun_service_dto.dart';

/// Mirakurun RESTクライアント。`dio.options.baseUrl` は正規化済み前提。
class MirakurunApiClient {
  MirakurunApiClient(this._dio);

  final Dio _dio;

  Future<List<MirakurunServiceDto>> getServices() async {
    final response = await _dio.get<List<dynamic>>('/api/services');
    final data = response.data ?? [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(MirakurunServiceDto.fromJson)
        .toList();
  }

  Future<List<MirakurunProgramDto>> getPrograms() async {
    final response = await _dio.get<List<dynamic>>('/api/programs');
    final data = response.data ?? [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(MirakurunProgramDto.fromJson)
        .toList();
  }

  /// 接続テスト用。200以外・到達不能は例外送出する。
  Future<void> checkVersion() async {
    await _dio.get<dynamic>('/api/version');
  }
}
