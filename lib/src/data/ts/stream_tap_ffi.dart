import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// 自前のネイティブ tap ライブラリ (`native/stream_tap`) への FFI。
///
/// mpv の stream コールバック自体は C 側 (`kurumi_stream_open` 以下) にあり、
/// Dart からは制御用 API のみ呼ぶ。Dart 製コールバックは一切作らない
/// (mpv 側スレッドからの呼び出しになるため)。
///
/// ライブラリの探索順:
/// - Android: APK 同梱の `libkurumi_stream_tap.so` を soname で開く
/// - Linux: Flutter バンドル内 `lib/` の同名ファイルを絶対パスで開く
///   (実行ファイル相対で決まるため dev/`nix build`/AppImage で共通)。
///   無ければ soname にフォールバックする
/// - Windows: 実行ファイルと同じフォルダの `kurumi_stream_tap.dll` を
///   絶対パスで開く。無ければ DLL 探査順にフォールバックする
/// - 他 OS: 未対応 ([UnsupportedError])。macOS/iOS は別途組み込みが必要
Future<DynamicLibrary> loadStreamTapLibrary() async {
  if (Platform.isAndroid) {
    return DynamicLibrary.open('libkurumi_stream_tap.so');
  }
  if (Platform.isLinux) {
    final bundleLib = File(
      '${File(Platform.resolvedExecutable).parent.path}/lib/libkurumi_stream_tap.so',
    );
    if (bundleLib.existsSync()) {
      return DynamicLibrary.open(bundleLib.path);
    }
    return DynamicLibrary.open('libkurumi_stream_tap.so');
  }
  if (Platform.isWindows) {
    final bundleDll = File(
      '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}kurumi_stream_tap.dll',
    );
    if (bundleDll.existsSync()) {
      return DynamicLibrary.open(bundleDll.path);
    }
    return DynamicLibrary.open('kurumi_stream_tap.dll');
  }
  throw UnsupportedError('stream tap は Linux/Android/Windows のみ対応しています');
}

/// 不透明な tap ハンドル。
final class KurumiTap extends Opaque {}

typedef _TapCreateNative = Pointer<KurumiTap> Function(Uint64 capacity);
typedef _TapCreateDart = Pointer<KurumiTap> Function(int capacity);

typedef _TapRefNative = Void Function(Pointer<KurumiTap> tap);
typedef _TapRefDart = void Function(Pointer<KurumiTap> tap);typedef _TapPushNative
    = Uint64 Function(
      Pointer<KurumiTap> tap,
      Pointer<Uint8> data,
      Uint64 len,
    );
typedef _TapPushDart
    = int Function(Pointer<KurumiTap> tap, Pointer<Uint8> data, int len);

typedef _TapSignalNative = Void Function(Pointer<KurumiTap> tap);
typedef _TapSignalDart = void Function(Pointer<KurumiTap> tap);

/// `kurumi_stream_open` のアドレスを mpv へ渡すための型。
typedef _StreamOpenNative
    = Int32 Function(Pointer<Void> userData, Pointer<Char> uri, Pointer<Void> info);

/// tap ライブラリの制御 API。テスト時は差し替え可能。
abstract interface class StreamTapNative {
  /// セッションを作り tap アドレスを返す。失敗時は例外送出しする。
  int create(int capacity);

  /// 積めたバイト数を返す (満杯時は一部のみ)。
  int push(int tap, Uint8List data);

  /// 正常終了を通知する。
  void eof(int tap);

  /// 異常終了を通知する (ブロック中の read は -1 で起きる)。
  void abort(int tap);

  /// Dart 側の参照を離す。
  void destroy(int tap);

  /// `kurumi_stream_open` の関数アドレス。
  int get openFunctionAddress;
}

/// FFI による [StreamTapNative] の実装。
class FfiStreamTapNative implements StreamTapNative {
  FfiStreamTapNative(DynamicLibrary lib)
    : _create = lib.lookupFunction<_TapCreateNative, _TapCreateDart>(
        'kurumi_tap_create',
      ),
      _unref = lib.lookupFunction<_TapRefNative, _TapRefDart>(
        'kurumi_tap_unref',
      ),
      _push = lib.lookupFunction<_TapPushNative, _TapPushDart>(
        'kurumi_tap_push',
      ),
      _eof = lib.lookupFunction<_TapSignalNative, _TapSignalDart>(
        'kurumi_tap_eof',
      ),
      _abort = lib.lookupFunction<_TapSignalNative, _TapSignalDart>(
        'kurumi_tap_abort',
      ),
      openFunctionAddress = lib
          .lookup<NativeFunction<_StreamOpenNative>>('kurumi_stream_open')
          .address;

  final _TapCreateDart _create;
  final _TapRefDart _unref;
  final _TapPushDart _push;
  final _TapSignalDart _eof;
  final _TapSignalDart _abort;

  @override
  final int openFunctionAddress;

  @override
  int create(int capacity) {
    final tap = _create(capacity);
    if (tap.address == 0) {
      throw StateError('tap セッションを作れませんでした');
    }
    // Dart が1参照を持つ (C 側で refcount=1済み)。アドレスで管理する。
    return tap.address;
  }

  @override
  int push(int tap, Uint8List data) {
    if (data.isEmpty) return 0;
    final ptr = calloc<Uint8>(data.length);
    try {
      ptr.asTypedList(data.length).setAll(0, data);
      return _push(Pointer<KurumiTap>.fromAddress(tap), ptr, data.length);
    } finally {
      calloc.free(ptr);
    }
  }

  @override
  void eof(int tap) => _eof(Pointer<KurumiTap>.fromAddress(tap));

  @override
  void abort(int tap) => _abort(Pointer<KurumiTap>.fromAddress(tap));

  @override
  void destroy(int tap) => _unref(Pointer<KurumiTap>.fromAddress(tap));
}
