import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;
import 'package:media_kit/media_kit.dart';

/// キャプチャ画像のギャラリー保存先アルバム名。
const captureGalleryAlbum = 'kurumi';

/// EXIF のソフトウェア名。
const captureSoftwareName = 'kurumi';

/// キャプチャ画像の JPEG 品質。KonomiTV の `CaptureCompositor` と同じ 99。
const captureJpegQuality = 99;

/// キャプチャタブに保持する最大件数。超過分は古いものから破棄する。
const captureMaxEntries = 20;

/// キャプチャタブに保持する1件分の画像と情報。
///
/// ギャラリー保存済みの JPEG バイト列をメモリに保持する。画面
/// (`_WatchLayoutState` / `_VideoPlayerState`) を離れたら破棄される
/// (セッション内のみ保持)。
@immutable
class CaptureEntry {
  const CaptureEntry({
    required this.id,
    required this.jpegBytes,
    required this.capturedAt,
    required this.title,
    required this.isDanmaku,
  });

  /// 一覧内での一意識別子。撮影時刻のマイクロ秒。
  final String id;

  /// EXIF 付き JPEG バイト列。
  final Uint8List jpegBytes;

  /// 撮影時刻。
  final DateTime capturedAt;

  /// 撮影時の番組名・チャンネル名。
  final String title;

  /// 弾幕を合成したかどうか。
  final bool isDanmaku;
}

/// キャプチャ時の番組情報のスナップショット。
///
/// ボタン押下の瞬間の値を切り出して保持する。合成・保存は非同期のため、
/// 実行中に EIT や再生位置が変わっても撮影時の値を使う。
@immutable
class CaptureMetadata {
  const CaptureMetadata({
    required this.capturedAt,
    required this.playbackPositionSec,
    required this.networkId,
    required this.serviceId,
    required this.eventId,
    required this.title,
    required this.description,
    required this.startAt,
    required this.endAt,
    required this.durationSec,
    required this.isCaptionComposited,
  });

  /// 撮影時刻。
  final DateTime capturedAt;

  /// 番組開始時刻から換算したキャプチャ位置 (秒)。
  final double playbackPositionSec;

  /// チャンネルの network_id。録画で不明のときは 0。
  final int networkId;

  /// チャンネルの service_id。録画で不明のときは 0。
  final int serviceId;

  /// 番組の event_id。ライブで EIT 未受信のときは 0。
  final int eventId;

  /// 番組名。ライブで EIT 未受信のときはチャンネル名。
  final String title;

  /// 番組概要。なければ空。
  final String description;

  /// 番組開始時刻。EIT 未受信のときは撮影時刻。
  final DateTime startAt;

  /// 番組終了時刻。EIT 未受信のときは撮影時刻。
  final DateTime endAt;

  /// 番組長 (秒)。EIT 未受信のときは 0。
  final int durationSec;

  /// キャプチャに字幕が合成されているかどうか。撮影時の字幕表示設定。
  final bool isCaptionComposited;
}

/// ギャラリー保存時のファイル名 (拡張子なし) を作る。
///
/// `kurumi_20250101_123045` 形式。`Gal.putImageBytes` の `name` に渡す。
String captureFileName(DateTime at) {
  String two(int value) => value.toString().padLeft(2, '0');
  return 'kurumi_${at.year}${two(at.month)}${two(at.day)}_'
      '${two(at.hour)}${two(at.minute)}${two(at.second)}';
}

/// EXIF の撮影時刻文字列 (`YYYY:MM:DD HH:mm:ss`) を作る。
///
/// コロン区切りがポイント (KonomiTV の `CaptureCompositor` と同じ)。
String captureExifDateTime(DateTime at) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${at.year}:${two(at.month)}:${two(at.day)} '
      '${two(at.hour)}:${two(at.minute)}:${two(at.second)}';
}

/// 文字列を UTF-16LE バイト列に変換する。
///
/// EXIF の XPComment は UCS2 (UTF-16LE) で格納する (KonomiTV の
/// `Buffer.from(json, 'ucs2')` と同等)。
Uint8List utf16LeBytes(String value) {
  final units = value.codeUnits;
  final bytes = Uint8List(units.length * 2);
  final data = ByteData.sublistView(bytes);
  for (var i = 0; i < units.length; i++) {
    data.setUint16(i * 2, units[i], Endian.little);
  }
  return bytes;
}

