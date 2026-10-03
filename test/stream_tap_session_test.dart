import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/data/ts/eit.dart';
import 'package:kurumi/src/data/ts/live_program.dart';
import 'package:kurumi/src/data/ts/stream_tap_ffi.dart';
import 'package:kurumi/src/data/ts/stream_tap_pump.dart';
import 'package:kurumi/src/data/ts/stream_tap_session.dart';

/// ネイティブ呼び出しを記録するだけの差し替え。mpv 側は起動しない。
class _FakeTapNative implements StreamTapNative {
  int _nextTap = 1;
  final created = <int>[];
  final pushed = BytesBuilder();
  final eofed = <int>[];
  final aborted = <int>[];
  final destroyed = <int>[];

  /// 一度の push で受け入れる上限 (0 なら無制限)。
  int acceptLimit;

  _FakeTapNative({this.acceptLimit = 0});

  @override
  int create(int capacity) {
    final tap = _nextTap++;
    created.add(tap);
    return tap;
  }

  @override
  int push(int tap, Uint8List data) {
    pushed.add(data);
    if (acceptLimit <= 0 || data.length <= acceptLimit) return data.length;
    return acceptLimit;
  }

  @override
  void eof(int tap) => eofed.add(tap);

  @override
  void abort(int tap) => aborted.add(tap);

  @override
  void destroy(int tap) => destroyed.add(tap);

  @override
  int get openFunctionAddress => 0x1234;
}

Uint8List _aribAscii(String text) {
  return Uint8List.fromList([0x1B, 0x28, 0x4A, ...text.codeUnits]);
}

Uint8List _sectionBytes() {
  const eventId = 77;
  final name = _aribAscii('AB');
  final bodyText = _aribAscii('C');
  final desc = BytesBuilder()
    ..addByte(0x4D)
    ..addByte(3 + 1 + name.length + 1 + bodyText.length)
    ..add([0x6A, 0x70, 0x6E])
    ..addByte(name.length)
    ..add(name)
    ..addByte(bodyText.length)
    ..add(bodyText);
  final descBytes = desc.toBytes();
  final body = BytesBuilder()
    ..addByte(0x4E)
    ..addByte(0xB0)
    ..addByte(0x00)
    ..addByte(0x00)
    ..addByte(0x07)
    ..addByte(0xC1)
    ..addByte(0x00)
    ..addByte(0x00)
    ..addByte(0x00)
    ..addByte(0x01)
    ..addByte(0x00)
    ..addByte(0x01)
    ..addByte(0x01)
    ..addByte(0x4E)
    ..addByte((eventId >> 8) & 0xFF)
    ..addByte(eventId & 0xFF)
    ..add([0xEB, 0x96, 0x10, 0x00, 0x00])
    ..add([0x01, 0x00, 0x00])
    ..addByte((descBytes.length >> 8) & 0x0F)
    ..addByte(descBytes.length & 0xFF)
    ..add(descBytes);
  final without = body.toBytes();
  final sectionLength = (without.length - 3) + 4;
  without[1] = 0xB0 | ((sectionLength >> 8) & 0x0F);
  without[2] = sectionLength & 0xFF;
  final crc = mpeg2CrcOf(without);
  return (BytesBuilder()
        ..add(without)
        ..add([
          (crc >> 24) & 0xFF,
          (crc >> 16) & 0xFF,
          (crc >> 8) & 0xFF,
          crc & 0xFF,
        ]))
      .toBytes();
}

Uint8List _packetize(Uint8List payload, int pid) {
  final out = BytesBuilder();
  var offset = 0;
  var first = true;
  var continuity = 0;
  while (offset < payload.length) {
    final packet = Uint8List(188);
    var start = 4;
    if (first) {
      packet[4] = 0x00;
      start = 5;
      first = false;
    }
    final room = 188 - start;
    final end = (offset + room).clamp(0, payload.length);
    final chunk = payload.sublist(offset, end);
    packet.setRange(start, start + chunk.length, chunk);
    for (var i = start + chunk.length; i < 188; i++) {
      packet[i] = 0xFF;
    }
    packet[0] = 0x47;
    packet[1] = (offset == 0 ? 0x40 : 0x00) | ((pid >> 8) & 0x1F);
    packet[2] = pid & 0xFF;
    packet[3] = 0x10 | (continuity++ & 0x0F);
    out.add(packet);
    offset = end;
  }
  return out.toBytes();
}

