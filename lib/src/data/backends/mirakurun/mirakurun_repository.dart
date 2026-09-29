import 'package:dio/dio.dart';

import '../../../domain/entities/channel_item.dart';
import '../../../domain/repositories/tv_repository.dart';
import 'mirakurun_api_client.dart';
import 'mirakurun_filter.dart';

/// Mirakurun向け [TvRepository] 実装。
class MirakurunTvRepository implements TvRepository {
  MirakurunTvRepository(Dio dio, {required this.baseUrl})
      : _client = MirakurunApiClient(dio);

  final String baseUrl;
  final MirakurunApiClient _client;

  @override
  Future<List<ChannelItem>> getNowOnAirChannels() async {
    if (baseUrl.isEmpty) {
      throw const BackendUnconfiguredException();
    }
    final servicesFuture = _client.getServices();
    final programsFuture = _client.getPrograms();
    final services = await servicesFuture;
    final programs = await programsFuture;
    return buildMirakurunChannelItems(
      services: services,
      programs: programs,
      now: DateTime.now(),
      baseUrl: baseUrl,
    );
  }

  @override
  Future<void> testConnection() => _client.checkVersion();
}