/// XPComment 用の EXIF メタデータ JSON を作る。
///
/// キーは KonomiTV の `ICaptureExifData` と同じ snake_case にする (互換目的)。
/// `caption_text` は mpv 内字幕のテキスト抽出手段がないため常に null。
Map<String, Object?> buildCaptureExifJson({
  required CaptureMetadata metadata,
  required bool isCommentComposited,
}) {
  return {
    'captured_at': metadata.capturedAt.toIso8601String(),
    'captured_playback_position': metadata.playbackPositionSec,
    'network_id': metadata.networkId,
    'service_id': metadata.serviceId,
    'event_id': metadata.eventId,
    'title': metadata.title,
    'description': metadata.description,
    'start_time': metadata.startAt.toIso8601String(),
    'end_time': metadata.endAt.toIso8601String(),
    'duration': metadata.durationSec,
    'caption_text': null,
    'is_caption_composited': metadata.isCaptionComposited,
    'is_comment_composited': isCommentComposited,
  };
}

/// KonomiTV の `CaptureCompositor` と同じ EXIF を組み立てる。
///
/// - 0th: 解像度・撮影時刻・ソフトウェア名・XPComment (番組情報 JSON)。
/// - Exif: バージョン・色空間・撮影時刻。
img.ExifData buildCaptureExif({
  required Map<String, Object?> json,
  required String software,
  required String dateTime,
}) {
  final exif = img.ExifData();
  final imageIfd = exif.imageIfd;
  imageIfd['XResolution'] = [72, 1];
  imageIfd['YResolution'] = [72, 1];
  imageIfd['ResolutionUnit'] = 2;
  imageIfd['YCbCrPositioning'] = 1;
  imageIfd['DateTime'] = dateTime;
  imageIfd['Software'] = software;
  // `XPComment` の型は未定義のため、`IfdValue` を直接入れる
  // (文字列代入では型解決できず格納されない)。
  imageIfd['XPComment'] = img.IfdValueUndefined.list(
    utf16LeBytes(jsonEncode(json)),
  );
  final exifIfd = exif.exifIfd;
  exifIfd['ExifVersion'] = [48, 50, 51, 48];
  exifIfd['ComponentsConfiguration'] = [1, 2, 3, 0];
  exifIfd['FlashpixVersion'] = [48, 49, 48, 48];
  exifIfd['ColorSpace'] = 1;
  exifIfd['DateTimeOriginal'] = dateTime;
  exifIfd['DateTimeDigitized'] = dateTime;
  return exif;
}

/// PNG バイト列の大きさを読む。デコードせず IHDR だけ見る。
///
/// mpv 撮像の解像度を知るために使う (UI isolate での全デコードを避ける)。
({int width, int height})? pngSize(Uint8List bytes) {
  if (bytes.length < 24) return null;
  const signature = [137, 80, 78, 71, 13, 10, 26, 10];
  for (var i = 0; i < 8; i++) {
    if (bytes[i] != signature[i]) return null;
  }
  // シグネチャ直後の長さ (4B) + 種別 (4B) が `IHDR` のものだけ読む。
  if (bytes[12] != 73 ||
      bytes[13] != 72 ||
      bytes[14] != 68 ||
      bytes[15] != 82) {
    return null;
  }
  final data = ByteData.sublistView(bytes);
  final width = data.getUint32(16, Endian.big);
  final height = data.getUint32(20, Endian.big);
  if (width == 0 || height == 0) return null;
  return (width: width, height: height);
}

/// 弾幕撮像の pixelRatio。mpv 撮像と等倍になる倍率。
///
/// 上限 4.0 はメモリ ($3840\times2160\times4$ で約 33MB) の上限。
double captureOverlayPixelRatio({
  required int baseWidth,
  required double boundaryWidth,
}) {
  if (boundaryWidth <= 0) return 1.0;
  return (baseWidth / boundaryWidth).clamp(1.0, 4.0);
}

/// 弾幕画像を mpv 撮像へ収める矩形。アスペクトを保って中央に置く。
///
/// mpv 撮像は符号化サイズ (1440x1080 など) の場合があり、表示矩形 (16:9)
/// と比が違うことがある。引き伸ばし合成すると弾幕が歪むため、収まる側に
/// 合わせて中央に置く (一致していれば等倍のまま)。
({int dstX, int dstY, int dstW, int dstH}) captureOverlayFit({
  required int baseWidth,
  required int baseHeight,
  required int overlayWidth,
  required int overlayHeight,
}) {
  if (overlayWidth <= 0 || overlayHeight <= 0) {
    return (dstX: 0, dstY: 0, dstW: baseWidth, dstH: baseHeight);
  }
  final scale = math.min(baseWidth / overlayWidth, baseHeight / overlayHeight);
  final dstW = (overlayWidth * scale).round();
  final dstH = (overlayHeight * scale).round();
  return (
    dstX: ((baseWidth - dstW) ~/ 2),
    dstY: ((baseHeight - dstH) ~/ 2),
    dstW: dstW,
    dstH: dstH,
  );
}

