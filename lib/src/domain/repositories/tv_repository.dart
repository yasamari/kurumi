import '../entities/channel.dart';
import '../entities/channel_item.dart';
import '../entities/live_stream.dart';

/// サーバー未設定時に送出する例外。UI側で設定誘導表示に使う。
class BackendUnconfiguredException implements Exception {
  const BackendUnconfiguredException();
}

/// バックエンド非依存のテレビ操作インターフェース。
///
/// 新しいバックエンド (EDCB等) を追加する場合はこのクラスを実装し、
/// `tvRepositoryProvider` の factory に1行追加する。あわせて
/// `BackendType` の能力 getter (`supportsVideos` 等) の switch にも
/// 1行ずつ追加する (網羅 switch のため書き忘れはコンパイルエラーになる)。
abstract class TvRepository {
  /// 放送中チャンネル一覧を返す。次番組も可能な範囲で含める。
  Future<List<ChannelItem>> getNowOnAirChannels();

  /// 接続テスト。成功時は正常終了、失敗時は [Exception] を送出する。
  Future<void> testConnection();

  /// ライブ視聴用のストリーム情報を返す。
  ///
  /// [quality] はKonomiTVの画質指定 (例: `original`)。Mirakurunでは無視され、
  /// `decode=1` 固定のストリームを返す。未設定時は [BackendUnconfiguredException]。
  Future<LiveStream> getLiveStream(Channel channel, {String quality = 'original'});

  /// ライブ視聴で選択可能な画質一覧。
  ///
  /// Mirakurunでは画質選択をサポートしないため空リストを返す。
  /// KonomiTVでは `original` + 16種の再エンコード画質を返す。
  List<String> getLiveQualities();

  /// ライブ視聴の既定画質。
  String getDefaultLiveQuality();

  /// 画質を正規化する。不正値は既定画質にフォールバックする。
  String normalizeLiveQuality(String quality);

  /// 再エンコード無しの画質 (生放送TS) かを判定する。
  ///
  /// `original` はインターレース放送のMPEG-2 TS直接出力のため、mpv側で
  /// デインタレースする。トランスコード済み画質はプログレッシブのため不要。
  bool isOriginalLiveQuality(String quality);
}
