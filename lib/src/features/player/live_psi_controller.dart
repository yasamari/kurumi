import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../data/ts/eit.dart';
import '../../data/ts/live_program.dart';
import '../../domain/entities/tv_program.dart';

/// 再生中TSのEIT[p/f]を追うコントローラー。
///
/// 視聴画面の `_LivePlayerState` が所有する (回転で作り直されない位置のため、
/// 回転しても接続を保てる。チャンネル切替・画質切替では画面ごと作り直され
/// るため接続し直す)。実況コメントの [JikkyoCommentController] と同じ持ち方。
///
/// TSパケット源はバックエンドごとに差し替える:
/// - KonomiTV: PSIアーカイブAPIの展開結果 (188バイトTSパケット列)
/// - Mirakurun等: 再生中TSのタップ (188バイト境界に整列済み)
///
/// EIT[p/f] をデコードし、現在・次番組 ([present]/[following]) を
/// [TvProgram] で公開する。更新のたびに通知する。再生中の番組情報は
/// ライブEIT[p/f]からのみ取得し、`/api/channels` 等の情報は使わない。
class LivePsiController extends ChangeNotifier {
  LivePsiController({
    required this.networkId,
    required this.serviceId,
    required this.packets,
  });

  /// フィルタ対象の network_id。
  final int networkId;

  /// フィルタ対象の service_id。
  final int serviceId;

  /// 188バイト境界に整列したTSパケット列 (ヘッダー付き)。
  final Stream<Uint8List> packets;

  /// EIT[p/f] の現在番組。未受信時は null。
  TvProgram? present;

  /// EIT[p/f] の次番組。未受信時は null。
  TvProgram? following;

  StreamSubscription<Uint8List>? _subscription;
  bool _disposed = false;

  /// いずれかを受信済みかどうか。
  bool get hasLive => present != null || following != null;

  /// 購読を開始する。多重呼び出しは無視する。
  void start() {
    if (_subscription != null) return;
    final assembler = TsSectionAssembler();
    final kept = BytesBuilder();
    _subscription = packets.listen(
      (batch) {
        if (_disposed) return;
        // 映像等のPESを含むフルTSが来るため、EIT (PID 0x12) だけ抜き出す。
        // 組み立て前に落とさないと、他PIDの断片が組み立てバッファに溜まる。
        kept.clear();
        for (var offset = 0; offset + 188 <= batch.length; offset += 188) {
          if (batch[offset] != 0x47) continue;
          final pid =
              ((batch[offset + 1] & 0x1F) << 8) | batch[offset + 2];
          if (pid != 0x12) continue;
          kept.add(batch.sublist(offset, offset + 188));
        }
        final filtered = kept.toBytes();
        if (filtered.isEmpty) return;
        for (final section in assembler.addPackets(filtered)) {
          if (section.pid != 0x12) continue;
          handleSection(section.section);
        }
      },
      onError: (_) {
        // 源の異常終了時は黙って止める (再試行は画面の再試行に任せる)。
      },
    );
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
    _subscription?.cancel();
    super.dispose();
  }
}