/// `compute` に渡す合成引数。すべて isolate 間で送れる値だけを持つ。
@immutable
class CaptureComposeArgs {
  const CaptureComposeArgs({
    required this.baseBytes,
    this.overlayRgbaBytes,
    this.overlayWidth,
    this.overlayHeight,
    required this.exifJson,
    required this.software,
    required this.dateTime,
  });

  /// mpv の撮像 (PNG)。
  final Uint8List baseBytes;

  /// 弾幕レイヤーの撮像 (未加工 RGBA)。通常キャプチャでは null。
  /// [overlayWidth]・[overlayHeight] と組で使う。
  final Uint8List? overlayRgbaBytes;

  /// 弾幕撮像の幅・高さ。RGBA バイト列の解釈に使う。
  final int? overlayWidth;
  final int? overlayHeight;

  /// XPComment に格納する番組情報 JSON。
  final Map<String, Object?> exifJson;

  /// EXIF のソフトウェア名。
  final String software;

  /// EXIF の撮影時刻文字列。
  final String dateTime;
}

/// mpv 撮像に弾幕を合成し、EXIF を付けて JPEG 化する。
///
/// `compute` で実行するトップレベル関数。UI isolate を止めない。
Uint8List composeCaptureBytes(CaptureComposeArgs args) {
  final base = img.decodeImage(args.baseBytes);
  if (base == null) {
    throw StateError('キャプチャ画像を読み取れません');
  }
  final overlayRgbaBytes = args.overlayRgbaBytes;
  final overlayWidth = args.overlayWidth;
  final overlayHeight = args.overlayHeight;
  if (overlayRgbaBytes != null &&
      overlayWidth != null &&
      overlayHeight != null &&
      overlayWidth > 0 &&
      overlayHeight > 0 &&
      overlayRgbaBytes.lengthInBytes >= overlayWidth * overlayHeight * 4) {
    final overlay = img.Image.fromBytes(
      width: overlayWidth,
      height: overlayHeight,
      bytes: overlayRgbaBytes.buffer,
      bytesOffset: overlayRgbaBytes.offsetInBytes,
      // Flutter の `rawStraightRgba` (straight alpha) と同じ。
      numChannels: 4,
    );
    // 比が違うときの引き伸ばしを避け、アスペクトを保って中央に置く
    // (一致していれば等倍のまま)。
    final fit = captureOverlayFit(
      baseWidth: base.width,
      baseHeight: base.height,
      overlayWidth: overlay.width,
      overlayHeight: overlay.height,
    );
    // nearest 伸縮で文字がジャギるのを避けるため、fit サイズへ線形補間で
    // 先にリサイズしてから 1:1 で合成する (ゼロ遅延を保つため DPR の
    // 引き上げはしない)。
    final resizedOverlay =
        (overlay.width == fit.dstW && overlay.height == fit.dstH)
        ? overlay
        : img.copyResize(
            overlay,
            width: fit.dstW,
            height: fit.dstH,
            interpolation: img.Interpolation.linear,
          );
    img.compositeImage(base, resizedOverlay, dstX: fit.dstX, dstY: fit.dstY);
  }
  base.exif = buildCaptureExif(
    json: args.exifJson,
    software: args.software,
    dateTime: args.dateTime,
  );
  return img.encodeJpg(base, quality: captureJpegQuality);
}

