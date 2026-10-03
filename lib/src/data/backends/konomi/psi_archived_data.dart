import 'dart:typed_data';

import 'konomi_live.dart';

/// KonomiTVのライブPSI/SIアーカイブデータURLを組み立てる純粋関数。
///
/// 仕様 (`server/app/routers/LiveStreamsRouter.py`):
/// - `GET /api/streams/live/{display_channel_id}/{quality}/psi-archived-data`
/// - [displayChannelId] は [Channel.id] (例: `gr011`) をそのまま使う
/// - [quality] は [konomiLiveQualities] のいずれか。不正値は `original` に正規化する
/// - [baseUrl] の末尾 `/` の有無に影響されない
Uri buildKonomiPsiArchivedDataUrl({
  required String baseUrl,
  required String displayChannelId,
  required String quality,
}) {
  final normalized = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
  final q = normalizeKonomiQuality(quality);
  return Uri.parse(
    '$normalized/api/streams/live/$displayChannelId/$q/psi-archived-data',
  );
}

/// psisiarc アーカイブから復元したTSパケット群。
class PsiTsChunk {
  const PsiTsChunk({
    required this.second,
    required this.packets,
    required this.pid,
  });

  /// ストリーム開始からの秒数 (PCR相当の算出元。表示には使わない)。
  final double second;

  /// ヘッダー設定済みのTSパケット (`188 * N` バイト)。
  final Uint8List packets;

  /// TSパケットのPID。
  final int pid;
}

/// ヘッダなしTSパケット群にTSヘッダを設定する。
///
/// EDCB Legacy WebUI の実装の移植
/// (`LivePSIArchivedDataDecoder.setTSPacketHeader`)。先頭パケットにのみ
/// payload_unit_start_indicator を立てる。戻り値は [packets] 自身。
Uint8List setTsPacketHeader(
  Uint8List packets,
  int pid,
  Map<int, int> counters,
) {
  var counter = counters[pid] ?? 0;
  for (var i = 0; i + 188 <= packets.length; i += 188) {
    packets[i] = 0x47;
    packets[i + 1] = (i > 0 ? 0 : 0x40) | ((pid >> 8) & 0x1F);
    packets[i + 2] = pid & 0xFF;
    packets[i + 3] = 0x10 | (counter & 0x0F);
    counter = (counter + 1) & 0x0F;
  }
  counters[pid] = counter;
  return packets;
}

/// PSI/SIアーカイブデータ (`.psc`) をTSパケットに展開するパーサー。
///
/// KonomiTV `LivePSIArchivedDataDecoder.readPSIArchivedDataChunk` の移植。
/// サーバーからのストリーミングを [addBytes] に継ぎ足すと、復元できた分だけ
/// [PsiTsChunk] を返す。データ不足分は内部に保持し、次回呼び出しで使う。
/// 構造破綻時は [StateError] を送出する。
class PsiArchivedDataParser {
  List<int>? _pids;
  List<Uint8List?>? _dict;
  int _position = 0;
  int _trailerSize = 0;
  int _timeListCount = -1;
  int _codeListPosition = 0;
  int _codeCount = 0;
  int _initTime = -1;
  int _currTime = -1;

  Uint8List _pending = Uint8List(0);

  final Map<int, int> _counters = {};

  /// 内部バッファに残っている未処理バイト数 (テスト用)。
  int get pendingLength => _pending.length;

  /// [data] を追記し、復元できたTSパケット群を返す。
  List<PsiTsChunk> addBytes(Uint8List data) {
    final merged = Uint8List(_pending.length + data.length);
    merged.setRange(0, _pending.length, _pending);
    merged.setRange(_pending.length, merged.length, data);
    final out = <PsiTsChunk>[];
    final rest = _parse(merged, out);
    _pending = rest;
    return out;
  }

