import 'package:dio/dio.dart';

import 'epg_database.dart';

/// EPG取得結果 (DB行の Companion 集合)。
class EpgFetchResult {
  const EpgFetchResult({required this.channels, required this.programs});

  final List<EpgChannelsCompanion> channels;
  final List<EpgProgramsCompanion> programs;
}

/// バックエンド別のEPG取得器。
///
/// Mirakurun が最初の実装。EDCB (TCP API) はこのインターフェースに
/// 実装を足すだけで、DB・表示層は変えない。
abstract class EpgFetcher {
  /// `dio.options.baseUrl` は正規化済み前提。
  Future<EpgFetchResult> fetch(Dio dio);
}
