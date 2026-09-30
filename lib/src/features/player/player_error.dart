/// プレイヤーのエラー表示判定と `video-params` の読み取り (pure 関数群)。
///
/// media_kit の `Player.stream.error` は mpv のログレベル `error` をそのまま
/// 流す。`vd`/`ad` (デコーダ) 由来の一過性エラー (「Could not open codec」、
/// 「Error decoding audio.」など) は再生が継続・回復する場合でも送られてくる。
/// 受信のたびにエラー表示すると、再生できているのに画面が覆われてしまうため、
/// 再生状態 (`playing` + 映像/音声パラメータ) と組み合わせて判定する。
///
/// `videoDisplayAspectOf` はエラー判定ではなく弾幕の配置で使うが、同じ
/// `video-params` を読み取るのでこのファイルに置いてある。
library;

/// `error` 受信後に表示を確定するまでの猶予時間。
///
/// 起動直後はフォールバック前のデコーダ失敗 (`Could not open codec` など) が
/// 先に届き、直後に正常なデコーダで再生が始まることがある。その回復を待つ
/// ための待ち時間。猶予内に回復しなければエラー表示する。
const playerErrorGracePeriod = Duration(seconds: 3);

/// 実際に再生できている (回復済み) かを判定する。
///
/// 映像または音声のパラメータが届き、かつ `playing` が真の場合に真を返す。
/// テレビ放送は映像・音声の両方を持つが、音声のみのストリームでも誤表示
/// しないよう、どちらか一方があれば回復済みとみなす。
bool isPlayerRecovered({
  required bool isPlaying,
  required bool hasVideo,
  required bool hasAudio,
}) {
  return isPlaying && (hasVideo || hasAudio);
}

/// mpv の `video-params` が有効な映像サイズを持つかを判定する。
///
/// `dw`/`dh` (表示サイズ) を優先し、無ければ `w`/`h` を見る。
bool hasValidVideoSize({int? dw, int? dh, int? w, int? h}) {
  return (dw ?? w ?? 0) > 0 && (dh ?? h ?? 0) > 0;
}

double? videoDisplayAspectOf({
  double? aspect,
  int? w,
  int? h,
  int? dw,
  int? dh,
}) {
  // mpv が持つ表示アスペクト比がもっとも正確。
  final reported = aspect ?? 0;
  if (reported > 0 && reported.isFinite) return reported;
  // アスペクト補正済みの表示サイズ。
  final width = dw ?? 0;
  final height = dh ?? 0;
  if (width > 0 && height > 0) return width / height;
  // 符号化サイズ (補正なし)。最後の望み而已。
  final codedWidth = w ?? 0;
  final codedHeight = h ?? 0;
  if (codedWidth > 0 && codedHeight > 0) return codedWidth / codedHeight;
  return null;
}

/// mpv の `audio-params` が有効な音声形式を持つかを判定する。
bool hasValidAudioFormat({int? sampleRate, int? channelCount}) {
  return (sampleRate ?? 0) > 0 || (channelCount ?? 0) > 0;
}
