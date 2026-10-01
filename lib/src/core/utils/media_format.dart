import 'time_format.dart';

// 録画ファイル情報の表示用整形ヘルパー。
//
// いずれも副作用のない純粋関数で、単体テストで検証する。
// 値が不明な項目は `―` を返す。

/// 不明値を表す表示。
const unknownMediaValue = '―';

/// ファイルサイズを人間可読形式にする (例: `8.4 GB` / `123 MB` / `100 B`)。
String formatFileSize(int bytes) {
  if (bytes < 0) return unknownMediaValue;
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var size = bytes.toDouble();
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  final text = size % 1 == 0
      ? size.toStringAsFixed(0)
      : size.toStringAsFixed(1);
  return '$text ${units[unit]}';
}

/// フレームレートを表示用にする (例: `29.97 fps` / `60 fps`)。
String formatFrameRate(double fps) {
  final text = fps.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  return '$text fps';
}

/// サンプリングレートを表示用にする (例: `48 kHz` / `44.1 kHz`)。
String formatSamplingRate(int hz) {
  if (hz < 0) return unknownMediaValue;
  if (hz < 1000) return '$hz Hz';
  final khz = hz / 1000;
  final text = khz % 1 == 0
      ? khz.toStringAsFixed(0)
      : khz.toStringAsFixed(1);
  return '$text kHz';
}

/// 解像度を表示用にする (例: `1920 × 1080`)。片方でも不明なら `―`。
String formatResolution(int? width, int? height) {
  if (width == null || height == null) return unknownMediaValue;
  return '$width × $height';
}

/// スキャン方式を日本語表示にする。未知の値はそのまま返す。
String formatScanType(String? scanType) {
  return switch (scanType) {
    null || '' => unknownMediaValue,
    'Interlaced' => 'インターレース',
    'Progressive' => 'プログレッシブ',
    final other => other,
  };
}

/// 音声チャンネルを日本語表示にする。未知の値はそのまま返す。
String formatAudioChannel(String? channel) {
  return switch (channel) {
    null || '' => unknownMediaValue,
    'Monaural' => 'モノラル',
    'Stereo' => 'ステレオ',
    final other => other,
  };
}

/// 録画期間を `開始 〜 終了` 形式にする。片欠けはある側だけ出す。
String formatRecordingPeriod(DateTime? start, DateTime? end) {
  if (start == null && end == null) return unknownMediaValue;
  if (start == null) return '〜 ${formatDateTimeJa(end!)}';
  if (end == null) return '${formatDateTimeJa(start)} 〜';
  return '${formatDateTimeJa(start)} 〜 ${formatDateTimeJa(end)}';
}

/// 日時を表示用にする。null のときは `―`。
String formatFileDateTime(DateTime? dateTime) {
  if (dateTime == null) return unknownMediaValue;
  return formatDateTimeJa(dateTime);
}

/// 文字列の表示用変換。空・null のときは `―`。
String formatMediaText(String? value) {
  if (value == null || value.isEmpty) return unknownMediaValue;
  return value;
}