/// 一定 chunk ずつ流すローカル上流。[\data] を流し終えたら少し待たせる。
Future<HttpServer> _serve(Uint8List data, int chunkSize) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  unawaited(
    server.listen((request) async {
      final response = request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType('video', 'MP2T')
        ..bufferOutput = false;
      for (var i = 0; i < data.length; i += chunkSize) {
        final end = (i + chunkSize).clamp(0, data.length);
        response.add(data.sublist(i, end));
        await response.flush();
      }
      await Future<void>.delayed(const Duration(seconds: 10));
      await response.close();
    }).asFuture(),
  );
  return server;
}

/// ビルド成果物の tap ライブラリ。無ければ null (テストをスキップする)。
String? _tapLibrary() {
  const candidates = [
    'build/linux/x64/debug/bundle/lib/libkurumi_stream_tap.so',
    'build/linux/x64/release/bundle/lib/libkurumi_stream_tap.so',
  ];
  for (final path in candidates) {
    if (File(path).existsSync()) return File(path).absolute.path;
  }
  return null;
}

void main() {
  group('stream tap ポンプ', () {
    test('上流をネイティブとEITタップの両方に流す', () async {
      final upstreamData =
          (BytesBuilder()
                ..add(_packetize(_sectionBytes(), 0x12))
                ..add(
                  _packetize(Uint8List.fromList(List.filled(500, 0x55)), 0x100),
                ))
              .toBytes();

      final upstream = await _serve(upstreamData, 500);

      final native = _FakeTapNative();
      final tapped = BytesBuilder();
      final ready = Completer<int>();
      final stats = <TapStats>[];
      final pump = StreamTapPump(
        upstreamUrl: Uri.parse('http://127.0.0.1:${upstream.port}/x'),
        native: native,
        onReady: ready.complete,
        onEitBatch: tapped.add,
        onError: (_) {},
        onStats: stats.add,
        statsInterval: const Duration(milliseconds: 20),
      );
      await pump.start();
      expect(await ready.future, isNot(0));

      // ネイティブ側に全バイト届くまで待つ。
      for (
        var i = 0;
        i < 100 && native.pushed.length < upstreamData.length;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(native.pushed.toBytes(), upstreamData);

      // EITタップには PID 0x12 だけが行く (他PIDは落とされる)。
      final tappedBytes = tapped.toBytes();
      expect(tappedBytes.length % 188, 0);
      expect(tappedBytes.length, lessThan(upstreamData.length));
      for (var offset = 0; offset < tappedBytes.length; offset += 188) {
        final pid =
            ((tappedBytes[offset + 1] & 0x1F) << 8) | tappedBytes[offset + 2];
        expect(pid, 0x12);
      }
      final sections = TsSectionAssembler()
          .addPackets(tappedBytes)
          .where((s) => s.pid == 0x12)
          .toList();
      expect(sections, isNotEmpty);
      final eit = parseEitSection(sections.first.section);
      final program = buildLiveTvProgram(eit!, networkId: 1, serviceId: 7);
      expect(program!.title, 'AB');

      await pump.close();
      // abort + destroy が呼ばれている。
      expect(native.aborted, hasLength(1));
      expect(native.destroyed, hasLength(1));

      // 終了時に統計が通知され、累積バイト数も一致する。
      expect(stats, isNotEmpty);
      expect(stats.last.bytesPushed, upstreamData.length);
      expect(stats.last.describe(), contains('tap pump:'));
      await upstream.close(force: true);
    });

    test('188バイト境界が崩れた塊もEITとして再構成できる', () async {
      final upstreamData = _packetize(_sectionBytes(), 0x12);
      // 境界をずらした塊を数回送る。
      final upstream = await _serve(upstreamData, 100);

      final native = _FakeTapNative();
      final tapped = BytesBuilder();
      final pump = StreamTapPump(
        upstreamUrl: Uri.parse('http://127.0.0.1:${upstream.port}/x'),
        native: native,
        onReady: (_) {},
        onEitBatch: tapped.add,
        onError: (_) {},
      );
      await pump.start();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await pump.close();

      final tappedBytes = tapped.toBytes();
      expect(tappedBytes.length % 188, 0);
      expect(tappedBytes, isNotEmpty);
      expect(native.pushed.length, upstreamData.length);
      await upstream.close(force: true);
    });

    test('上流不通時は例外送出しする', () async {
      final probe = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = probe.port;
      await probe.close(force: true);
      final pump = StreamTapPump(
        upstreamUrl: Uri.parse('http://127.0.0.1:$port/x'),
        native: _FakeTapNative(),
        onReady: (_) {},
        onEitBatch: (_) {},
        onError: (_) {},
      );
      await expectLater(pump.start(), throwsA(isA<StateError>()));
      await pump.close();
    });

    test('リングが満杯なら残りを保持し、次回 push で使い切る', () async {
      final upstreamData = _packetize(
        Uint8List.fromList(List.filled(700, 0x55)),
        0x100,
      );
      final upstream = await _serve(upstreamData, upstreamData.length);

      final native = _FakeTapNative(acceptLimit: 1000);
      final pump = StreamTapPump(
        upstreamUrl: Uri.parse('http://127.0.0.1:${upstream.port}/x'),
        native: native,
        onReady: (_) {},
        onEitBatch: (_) {},
        onError: (_) {},
      );
      await pump.start();
      // 上流は1チャンクで終わるため、二巡目で残りが積まれる。
      for (
        var i = 0;
        i < 20 && native.pushed.length < upstreamData.length;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await pump.close();
      // 総量は落ちない (順番も保たれる)。
      expect(native.pushed.toBytes(), upstreamData);
      await upstream.close(force: true);
    });
  });

  group('stream tap セッション (worker isolate)', () {
    test('EITバッチがworker経由でメイン isolate に届く', () async {
      final upstreamData =
          (BytesBuilder()
                ..add(_packetize(_sectionBytes(), 0x12))
                ..add(
                  _packetize(Uint8List.fromList(List.filled(500, 0x55)), 0x100),
                ))
              .toBytes();
      final upstream = await _serve(upstreamData, 500);

      final session = await StreamTapSession.start(
        upstreamUrl: Uri.parse('http://127.0.0.1:${upstream.port}/x'),
        libraryPath: _tapLibrary(),
      );
      expect(session.url.toString(), startsWith('kurumi-ts://'));
      expect(session.openFunctionAddress, isNotNull);

      // 受信は worker isolate から届く (UDP ではなくSendPort経由)。
      final tapped = BytesBuilder();
      final sub = session.tsPackets.listen(tapped.add);
      for (var i = 0; i < 100 && tapped.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      final tappedBytes = tapped.toBytes();
      expect(tappedBytes.length % 188, 0);
      expect(tappedBytes, isNotEmpty);
      for (var offset = 0; offset < tappedBytes.length; offset += 188) {
        final pid =
            ((tappedBytes[offset + 1] & 0x1F) << 8) | tappedBytes[offset + 2];
        expect(pid, 0x12);
      }
      final sections = TsSectionAssembler().addPackets(tappedBytes);
      expect(sections, isNotEmpty);
      expect(parseEitSection(sections.first.section), isNotNull);

      await sub.cancel();
      await session.close();
      await upstream.close(force: true);
    }, skip: _tapLibrary() == null);

    test('上流不通時は例外送出しする', () async {
      final probe = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = probe.port;
      await probe.close(force: true);
      await expectLater(
        StreamTapSession.start(
          upstreamUrl: Uri.parse('http://127.0.0.1:$port/x'),
          libraryPath: _tapLibrary(),
        ),
        throwsA(isA<StateError>()),
      );
    }, skip: _tapLibrary() == null);
  });
}
