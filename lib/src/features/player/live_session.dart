import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:media_kit/media_kit.dart';

import '../../data/backends/konomi/konomi_ts_packets.dart';
import '../../data/ts/stream_tap_session.dart';
import 'mpv_stream_tap.dart';

/// ライブ再生の単位。mpvが開くURLとEIT取得用のTSパケット列を持つ。
///
/// - KonomiTV: mpegtsを直接開き、PSIアーカイブAPIからパケットを得る
/// - Mirakurun等: stream tap (`kurumi-ts://`) を開き、
///   再生中TSから直接EITを抜く (Linux/Android/Windows)
/// いずれもチューナー消費は1のまま。使い終わったら [close] で閉じる。
/// tap 未対応OS (macOS/iOS) の Mirakurun等は [UnsupportedError] で
/// セッション開設に失敗し、再試行表示になる。
class LiveSession {
  const LiveSession({
    required this.playUrl,
    required this.packets,
    required this.close,
  });

  /// mpvが開くURL。
  final Uri playUrl;

  /// 188バイト境界のTSパケット列 (EIT取得用)。
  final Stream<Uint8List> packets;

  /// 上流を閉じる。
  final Future<void> Function() close;
}

/// ライブセッションを開く関数。登録に使う [Player] を渡す。
typedef LiveSessionFactory = Future<LiveSession> Function(Player player);

/// KonomiTV用のセッションを作る。mpegtsは直接開く。
LiveSession buildKonomiLiveSession({
  required Dio dio,
  required String displayChannelId,
  required String quality,
  required Uri mpegtsUrl,
}) {
  final source = KonomiTsPackets(
    dio: dio,
    displayChannelId: displayChannelId,
    quality: quality,
  );
  return LiveSession(
    playUrl: mpegtsUrl,
    packets: source.stream,
    close: () async {
      source.close();
    },
  );
}

/// stream tap 用のセッションを開く。ポンプ起動とプロトコル登録まで待つ。
Future<LiveSession> startStreamTapLiveSession({
  required Uri upstreamUrl,
  required Player player,
}) async {
  final session = await StreamTapSession.start(upstreamUrl: upstreamUrl);
  try {
    await registerStreamTapProtocol(
      player,
      openFunctionAddress: session.openFunctionAddress!,
    );
  } catch (_) {
    await session.close();
    rethrow;
  }
  return LiveSession(
    playUrl: session.url!,
    packets: session.tsPackets,
    close: session.close,
  );
}
