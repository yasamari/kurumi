import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'stream_tap_ffi.dart';
import 'ts_sync.dart';

/// ポンプ稼働統計。デバッグログ用 (全て累積)。
class TapStats {
  const TapStats({
    this.bytesIn = 0,
    this.bytesPushed = 0,
    this.pushCalls = 0,
    this.partialPushes = 0,
    this.pauses = 0,
    this.maxPendingBytes = 0,
    this.eitBatches = 0,
  });

  /// 上流から受けたバイト数。
  final int bytesIn;

  /// ネイティブのリングに積めたバイト数。
  final int bytesPushed;

  /// push 呼び出し回数。
  final int pushCalls;

  /// 一部しか積めなかった回数。
  final int partialPushes;

  /// 上流を一時停止した回数。
  final int pauses;

  /// 積み残しの最大バイト数。
  final int maxPendingBytes;

  /// EITバッチの送出回数。
  final int eitBatches;

  /// 1行ログ用。
  String describe() {
    String mb(int bytes) => (bytes / 1048576).toStringAsFixed(1);
    return 'tap pump: in=${mb(bytesIn)}MB pushed=${mb(bytesPushed)}MB '
        'push=$pushCalls partial=$partialPushes pauses=$pauses '
        'maxPending=${maxPendingBytes ~/ 1024}KB eit=$eitBatches';
  }
}

/// 上流TSの取得ポンプ。isolate非依存で、呼び出し側isolateで動く。
///
/// 従来はUI isolateで回していたが、フルTS (数MB/s) の整列・分配を
/// 毎秒数千イベントで回すとイベントループを圧迫し、mpvへの供給が
/// 途切れ途切れになる (映像遅延・音切れ)。重い部分は worker isolate
/// (`stream_tap_session.dart`) で動かし、メイン側にはEITバッチだけ渡す。
class StreamTapPump {
  StreamTapPump({
    required this.upstreamUrl,
    required this.native,
    HttpClient? httpClient,
    required this.onReady,
    required this.onEitBatch,
    required this.onError,
    this.onStats,
    this.ringCapacity = 4 * 1024 * 1024,
    this.pendingCap = 8 * 1024 * 1024,
    this.pollInterval = const Duration(milliseconds: 250),
    this.statsInterval = const Duration(seconds: 5),
  }) : _httpClient = httpClient ?? HttpClient();

  /// 上流のTS (MirakurunのライブTS等)。
  final Uri upstreamUrl;

  /// ネイティブのリング操作。
  final StreamTapNative native;
  final HttpClient _httpClient;

  /// 最初の塊が届いたときに tap アドレスと共に呼ばれる。
  final void Function(int tapAddress) onReady;

  /// PID 0x12 だけ抜き出した188バイト境界のパケット列。
  final void Function(Uint8List batch) onEitBatch;

  /// 上流異常時に呼ばれる (呼び出し後に閉じられる)。
  final void Function(Object error) onError;

  /// 定期・終了時の統計。nullなら送出しない。
  final void Function(TapStats stats)? onStats;

  /// リング容量。mpv の読みバーストを吸収する。
  final int ringCapacity;

  /// 積み残し上限。超過で上流を一時停止する。
  final int pendingCap;

  /// 一時停止中にリングの空きを確かめる間隔。
  final Duration pollInterval;

  /// 統計の送出間隔。
  final Duration statsInterval;

  StreamSubscription<List<int>>? _upstream;
  Timer? _pollTimer;
  Timer? _statsTimer;
  bool _upstreamPaused = false;
  bool _closed = false;

  final TsSyncBuffer _sync = TsSyncBuffer();
  final BytesBuilder _pending = BytesBuilder();
  int _pendingBytes = 0;
  int? _tapHandle;

  Completer<void>? _firstChunk;

  int _bytesIn = 0;
  int _bytesPushed = 0;
  int _pushCalls = 0;
  int _partialPushes = 0;
  int _pauses = 0;
  int _maxPendingBytes = 0;
  int _eitBatches = 0;

