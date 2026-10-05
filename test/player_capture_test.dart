import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kurumi/src/features/player/player_capture.dart';

CaptureMetadata _metadata() {
  return CaptureMetadata(
    capturedAt: DateTime(2025, 1, 2, 3, 4, 5),
    playbackPositionSec: 61.5,
    networkId: 1,
    serviceId: 2,
    eventId: 3,
    title: '番組名',
    description: '概要',
    startAt: DateTime(2025, 1, 2, 3, 0, 0),
    endAt: DateTime(2025, 1, 2, 4, 0, 0),
    durationSec: 3600,
    isCaptionComposited: true,
  );
}

/// UTF-16LE バイト列を文字列に戻す。
String _decodeUtf16Le(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final units = List<int>.generate(
    bytes.length ~/ 2,
    (i) => data.getUint16(i * 2, Endian.little),
  );
  return String.fromCharCodes(units);
}

void main() {
  group('captureFileName', () {
    test('kurumi_YYYYMMDD_HHMMSS 形式になる', () {
      expect(
        captureFileName(DateTime(2025, 1, 2, 3, 4, 5)),
        'kurumi_20250102_030405',
      );
    });
  });

  group('captureExifDateTime', () {
    test('YYYY:MM:DD HH:mm:ss 形式になる', () {
      expect(
        captureExifDateTime(DateTime(2025, 1, 2, 3, 4, 5)),
        '2025:01:02 03:04:05',
      );
    });
  });

  group('utf16LeBytes', () {
    test('UTF-16LE で往復できる', () {
      const value = '番組名 ABC 123';
      expect(_decodeUtf16Le(utf16LeBytes(value)), value);
    });
  });

  group('buildCaptureExifJson', () {
    test('KonomiTV と同じキーを持つ', () {
      final json = buildCaptureExifJson(
        metadata: _metadata(),
        isCommentComposited: true,
      );
      expect(json.keys.toSet(), {
        'captured_at',
        'captured_playback_position',
        'network_id',
        'service_id',
        'event_id',
        'title',
        'description',
        'start_time',
        'end_time',
        'duration',
        'caption_text',
        'is_caption_composited',
        'is_comment_composited',
      });
      expect(json['caption_text'], isNull);
      expect(json['is_caption_composited'], isTrue);
      expect(json['is_comment_composited'], isTrue);
      expect(json['title'], '番組名');
    });
  });

  group('buildCaptureExif', () {
    test('XPComment に番組情報 JSON が入る', () {
      final json = buildCaptureExifJson(
        metadata: _metadata(),
        isCommentComposited: false,
      );
      final exif = buildCaptureExif(
        json: json,
        software: captureSoftwareName,
        dateTime: '2025:01:02 03:04:05',
      );
      expect(exif.imageIfd['DateTime'].toString(), contains('2025:01:02'));
      expect(
        exif.imageIfd['Software'].toString(),
        contains(captureSoftwareName),
      );
      final comment = exif.getTag(0x9c9c);
      expect(comment, isNotNull);
      final decoded =
          jsonDecode(_decodeUtf16Le(comment!.toData()))
              as Map<String, dynamic>;
      expect(decoded['title'], '番組名');
      expect(decoded['is_comment_composited'], isFalse);
      expect(exif.exifIfd['DateTimeOriginal'].toString(), contains('2025'));
    });
  });

  group('composeCaptureBytes', () {
    img.Image solid(int width, int height, int r, int g, int b) {
      final image = img.Image(width: width, height: height);
      img.fill(image, color: img.ColorRgb8(r, g, b));
      return image;
    }

    test('通常キャプチャは JPEG で同じ大きさになる', () {
      final base = img.encodePng(solid(64, 36, 10, 20, 30));
      final out = composeCaptureBytes(
        CaptureComposeArgs(
          baseBytes: base,
          exifJson: buildCaptureExifJson(
            metadata: _metadata(),
            isCommentComposited: false,
          ),
          software: captureSoftwareName,
          dateTime: '2025:01:02 03:04:05',
        ),
      );
      // JPEG マジックバイト。
      expect(out[0], 0xFF);
      expect(out[1], 0xD8);
      final decoded = img.decodeImage(out)!;
      expect(decoded.width, 64);
      expect(decoded.height, 36);
      expect(decoded.exif.imageIfd['Software'].toString(), contains('kurumi'));
    });

    test('弾幕レイヤーは base の解像度に合わせて合成される', () {
      final base = img.encodePng(solid(64, 36, 10, 20, 30));
      final overlay = img.encodePng(solid(16, 9, 200, 10, 10));
      final out = composeCaptureBytes(
        CaptureComposeArgs(
          baseBytes: base,
          overlayBytes: overlay,
          exifJson: buildCaptureExifJson(
            metadata: _metadata(),
            isCommentComposited: true,
          ),
          software: captureSoftwareName,
          dateTime: '2025:01:02 03:04:05',
        ),
      );
      final decoded = img.decodeImage(out)!;
      expect(decoded.width, 64);
      expect(decoded.height, 36);
      final comment = decoded.exif.getTag(0x9c9c)!;
      final decodedJson =
          jsonDecode(_decodeUtf16Le(comment.toData()))
              as Map<String, dynamic>;
      expect(decodedJson['is_comment_composited'], isTrue);
    });
  });

  group('pngSize', () {
    Uint8List solidPng(int width, int height) {
      final image = img.Image(width: width, height: height);
      img.fill(image, color: img.ColorRgb8(10, 20, 30));
      return img.encodePng(image);
    }

    test('デコードせず大きさが読める', () {
      expect(pngSize(solidPng(64, 36)), (width: 64, height: 36));
    });

    test('PNG 以外・壊れた入力は null', () {
      expect(pngSize(Uint8List(0)), isNull);
      expect(pngSize(Uint8List.fromList([1, 2, 3])), isNull);
      expect(
        pngSize(Uint8List.fromList(List.filled(32, 0))),
        isNull,
      );
    });
  });

  group('captureOverlayPixelRatio', () {
    test('mpv 撮像と等倍になる倍率を返す', () {
      expect(
        captureOverlayPixelRatio(baseWidth: 1920, boundaryWidth: 960),
        2.0,
      );
    });

    test('下限は 1.0、上限は 4.0', () {
      expect(
        captureOverlayPixelRatio(baseWidth: 640, boundaryWidth: 960),
        1.0,
      );
      expect(
        captureOverlayPixelRatio(baseWidth: 3840, boundaryWidth: 640),
        4.0,
      );
      expect(
        captureOverlayPixelRatio(baseWidth: 1920, boundaryWidth: 0),
        1.0,
      );
    });
  });

  group('captureOverlayFit', () {
    test('比が一致すれば等倍のまま', () {
      expect(
        captureOverlayFit(
          baseWidth: 1920,
          baseHeight: 1080,
          overlayWidth: 1920,
          overlayHeight: 1080,
        ),
        (dstX: 0, dstY: 0, dstW: 1920, dstH: 1080),
      );
    });

    test('比が違うときは歪めず中央に置く', () {
      // 16:9 の弾幕を 4:3 (1440x1080) の撮像へ: 幅に合わせて上下に余白。
      final fit = captureOverlayFit(
        baseWidth: 1440,
        baseHeight: 1080,
        overlayWidth: 1920,
        overlayHeight: 1080,
      );
      expect(fit, (dstX: 0, dstY: 135, dstW: 1440, dstH: 810));
    });

    test('小さな弾幕は引き伸ばさず等倍以下で収める', () {
      final fit = captureOverlayFit(
        baseWidth: 1920,
        baseHeight: 1080,
        overlayWidth: 960,
        overlayHeight: 540,
      );
      expect(fit, (dstX: 0, dstY: 0, dstW: 1920, dstH: 1080));
    });
  });

  group('appendCaptureEntry', () {
    CaptureEntry entry(int id) {
      return CaptureEntry(
        id: '$id',
        jpegBytes: Uint8List(0),
        capturedAt: DateTime(2025, 1, 2).add(Duration(seconds: id)),
        title: '番組',
        isDanmaku: false,
      );
    }

    test('上限まではそのまま増える', () {
      final entries = appendCaptureEntry([], entry(1));
      expect(entries.map((e) => e.id), ['1']);
    });

    test('上限を超えた分は古いものから破棄する', () {
      var entries = <CaptureEntry>[];
      for (var i = 0; i < captureMaxEntries + 5; i++) {
        entries = appendCaptureEntry(entries, entry(i));
      }
      expect(entries.length, captureMaxEntries);
      expect(entries.first.id, '5');
      expect(entries.last.id, '${captureMaxEntries + 4}');
    });
  });
}
