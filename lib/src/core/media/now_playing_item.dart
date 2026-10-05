import 'package:audio_service/audio_service.dart';

/// ライブ視聴の [MediaItem] を組み立てる純粋関数。
///
/// [channelTitle] は上部ボタンバーと同じ `チャンネル番号 + 局名` の表示名。
/// 番組名が分かっているとき (EIT[p/f] 受信済み) はそれをタイトルにし、
/// チャンネル名はアーティストへ回す。アルバムアートはチャンネルロゴ。
MediaItem liveMediaItem({
  required String channelId,
  required String channelTitle,
  String? programTitle,
  Uri? artUri,
}) {
  return MediaItem(
    id: 'live:$channelId',
    title: programTitle ?? channelTitle,
    artist: programTitle == null ? null : channelTitle,
    artUri: artUri,
  );
}

/// 録画再生の [MediaItem] を組み立てる純粋関数。
///
/// アルバムアートは番組サムネイル。再生尺 ([duration]) は mpv から届き次第
/// 差し替えるため、取得前は null のままにする (推定値は入れない)。
MediaItem videoMediaItem({
  required int videoId,
  required String title,
  String? channelName,
  Uri? artUri,
  Duration? duration,
}) {
  return MediaItem(
    id: 'video:$videoId',
    title: title,
    artist: channelName,
    duration: duration,
    artUri: artUri,
  );
}

/// バックエンドが返すロゴ・サムネイルの URL 文字列を [MediaItem.artUri] 用に直す。
///
/// 未設定 (null・空文字) や不正な値は null にして、アート無しとして扱う。
/// mpris 側は `Uri.toString()` の `"null"` をそのまま artUrl に載せてしまうため、
/// ここで落とす (未設定＝項目自体を渡さない、が正しい)。
Uri? artUriOf(String? url) {
  if (url == null || url.isEmpty) return null;
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return null;
  return uri;
}
