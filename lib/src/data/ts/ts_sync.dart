import 'dart:typed_data';

/// TSの188バイト境界に整列するバッファ。
///
/// 再生中TSはTCPの塊で届くため、パケット境界と一致しない。
/// [addBytes] に継ぎ足すと、整列できた分だけ188バイトパケット列
/// (ヘッダー付きのまま) を返す。端数は内部に保持し、次回呼び出しで使う。
/// 先頭のゴミは同期バイト (`0x47`) を探して読み飛ばす。
class TsSyncBuffer {
  final BytesBuilder _pending = BytesBuilder();

  /// 内部に残っている未整列バイト数 (テスト用)。
  int get pendingLength => _pending.length;

  /// [data] を追記し、整列できたパケット列を返す。
  List<Uint8List> addBytes(Uint8List data) {
    _pending.add(data);
    var bytes = _pending.toBytes();
    final out = <Uint8List>[];

    // 0x47を探す。188バイト先にも0x47があれば境界とみなす。
    var start = 0;
    while (start < bytes.length) {
      if (bytes[start] != 0x47) {
        start++;
        continue;
      }
      if (start + 188 < bytes.length && bytes[start + 188] != 0x47) {
        // 単発の0x47 (ペイロード内の偶然一致) として読み飛ばす。
        start++;
        continue;
      }
      break;
    }
    if (start >= bytes.length) {
      // 同期バイトが無いゴミだけなら捨てる。
      _pending.clear();
      return out;
    }
    if (start > 0) {
      bytes = bytes.sublist(start);
    }

    final complete = (bytes.length ~/ 188) * 188;
    for (var offset = 0; offset < complete; offset += 188) {
      out.add(bytes.sublist(offset, offset + 188));
    }
    _pending.clear();
    if (complete < bytes.length) {
      _pending.add(bytes.sublist(complete));
    }
    return out;
  }

  /// 内部バッファを破棄する。
  void reset() => _pending.clear();
}
