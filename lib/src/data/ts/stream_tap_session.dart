import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'stream_tap_ffi.dart';
import 'stream_tap_pump.dart';

/// worker → main の出来事。送達可能な値のみ持つ。
sealed class TapWorkerEvent {
  const TapWorkerEvent();
}

/// ポンプ起動完了。tap アドレスと open 関数アドレスを渡す。
class TapWorkerReady extends TapWorkerEvent {
  const TapWorkerReady(this.tapAddress, this.openFunctionAddress);

  final int tapAddress;
  final int openFunctionAddress;
}

/// EITバッチ (PID 0x12 の188バイトパケット列)。
class TapWorkerEit extends TapWorkerEvent {
  TapWorkerEit(this.batch);

  final Uint8List batch;
}

/// 稼働統計。
class TapWorkerStats extends TapWorkerEvent {
  TapWorkerStats(this.stats);

  final TapStats stats;
}

/// 異常。直後に閉じる。
class TapWorkerError extends TapWorkerEvent {
  TapWorkerError(this.message);

  final String message;
}

/// 終了通知。
class TapWorkerDone extends TapWorkerEvent {
  const TapWorkerDone();
}

/// main → worker の指示。
sealed class TapWorkerCommand {
  const TapWorkerCommand();
}

/// ポンプ停止指示。
class TapWorkerClose extends TapWorkerCommand {
  const TapWorkerClose();
}

/// worker isolate の入口。引数は `[返信ポート, 上流URL文字列, ライブラリパス (任意)]`。
void runStreamTapPump(List<Object?> args) {
  _runStreamTapPump(args);
}

Future<void> _runStreamTapPump(List<Object?> args) async {
  final toMain = args[0] as SendPort;
  final upstreamUrl = Uri.parse(args[1] as String);
  // 明示指定 (テスト用。無ければ実行ファイルから解決する)。
  final libraryPath = args.length > 2 ? args[2] as String? : null;
  final commands = ReceivePort();
  toMain.send(commands.sendPort);

  StreamTapPump? pump;
  var closing = false;
  Future<void> finish() async {
    if (closing) return;
    closing = true;
    commands.close();
    try {
      await pump?.close();
    } finally {
      toMain.send(const TapWorkerDone());
    }
  }

  commands.listen((message) async {
    if (message is TapWorkerClose) await finish();
  });

  try {
    final native = FfiStreamTapNative(
      libraryPath == null
          ? await loadStreamTapLibrary()
          : DynamicLibrary.open(libraryPath),
    );
    pump = StreamTapPump(
      upstreamUrl: upstreamUrl,
      native: native,
      onReady: (tapAddress) =>
          toMain.send(TapWorkerReady(tapAddress, native.openFunctionAddress)),
      onEitBatch: (batch) => toMain.send(TapWorkerEit(batch)),
      onError: (error) => toMain.send(TapWorkerError('$error')),
      onStats: (stats) => toMain.send(TapWorkerStats(stats)),
    );
    await pump.start();
  } catch (error) {
    toMain.send(TapWorkerError('$error'));
    await finish();
  }
}

/// stream tap の再生セッション。
///
/// 重い取得ポンプは worker isolate で回し、メイン側にはEITバッチ
/// (PID 0x12 のみ) だけ渡す。フルTSの整列・分配をUI isolateで回すと
/// イベントループを圧迫し、mpvへの供給が途切れ途切れになる
/// (映像遅延・音切れ)。mpv 側は `kurumi-ts://<id>` を読む。
class StreamTapSession {
  StreamTapSession._();

  Isolate? _isolate;
  SendPort? _commands;
  StreamSubscription<Object?>? _fromWorker;

  Completer<SendPort>? _commandPort;
  Completer<TapWorkerReady>? _ready;

  int? _tapAddress;
  int? _openFunctionAddress;

  bool _closed = false;
  Completer<void>? _doneSignal;

  final StreamController<Uint8List> _tap = StreamController<Uint8List>();

  /// mpvが開くURL。[start] 後に有効。
  Uri? get url {
    final tap = _tapAddress;
    if (tap == null) return null;
    return Uri.parse('kurumi-ts://${tap.toRadixString(16)}');
  }

  /// `kurumi_stream_open` の関数アドレス。プロトコル登録に使う。
  int? get openFunctionAddress => _openFunctionAddress;

  /// EITタップ (PID 0x12 の188バイトパケット列)。
  Stream<Uint8List> get tsPackets => _tap.stream;

  /// セッションを開始し、最初の塊が届くのを待つ。
  ///
  /// タイムアウト・到達不能時は例外送出しし、呼び出し側で再試行表示に使う。
  static Future<StreamTapSession> start({
    required Uri upstreamUrl,
    String? libraryPath,
  }) async {
    final session = StreamTapSession._();
    await session._start(upstreamUrl, libraryPath);
    return session;
  }

  Future<void> _start(Uri upstreamUrl, String? libraryPath) async {
    final fromWorker = ReceivePort();
    _commandPort = Completer<SendPort>();
    _ready = Completer<TapWorkerReady>();
    _doneSignal = Completer<void>();
    try {
      _isolate = await Isolate.spawn(runStreamTapPump, [
        fromWorker.sendPort,
        upstreamUrl.toString(),
        libraryPath,
      ]);
    } catch (error) {
      fromWorker.close();
      throw StateError('tap worker を起動できませんでした: $error');
    }
    _fromWorker = fromWorker.listen(
      (message) {
        if (_closed) return;
        if (message is SendPort) {
          if (!_commandPort!.isCompleted) _commandPort!.complete(message);
          return;
        }
        if (message is TapWorkerReady) {
          _tapAddress = message.tapAddress;
          _openFunctionAddress = message.openFunctionAddress;
          if (!_ready!.isCompleted) _ready!.complete(message);
          return;
        }
        if (message is TapWorkerEit) {
          if (!_tap.isClosed) _tap.add(message.batch);
          return;
        }
        if (message is TapWorkerStats) {
          // ignore: avoid_print
          print('[tap] ${message.stats.describe()}');
          return;
        }
        if (message is TapWorkerError) {
          if (!_ready!.isCompleted) {
            _ready!.completeError(StateError(message.message));
          }
          unawaited(close());
          return;
        }
        if (message is TapWorkerDone) {
          if (!_doneSignal!.isCompleted) _doneSignal!.complete();
          return;
        }
      },
      onError: (_) => unawaited(close()),
      onDone: () {
        if (!_closed) unawaited(close());
      },
    );
    try {
      // 指示ポートは ready より先に届く。
      _commands = await _commandPort!.future.timeout(
        const Duration(seconds: 5),
      );
      await _ready!.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          unawaited(close());
          throw TimeoutException('上流の受信が始まりませんでした');
        },
      );
    } catch (_) {
      await close();
      rethrow;
    }
  }

  /// セッションを閉じる。mpv 側の読みは -1 で起きて終わる。
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _commands?.send(const TapWorkerClose());
    _commands = null;
    try {
      await _doneSignal?.future.timeout(const Duration(seconds: 5));
    } catch (_) {
      _isolate?.kill(priority: Isolate.immediate);
    } finally {
      _isolate = null;
    }
    await _fromWorker?.cancel();
    _fromWorker = null;
    if (!_tap.isClosed) await _tap.close();
  }
}
