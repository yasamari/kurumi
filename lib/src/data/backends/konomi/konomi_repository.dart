import 'package:dio/dio.dart';

import '../../../domain/entities/channel_item.dart';
import '../../../domain/repositories/tv_repository.dart';
import 'konomi_api_client.dart';
import 'konomi_filter.dart';

/// KonomiTV向け [TvRepository] 実装。
///
/// チャンネル一覧に現在・次番組が同梱されるため `/api/channels` 1回で足りる。
class KonomiTvRepository implements TvRepository {
  KonomiTvRepository(Dio dio, {required this.baseUrl})
      : _client = KonomiApiClient(dio);

  final String baseUrl;
  final KonomiApiClient _client;

  @override
  Future<List<ChannelItem>> getNowOnAirChannels() async {
    if (baseUrl.isEmpty) {
      throw const BackendUnconfiguredException();
    }
    final response = await _client.getChannels();
    return buildKonomiChannelItems(response: response, baseUrl: baseUrl);
  }

  @override
  Future<void> testConnection() => _client.checkVersion();
}