  /// ポンプを開始し、最初の塊が届くのを待つ。
  ///
  /// タイムアウト・到達不能時は例外送出しする。
  Future<void> start() async {
    _tapHandle = native.create(ringCapacity);
    _firstChunk = Completer<void>();
    unawaited(_pump());
    await _firstChunk!.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        unawaited(close());
        throw TimeoutException('上流の受信が始まりませんでした');
      },
    );
  }

  Future<void> _pump() async {
    try {
      final request = await _httpClient.getUrl(upstreamUrl);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('上流が ${response.statusCode} を返しました');
      }
      _statsTimer = Timer.periodic(statsInterval, (_) => _reportStats());
      _upstream = response.listen(
        (chunk) {
          if (_closed) return;
          final bytes = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
          _bytesIn += bytes.length;
          // EITタップへ。PID 0x12 だけ集めて1イベントにまとめる。
          final kept = BytesBuilder();
          for (final packet in _sync.addBytes(bytes)) {
            if (packet.length >= 3 &&
                packet[0] == 0x47 &&
                ((packet[1] & 0x1F) << 8 | packet[2]) == 0x12) {
              kept.add(packet);
            }
          }
          if (kept.length > 0) {
            _eitBatches++;
            onEitBatch(kept.toBytes());
          }
          if (_closed) return;
          // ネイティブのリングへ (積み残しは保持する)。
          _pending.add(bytes);
          _pendingBytes += bytes.length;
          if (_pendingBytes > _maxPendingBytes) {
            _maxPendingBytes = _pendingBytes;
          }
          _flushPending();
          if (_pendingBytes > pendingCap && !_upstreamPaused) {
            _pauses++;
            _upstreamPaused = true;
            _upstream?.pause();
            _pollTimer ??= Timer.periodic(pollInterval, (_) {
              if (_closed) return;
              _flushPending();
              if (_pendingBytes == 0) {
                _upstreamPaused = false;
                _upstream?.resume();
                _pollTimer?.cancel();
                _pollTimer = null;
              }
            });
          }
          if (!_firstChunk!.isCompleted) {
            _firstChunk!.complete();
            onReady(_tapHandle!);
          }
        },
        onError: (Object error) {
          onError(error);
          unawaited(close());
        },
        onDone: () async {
          // 上流の正常終了。残りを積んで EOF を通知する。
          _flushPending();
          final tap = _tapHandle;
          if (tap != null) native.eof(tap);
          await close();
        },
        cancelOnError: true,
      );
    } catch (error) {
      if (!_firstChunk!.isCompleted) {
        _firstChunk!.completeError(StateError('上流に接続できませんでした'));
      } else {
        onError(error);
      }
      await close();
    }
  }

  void _flushPending() {
    final tap = _tapHandle;
    if (tap == null || _pendingBytes == 0 || _closed) return;
    final bytes = _pending.toBytes();
    _pushCalls++;
    final accepted = native.push(tap, bytes);
    _bytesPushed += accepted;
    if (accepted >= bytes.length) {
      _pending.clear();
      _pendingBytes = 0;
    } else {
      if (accepted > 0) {
        _partialPushes++;
        final rest = bytes.sublist(accepted);
        _pending.clear();
        _pending.add(rest);
        _pendingBytes = rest.length;
      }
    }
  }

  void _reportStats() {
    onStats?.call(
      TapStats(
        bytesIn: _bytesIn,
        bytesPushed: _bytesPushed,
        pushCalls: _pushCalls,
        partialPushes: _partialPushes,
        pauses: _pauses,
        maxPendingBytes: _maxPendingBytes,
        eitBatches: _eitBatches,
      ),
    );
  }

  /// ポンプを閉じる。mpv 側の読みは -1 で起きて終わる。
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _pollTimer?.cancel();
    _pollTimer = null;
    _statsTimer?.cancel();
    _statsTimer = null;
    await _upstream?.cancel();
    _upstream = null;
    final first = _firstChunk;
    if (first != null && !first.isCompleted) {
      first.completeError(StateError('タップを閉じました'));
    }
    final tap = _tapHandle;
    _tapHandle = null;
    if (tap != null) {
      native.abort(tap);
      native.destroy(tap);
    }
    _httpClient.close(force: true);
    _reportStats();
  }
}
