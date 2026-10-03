import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:media_kit/media_kit.dart';

// ignore: implementation_imports
import 'package:media_kit/src/player/native/core/native_library.dart';

/// mpv の stream_cb 登録 (`mpv_stream_cb_add_ro`)。
///
/// `NativeLibrary` は package の公開 API ではないため src から直接取る。
/// media_kit 側の配置が変わったらここが壊れる (コンパイルエラーで気付ける)。
/// 取得に失敗した場合は media_kit と同じ soname 候補で開き直す。
Future<DynamicLibrary> _loadLibmpv() async {
  try {
    return DynamicLibrary.open(NativeLibrary.path);
  } catch (_) {
    // libmpv.so.2 等。media_kit の NativeLibrary.ensureInitialized と同順。
    const names = ['libmpv.so', 'libmpv.so.2', 'libmpv.so.1', 'libmpv.so.0'];
    for (final name in names) {
      try {
        return DynamicLibrary.open(name);
      } catch (_) {
        continue;
      }
    }
    throw StateError('libmpv を開けませんでした');
  }
}

/// 不透明な mpv ハンドル。media_kit 側の生成物には触れない。
final class _MpvHandle extends Opaque {}

/// `mpv_stream_cb_info`。配置は mpv のヘッダーと同一
/// (cookie, read, seek, size, close, cancel の順) でなければならない。
final class _MpvStreamCbInfo extends Struct {
  external Pointer<Void> cookie;

  external Pointer<NativeFunction<_ReadNative>> readFn;

  external Pointer<NativeFunction<_SeekNative>> seekFn;

  external Pointer<NativeFunction<_SizeNative>> sizeFn;

  external Pointer<NativeFunction<_CloseNative>> closeFn;

  external Pointer<NativeFunction<_CloseNative>> cancelFn;
}

typedef _ReadNative
    = Int64 Function(Pointer<Void> cookie, Pointer<Char> buf, Uint64 nbytes);
typedef _SeekNative = Int64 Function(Pointer<Void> cookie, Int64 offset);
typedef _SizeNative = Int64 Function(Pointer<Void> cookie);
typedef _CloseNative = Void Function(Pointer<Void> cookie);

typedef _AddRoNative
    = Int32 Function(
      Pointer<_MpvHandle> ctx,
      Pointer<Char> protocol,
      Pointer<Void> userData,
      Pointer<NativeFunction<_OpenNative>> open,
    );
typedef _AddRoDart
    = int Function(
      Pointer<_MpvHandle> ctx,
      Pointer<Char> protocol,
      Pointer<Void> userData,
      Pointer<NativeFunction<_OpenNative>> open,
    );

typedef _OpenNative
    = Int32 Function(
      Pointer<Void> userData,
      Pointer<Char> uri,
      Pointer<_MpvStreamCbInfo> info,
    );

/// tap 用プロトコル (`kurumi-ts://`) を [player] の mpv に登録する。
///
/// `open` の実体はネイティブ (`kurumi_stream_open`) で、Dart 製コールバックは
/// 作らない。登録はハンドル (Player 単位) ごとに1回で足りる。再試行などで
/// 同一ハンドルに重ねて登録した場合は mpv が `MPV_ERROR_INVALID_PARAMETER`
/// (-4) を返すが、これは登録済みの意味なので正常扱いにする。
Future<void> registerStreamTapProtocol(
  Player player, {
  required int openFunctionAddress,
}) async {
  final platform = player.platform;
  if (platform is! NativePlayer) {
    throw UnsupportedError('stream tap はネイティブ再生のみ対応しています');
  }
  final libmpv = await _loadLibmpv();
  final addRo = libmpv.lookupFunction<_AddRoNative, _AddRoDart>(
    'mpv_stream_cb_add_ro',
  );
  final handle = Pointer<_MpvHandle>.fromAddress(await platform.handle);
  final protocol = 'kurumi-ts'.toNativeUtf8();
  try {
    final rc = addRo(
      handle,
      protocol.cast(),
      nullptr,
      Pointer<NativeFunction<_OpenNative>>.fromAddress(openFunctionAddress),
    );
    // MPV_ERROR_INVALID_PARAMETER (-4) = 同一ハンドルに登録済み。正常扱い。
    if (rc != 0 && rc != -4) {
      throw StateError('プロトコル登録に失敗しました (rc=$rc)');
    }
  } finally {
    calloc.free(protocol);
  }
}