  Uint8List _parse(Uint8List buffer, List<PsiTsChunk> out) {
    _ensureContext();
    final view = ByteData.view(
      buffer.buffer,
      buffer.offsetInBytes,
      buffer.length,
    );

    int u16(int offset) => view.getUint16(offset, Endian.little);
    int u32(int offset) => view.getUint32(offset, Endian.little);
    int u32be(int offset) => view.getUint32(offset, Endian.big);

    while (buffer.length - _position >= _trailerSize + 32) {
      var position = _position + _trailerSize;
      final timeListLen = u16(position + 10);
      final dictionaryLen = u16(position + 12);
      final dictionaryWindowLen = u16(position + 14);
      final dictionaryDataSize = u32(position + 16);
      final dictionaryBufferSize = u32(position + 20);
      final codeListLen = u32(position + 24);

      if (u32be(position) != 0x50737363 ||
          u32be(position + 4) != 0x0d0a9a0a ||
          dictionaryWindowLen < dictionaryLen ||
          dictionaryBufferSize < dictionaryDataSize ||
          dictionaryWindowLen > 65536 - 4096) {
        throw StateError('PSIアーカイブのマジックが不正です');
      }

      final chunkSize =
          32 +
          timeListLen * 4 +
          dictionaryLen * 2 +
          ((dictionaryDataSize + 1) ~/ 2) * 2 +
          codeListLen * 2;

      if (buffer.length - position < chunkSize) break;

      var timeListPosition = position + 32;
      position += 32 + timeListLen * 4;

      if (_timeListCount < 0) {
        final pids = List<int>.filled(dictionaryWindowLen, 0);
        final dict = List<Uint8List?>.filled(dictionaryWindowLen, null);
        var sectionListPosition = 0;

        for (var i = 0; i < dictionaryLen; i++, position += 2) {
          final codeOrSize = u16(position) - 4096;
          if (codeOrSize >= 0) {
            if (codeOrSize >= _pids!.length || _pids![codeOrSize] < 0) {
              throw StateError('PSIアーカイブの辞書参照が不正です');
            }
            pids[i] = _pids![codeOrSize];
            dict[i] = _dict![codeOrSize];
            _pids![codeOrSize] = -1;
          } else {
            pids[i] = codeOrSize;
            dict[i] = null;
            sectionListPosition += 2;
          }
        }
        sectionListPosition += position;

        for (var i = 0; i < dictionaryLen; i++) {
          if (pids[i] >= 0) continue;
          final psiLength = pids[i] + 4097;
          final psi = buffer.sublist(
            sectionListPosition,
            sectionListPosition + psiLength,
          );
          final packed = Uint8List(((psi.length + 1 + 183) ~/ 184) * 188);
          for (var j = 0, k = 0; k < psi.length; j++, k++) {
            if (j % 188 == 0) {
              j += 4;
              if (k == 0) {
                packed[j++] = 0;
              }
            }
            packed[j] = psi[k];
          }
          sectionListPosition += psi.length;
          pids[i] = u16(position) & 0x1FFF;
          position += 2;
          dict[i] = packed;
        }

        var w = dictionaryLen;
        for (var j = 0; w < dictionaryWindowLen; j++) {
          if (j >= _pids!.length) {
            throw StateError('PSIアーカイブの辞書窓が不正です');
          }
          if (_pids![j] < 0) continue;
          pids[w] = _pids![j];
          dict[w] = _dict![j];
          w++;
        }
        _pids = pids;
        _dict = dict;
        _timeListCount = 0;
        position = sectionListPosition + dictionaryDataSize % 2;
      } else {
        position +=
            dictionaryLen * 2 + ((dictionaryDataSize + 1) ~/ 2) * 2;
      }

      position += _codeListPosition;
      timeListPosition += _timeListCount * 4;
      for (;
        _timeListCount < timeListLen;
        _timeListCount++, timeListPosition += 4) {
        var initTime = _initTime;
        var currTime = _currTime;
        final absTime = u32(timeListPosition);
        if (absTime == 0xFFFFFFFF) {
          currTime = -1;
        } else if (absTime >= 0x80000000) {
          currTime = absTime & 0x3FFFFFFF;
          if (initTime < 0) initTime = currTime;
        } else {
          final n = u16(timeListPosition + 2) + 1;
          if (currTime >= 0) {
            currTime += u16(timeListPosition);
            final sec =
                ((currTime + 0x40000000 - initTime) & 0x3FFFFFFF) / 11250;
            if (sec >= 0) {
              for (;
                _codeCount < n;
                _codeCount++, position += 2, _codeListPosition += 2) {
                final code = u16(position) - 4096;
                final dict = _dict![code]!;
                final pid = _pids![code];
                final packets = Uint8List.fromList(dict);
                setTsPacketHeader(packets, pid, _counters);
                out.add(
                  PsiTsChunk(second: sec, packets: packets, pid: pid),
                );
              }
              _codeCount = 0;
            } else {
              position += n * 2;
              _codeListPosition += n * 2;
            }
          } else {
            position += n * 2;
            _codeListPosition += n * 2;
          }
        }
        _initTime = initTime;
        _currTime = currTime;
      }

      _position = position;
      _trailerSize = 2 + (2 + chunkSize) % 4;
      _timeListCount = -1;
      _codeListPosition = 0;
      _currTime = -1;
    }

    final rest = buffer.sublist(_position);
    _position = 0;
    return rest;
  }

  void _ensureContext() {
    if (_pids != null) return;
    _pids = [];
    _dict = [];
    _position = 0;
    _trailerSize = 0;
    _timeListCount = -1;
    _codeListPosition = 0;
    _codeCount = 0;
    _initTime = -1;
    _currTime = -1;
  }
}