/// mpv の現在フレームを撮像する。
///
/// `player.screenshot()` は内部で `screenshot-raw` を同期実行する。mpv の
/// コアが色変換まで行うため、その間の処理が再生を詰まらせる。`screenshot-to-file`
/// は mpv の worker command を使い、色変換とファイル書込をコアのロック外で
/// 行うので、再生を止める時間を短くできる。
///
/// 字幕入りで取る (`subtitles`)。mpv の `s` キー相当で、ARIB ビットマップ
/// 字幕も含まれる。PNG 拡張子で撮像し、既存の合成処理へ渡す。
/// `NativePlayer.command` は既定の非同期 libmpv API を使うため、完了待ちでも
/// UI isolate はブロックしない。
Future<Uint8List?> takePlayerScreenshot(Player player) async {
  final platform = player.platform;
  if (platform is! NativePlayer) return null;

  final directory = await Directory.systemTemp.createTemp(
    'kurumi-player-capture-',
  );
  final file = File('${directory.path}/frame.png');
  try {
    if (Platform.isAndroid) {
      // Android の gpu VO で既定の撮像を行うと、撮像時に renderer の再初期化が
      // 入り再生が中断されることがある。ソフトウェア変換を別スレッドで行わせる。
      await platform.setProperty('screenshot-sw', 'yes');
    }
    await platform.command([
      'screenshot-to-file',
      file.path,
      'subtitles',
    ]);
    if (!await file.exists()) return null;
    return await file.readAsBytes();
  } finally {
    try {
      await directory.delete(recursive: true);
    } catch (_) {
      // 一時ファイルの後片付け失敗はキャプチャ結果に影響させない。
    }
  }
}

/// 撮像に使う弾幕境界のキーを選ぶ。
///
/// 通常表示とフルスクリーンで撮像境界のキーを分けている
/// (`JikkyoDanmakuLayer`) ため、フルスクリーン側が組まれている間はそちらを
/// 優先する。どちらも無ければ null。
GlobalKey? activeDanmakuBoundaryKey(
  GlobalKey? boundaryKey,
  GlobalKey? fullscreenBoundaryKey,
) {
  final fullscreen = fullscreenBoundaryKey;
  if (fullscreen?.currentContext != null) return fullscreen;
  return boundaryKey;
}

/// 弾幕レイヤーの `RepaintBoundary` の論理サイズを返す。
///
/// 境界が無いときは null。
Size? danmakuBoundarySize(GlobalKey key) {
  final boundary = key.currentContext?.findRenderObject();
  if (boundary is! RenderRepaintBoundary) return null;
  final size = boundary.size;
  if (size.isEmpty) return null;
  return size;
}

/// 弾幕レイヤーの `RepaintBoundary` を未加工 RGBA で撮像する。
///
/// PNG には符号化しない。`toByteData(format: png)` の符号化はラスタースレッドで
/// 走り、その間は映像テクスチャの更新も止まるため、動画が一瞬止まり、ライブ視聴
/// では遅延がそのまま増える。生の RGBA なら GPU からの読み戻しと memcpy だけで
/// 済み、重い合成・JPEG 化は `compute` (別 isolate) が担う。
/// [pixelRatio] は mpv 撮像と等倍になる倍率 ([captureOverlayPixelRatio])。
/// 境界が無い・撮像できないときは null。通常キャプチャとして保存する。
Future<({Uint8List bytes, int width, int height})?> captureDanmakuOverlay(
  GlobalKey key, {
  double pixelRatio = 1.0,
}) async {
  final boundary = key.currentContext?.findRenderObject();
  if (boundary is! RenderRepaintBoundary) return null;
  if (boundary.size.isEmpty) return null;
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  try {
    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    if (byteData == null) return null;
    return (
      bytes: byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      ),
      width: image.width,
      height: image.height,
    );
  } finally {
    image.dispose();
  }
}

/// ギャラリー保存の失敗内容。表示用メッセージだけを持つ。
class CaptureSaveFailure implements Exception {
  const CaptureSaveFailure(this.message);

  /// SnackBar に出す日本語メッセージ。
  final String message;
}

/// JPEG バイト列をギャラリーに保存する。成功時は通知しない。
///
/// ファイルパス指定の `putImage` を使う。メモリ指定の `putImageBytes` は
/// Linux 実装 (`gal_linux`) が拡張子を `.png` 固定にするため、JPEG が
/// `.png` 名で保存されてしまう。テンポラリの `.jpg` 経由なら全
/// プラットフォームで正しい拡張子になる。テンポラリ名は一意にする
/// (同一秒の連写で衝突しないよう)。
Future<void> saveCaptureToGallery(
  Uint8List jpegBytes, {
  required String name,
}) async {
  final file = File(
    '${Directory.systemTemp.path}/$name-'
    '${DateTime.now().microsecondsSinceEpoch}.jpg',
  );
  try {
    await file.writeAsBytes(jpegBytes, flush: true);
    await Gal.putImage(file.path, album: captureGalleryAlbum);
  } on GalException catch (error) {
    throw CaptureSaveFailure(switch (error.type) {
      GalExceptionType.accessDenied => 'ギャラリーへのアクセスが許可されていません',
      GalExceptionType.notEnoughSpace => '空き容量が不足しています',
      _ => 'キャプチャの保存に失敗しました',
    });
  } finally {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // 後片付けの失敗は無視する (保存結果に影響しない)。
    }
  }
}

