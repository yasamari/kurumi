/// NX-Jikkyo の接続先と WebSocket パスの組み立て。
///
/// NX-Jikkyo は Mirakurun / KonomiTV とは別のサーバーだが、接続先は公開の
/// 実況サーバーに固定する方針のためここでは変更しない。
library;

/// NX-Jikkyo のベースURL。
const nxJikkyoBaseUrl = 'https://nx-jikkyo.tsukumijima.net';

/// 実況チャンネルとしてサポートされていないチャンネルの案内文言。
///
/// 判定が2系統あるため文言を一元化している。
/// - クライアント側: 対応表 (`jikkyo_channel_map.dart`) に該当なし。
/// - サーバー側: 視聴セッションが close 1008 (`Invalid channel ID.`)。
///
/// クライアント側の判定を先に当てると、接続せず同じ文言を出せる。
const unsupportedChannelMessage = 'このチャンネルはニコニコ実況に対応していません';

/// 視聴セッション WebSocket のURL。
///
/// NX-Jikkyo は HTTP と WebSocket を同一ポートで待ち受けている。
/// `startWatching` を送ると `room` (スレッドIDなど) が返る。
Uri jikkyoWatchUri(String channelId, {String baseUrl = nxJikkyoBaseUrl}) =>
    _wsUri(baseUrl, '/api/v1/channels/$channelId/ws/watch');

/// コメントセッション WebSocket のURL。
///
/// 実況コメント (および過去ログ) が流れる。`thread` コマンドを送ると購読が
/// 始まり、以後は `chat` メッセージが push される。
Uri jikkyoCommentUri(String channelId, {String baseUrl = nxJikkyoBaseUrl}) =>
    _wsUri(baseUrl, '/api/v1/channels/$channelId/ws/comment');

/// ベースURLを WebSocket スキームに変換し、パスを付け足す。
///
/// `https`/`wss` は `wss` に、それ以外 (既定で `http`) は `ws` に読み替える。
Uri _wsUri(String baseUrl, String path) {
  final scheme = switch (Uri.parse(baseUrl).scheme) {
    'https' || 'wss' => 'wss',
    _ => 'ws',
  };
  final prefix = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
  return Uri.parse('$prefix$path').replace(scheme: scheme);
}
