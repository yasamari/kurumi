import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'konomi_api_client.dart';
import 'psi_archived_data.dart';

/// KonomiTVのPSIアーカイブをTSパケット列として流す源。
///
/// [LivePsiController] に渡す `packets` を作る。`.psc` を展開し、
/// EIT (PID 0x12) のパケットだけ188バイト境界のまま取り出す。
/// [close] で上流の取得をやめる。
class KonomiTsPackets {
  KonomiTsPackets({
    required Dio dio,
    required this.displayChannelId,
    required this.quality,
  }) : _client = KonomiApiClient(dio);

  final String displayChannelId;
  final String quality;
  final KonomiApiClient _client;

  CancelToken? _cancelToken;

  /// パケット列の購読を開始する。多重呼び出しは同じストリームを使い回す。
  Stream<Uint8List>? _stream;

  Stream<Uint8List> get stream {
    final existing = _stream;
    if (existing != null) return existing;
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    final created = _run(cancelToken);
    _stream = created;
    return created;
  }

  Stream<Uint8List> _run(CancelToken cancelToken) async* {
    final parser = PsiArchivedDataParser();
    final upstream = await _client.streamPsiArchivedData(
      displayChannelId: displayChannelId,
      quality: quality,
      cancelToken: cancelToken,
    );
    await for (final chunk in upstream) {
      if (cancelToken.isCancelled) break;
      final bytes = chunk is Uint8List
          ? chunk
          : Uint8List.fromList(chunk);
      for (final psi in parser.addBytes(bytes)) {
        if (psi.pid != 0x12) continue;
        yield psi.packets;
      }
    }
  }

  /// 上流の取得をやめる。
  void close() {
    _cancelToken?.cancel();
  }
}
