import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/data/ts/stream_tap_ffi.dart';

/// ビルド成果物の .so へのパス。無ければスキップする。
String? _findTapLibrary() {
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
  group('stream tap FFI', () {
    test('シンボル解決とpush/abort/destroy', () {
      final path = _findTapLibrary()!;
      final native = FfiStreamTapNative(DynamicLibrary.open(path));
      expect(native.openFunctionAddress, isNot(0));

      final tap = native.create(1024);
      expect(tap, isNot(0));

      final data = Uint8List.fromList(List.filled(100, 0x47));
      expect(native.push(tap, data), 100);
      // 満杯時は積めない分を返す。
      final big = Uint8List.fromList(List.filled(2000, 0x47));
      expect(native.push(tap, big), lessThan(2000));

      native.abort(tap);
      expect(native.push(tap, data), 0);

      native.destroy(tap);
    }, skip: _findTapLibrary() == null);
  });
}