/// キャプチャ1回分の実行。撮像→合成→保存→タブ追加まで行う。
///
/// 成功時は通知しない。失敗時だけ SnackBar を出す。`onCaptured` で
/// キャプチャタブの一覧へ追加する (上限を超えた分は古いものから破棄する)。
///
/// 弾幕付きのときは mpv 撮像と等倍の解像度で弾幕を撮像するが、表示解像度の
/// 引き上げはしない。引き上げるとエンジンが画像キャッシュを落として描き直す
/// うえ、撮像の符号化がラスタースレッドを塞ぎ、その間は映像テクスチャの更新も
/// 止まる (ライブ視聴では止まった分だけ遅延が増える)。DPR=1 の環境では文字が
/// ややぼやけるが、引き伸ばし合成で吸収する。
Future<void> runPlayerCapture({
  required BuildContext context,
  required Player player,
  required bool withDanmaku,
  GlobalKey? danmakuBoundaryKey,
  GlobalKey? fullscreenDanmakuBoundaryKey,
  required bool danmakuVisible,
  required CaptureMetadata metadata,
  required ValueChanged<CaptureEntry> onCaptured,
}) async {
  void notifyFailure(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Uint8List? base;
  try {
    base = await takePlayerScreenshot(player);
  } catch (_) {
    base = null;
  }
  if (base == null) {
    notifyFailure('キャプチャに失敗しました');
    return;
  }

  // 弾幕の撮像は表示中のときだけ試みる。撮れなければ通常保存する
  // (通知はしない)。そのままの DPR で1回だけ撮り、描き直し待ちはしない
  // (上記コメント参照)。
  ({Uint8List bytes, int width, int height})? overlay;
  final boundaryKey = activeDanmakuBoundaryKey(
    danmakuBoundaryKey,
    fullscreenDanmakuBoundaryKey,
  );
  if (withDanmaku && danmakuVisible && boundaryKey != null) {
    try {
      var pixelRatio = 1.0;
      final boundarySize = danmakuBoundarySize(boundaryKey);
      final baseSize = pngSize(base);
      if (boundarySize != null && baseSize != null) {
        pixelRatio = captureOverlayPixelRatio(
          baseWidth: baseSize.width,
          boundaryWidth: boundarySize.width,
        );
      }
      if (context.mounted) {
        overlay = await captureDanmakuOverlay(
          boundaryKey,
          pixelRatio: pixelRatio,
        );
      }
    } catch (_) {
      overlay = null;
    }
  }

  final isCommentComposited = overlay != null;
  late final Uint8List jpegBytes;
  try {
    jpegBytes = await compute(
      composeCaptureBytes,
      CaptureComposeArgs(
        baseBytes: base,
        overlayRgbaBytes: overlay?.bytes,
        overlayWidth: overlay?.width,
        overlayHeight: overlay?.height,
        exifJson: buildCaptureExifJson(
          metadata: metadata,
          isCommentComposited: isCommentComposited,
        ),
        software: captureSoftwareName,
        dateTime: captureExifDateTime(metadata.capturedAt),
      ),
    );
  } catch (_) {
    notifyFailure('キャプチャに失敗しました');
    return;
  }

  try {
    await saveCaptureToGallery(
      jpegBytes,
      name: captureFileName(metadata.capturedAt),
    );
  } on CaptureSaveFailure catch (error) {
    notifyFailure(error.message);
    return;
  }
  onCaptured(
    CaptureEntry(
      id: '${metadata.capturedAt.microsecondsSinceEpoch}',
      jpegBytes: jpegBytes,
      capturedAt: metadata.capturedAt,
      title: metadata.title,
      isDanmaku: isCommentComposited,
    ),
  );
}

/// キャプチャタブの一覧へ1件追加する。上限を超えた分は古いものから破棄する。
List<CaptureEntry> appendCaptureEntry(
  List<CaptureEntry> entries,
  CaptureEntry entry,
) {
  final next = [...entries, entry];
  if (next.length <= captureMaxEntries) return next;
  return next.sublist(next.length - captureMaxEntries);
}
