import 'dart:convert';
import 'dart:isolate';

import 'package:dio/dio.dart';

import '../../epg/epg_fetcher.dart';
import 'mirakurun_api_client.dart';
import 'mirakurun_epg_mapping.dart';
import 'mirakurun_program_dto.dart';

/// 生JSON文字列を番組DTO列に変換する。worker isolate で実行する。
List<MirakurunProgramDto> _decodePrograms(String body) {
  final data = jsonDecode(body) as List<dynamic>;
  return data
      .whereType<Map<String, dynamic>>()
      .map(MirakurunProgramDto.fromJson)
      .toList();
}

/// Mirakurun向け [EpgFetcher] 実装。
///
/// `/api/services` (軽量) と `/api/programs` (約10MB) を並列取得する。
/// 番組JSONのパースは worker isolate で行い、UIスレッドを止めない。
class MirakurunEpgFetcher implements EpgFetcher {
  const MirakurunEpgFetcher();

  @override
  Future<EpgFetchResult> fetch(Dio dio) async {
    final client = MirakurunApiClient(dio);
    final servicesFuture = client.getServices();
    final programsFuture = dio.get<String>(
      '/api/programs',
      options: Options(responseType: ResponseType.plain),
    );
    final services = await servicesFuture;
    final programsBody = (await programsFuture).data ?? '[]';
    // DTOは素のデータ保持のみのため isolate 境界を越えられる。
    final programs = await Isolate.run(() => _decodePrograms(programsBody));
    return EpgFetchResult(
      channels: [
        for (var i = 0; i < services.length; i++)
          epgChannelFromService(services[i], sortOrder: i),
      ],
      programs: [for (final program in programs) epgProgramFromDto(program)],
    );
  }
}
