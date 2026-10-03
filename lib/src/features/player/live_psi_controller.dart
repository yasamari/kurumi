import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/backends/konomi/eit.dart';
import '../../data/backends/konomi/live_program.dart';
import '../../data/backends/konomi/psi_archived_data.dart';
import '../../domain/entities/tv_program.dart';

/// PSIアーカイブストリームを開く関数。キャンセル用トークンを受け取る。
typedef PsiStreamFactory = Future<Stream<List<int>>> Function(
  CancelToken cancelToken,
);

/// KonomiTVのPSIアーカイブからEIT[p/f]を追うコントローラー。
///
/// 視聴画面の `_LivePlayerState` が所有する (回転で作り直されない位置のため、
/// 回転しても接続を保てる。チャンネル切替・画質切替では画面ごと作り直され
/// るため接続し直す)。実況コメントの [JikkyoCommentController] と同じ持ち方。
///
/// EIT[p/f] をデコードし、現在・次番組 ([present]/[following]) を
/// [TvProgram] で公開する。更新のたびに通知する。Mirakurun時は作らない。
class LivePsiController extends ChangeNotifier {
  LivePsiController({
    required this.networkId,
    required this.serviceId,
    required this.streamFactory,
  });

  /// フィルタ対象の network_id。
  final int networkId;

  /// フィルタ対象の service_id。
  final int serviceId;

  /// テスト時は差し替え可能にするためのストリーム取得口。
  final PsiStreamFactory streamFactory;

  /// EIT[p/f] の現在番組。未受信時は null。
  TvProgram? present;

  /// EIT[p/f] の次番組。未受信時は null。
  TvProgram? following;

  CancelToken? _cancelToken;
  Future<void>? _run;
  bool _disposed = false;

  /// いずれかを受信済みかどうか。
  bool get hasLive => present != null || following != null;

  /// 接続を開始する。多重呼び出しは無視する。
  void start() {
    if (_run != null) return;
    _cancelToken = CancelToken();
    _run = _runLoop(_cancelToken!);
  }

  Future<void> _runLoop(CancelToken cancelToken) async {
    final parser = PsiArchivedDataParser();
    final assembler = TsSectionAssembler();
    try {
      final stream = await streamFactory(cancelToken);
      await for (final chunk in stream) {
        if (_disposed || cancelToken.isCancelled) break;
        final bytes = chunk is Uint8List
            ? chunk
            : Uint8List.fromList(chunk);
        for (final psi in parser.addBytes(bytes)) {
          if (psi.pid != 0x12) continue;
          for (final section in assembler.addPackets(psi.packets)) {
            if (section.pid != 0x12) continue;
            handleSection(section.section);
          }
        }
      }
    } on DioException {
      // キャンセル・切断時は黙って止める。
    } on StateError {
      // アーカイブ破綻時も黙って止める (再試行は画面の再試行に任せる)。
    } finally {
      if (!_disposed) {
        // 正常終了・異常終了いずれも購読だけ終える。
      }
    }
  }

  /// 完成セクション1件を処理する。更新があれば真を返す (テスト用に公開)。
  @visibleForTesting
  bool handleSection(Uint8List section) {
    final eit = parseEitSection(section);
    if (eit == null) return false;
    final program = buildLiveTvProgram(
      eit,
      networkId: networkId,
      serviceId: serviceId,
    );
    if (program == null) return false;
    if (_disposed) return false;
    if (eit.sectionNumber == 0) {
      if (present != program) {
        present = program;
        notifyListeners();
        return true;
      }
    } else if (eit.sectionNumber == 1) {
      if (following != program) {
        following = program;
        notifyListeners();
        return true;
      }
    }
    return false;
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelToken?.cancel();
    super.dispose();
  }
}
