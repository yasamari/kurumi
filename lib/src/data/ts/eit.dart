import 'dart:typed_data';

/// MPEG-TSのビットリーダー。node-aribts `TsReader` の移植。
class TsBitReader {
  TsBitReader(this.buffer, [this.position = 0]);

  final Uint8List buffer;

  /// ビット位置。
  int position;

  int _readBitsRaw(int length) {
    if (position + length > buffer.length * 8) {
      position += length;
      return 0;
    }
    var value = 0;
    var rest = length;
    while (rest > 7) {
      final index = position >> 3;
      final shift = position & 0x07;
      final mask = (1 << (8 - shift)) - 1;
      value <<= 8;
      value |= (buffer[index] & mask) << shift;
      value |= buffer[index + 1] >> (8 - shift);
      position += 8;
      rest -= 8;
    }
    while (rest > 0) {
      final index = position >> 3;
      final shift = (position & 0x07) ^ 0x07;
      value <<= 1;
      value |= (buffer[index] >> shift) & 0x01;
      position++;
      rest--;
    }
    return value;
  }

  /// 任意ビット幅を読む (最大52bit程度まで)。
  int readBits(int length) {
    var value = 0;
    var rest = length;
    while (rest > 31) {
      final bits = (rest - 1) % 31 + 1;
      value += _readBitsRaw(bits);
      value *= 0x80000000;
      rest -= bits;
    }
    value += _readBitsRaw(rest);
    return value;
  }

  int uimsbf(int length) => readBits(length);

  int bslbf(int length) => readBits(length);

  void skip(int length) => position += length;

  /// [length] バイトを読む。
  Uint8List readBytes(int length) {
    if (position + length * 8 > buffer.length * 8) {
      position += length * 8;
      return Uint8List(0);
    }
    final start = position >> 3;
    position += length * 8;
    return buffer.sublist(start, start + length);
  }

  /// 残りビット数。
  int get remainingBits => buffer.length * 8 - position;
}

/// MPEG-2 CRC32 (多項式 `0x04C11DB7`) のテーブルを生成する。
List<int> _buildMpeg2CrcTable() {
  const poly = 0x04C11DB7;
  final table = List<int>.filled(256, 0);
  for (var i = 0; i < 256; i++) {
    var c = (i << 24) & 0xFFFFFFFF;
    for (var j = 0; j < 8; j++) {
      c = (c & 0x80000000) != 0
          ? (((c << 1) & 0xFFFFFFFF) ^ poly) & 0xFFFFFFFF
          : (c << 1) & 0xFFFFFFFF;
    }
    table[i] = c;
  }
  return table;
}

final _mpeg2CrcTable = _buildMpeg2CrcTable();

/// セクション全体 (CRC含む) のCRC剰余を返す。正常なら0になる。
int mpeg2CrcRemainder(Uint8List section) {
  var crc = 0xFFFFFFFF;
  for (final byte in section) {
    crc =
        (((crc << 8) & 0xFFFFFFFF) ^
            _mpeg2CrcTable[((crc >> 24) ^ byte) & 0xFF]) &
        0xFFFFFFFF;
  }
  return crc;
}

/// CRCなしのバイト列に対するMPEG-2 CRC値を返す。セクション組み立て用。
int mpeg2CrcOf(Uint8List data) => _mpeg2CrcRaw(data);

int _mpeg2CrcRaw(Uint8List data) {
  var crc = 0xFFFFFFFF;
  for (final byte in data) {
    crc =
        (((crc << 8) & 0xFFFFFFFF) ^
            _mpeg2CrcTable[((crc >> 24) ^ byte) & 0xFF]) &
        0xFFFFFFFF;
  }
  return crc;
}

/// EIT開始時刻 (5バイト: MJD 2 + BCD 3) を JST の瞬間として解釈する。
///
/// 全ビット1 (未定値) は null を返す。
DateTime? decodeEitStartTime(Uint8List bytes) {
  if (bytes.length < 5) return null;
  if (bytes.every((b) => b == 0xFF)) return null;
  final mjd = (bytes[0] << 8) | bytes[1];
  final year0 = ((mjd - 15078.2) / 365.25).truncate();
  final month0 = ((mjd - 14956.1 - (year0 * 365.25).truncate()) / 30.6001)
      .truncate();
  final day =
      mjd - 14956 - (year0 * 365.25).truncate() - (month0 * 30.6001).truncate();
  final k = (month0 == 14 || month0 == 15) ? 1 : 0;
  final year = year0 + k + 1900;
  final month = month0 - 1 - k * 12;
  final hour = (bytes[2] >> 4) * 10 + (bytes[2] & 0x0F);
  final minute = (bytes[3] >> 4) * 10 + (bytes[3] & 0x0F);
  final second = (bytes[4] >> 4) * 10 + (bytes[4] & 0x0F);
  // JSTの壁時計として解釈し、絶対時刻に直す。
  return DateTime.utc(
    year,
    month,
    day,
    hour,
    minute,
    second,
  ).subtract(const Duration(hours: 9));
}

/// EIT継続時間 (3バイトBCD) を秒数に変換する。全ビット1は null。
int? decodeEitDuration(Uint8List bytes) {
  if (bytes.length < 3) return null;
  if (bytes.every((b) => b == 0xFF)) return null;
  final hour = (bytes[0] >> 4) * 10 + (bytes[0] & 0x0F);
  final minute = (bytes[1] >> 4) * 10 + (bytes[1] & 0x0F);
  final second = (bytes[2] >> 4) * 10 + (bytes[2] & 0x0F);
  return hour * 3600 + minute * 60 + second;
}

/// 記述子の基底。タグ番号はARIB STD-B10準拠。
sealed class EitDescriptor {
  const EitDescriptor(this.tag);

  final int tag;
}

/// 短形式イベント記述子 (0x4D)。
class ShortEventDescriptor extends EitDescriptor {
  const ShortEventDescriptor({
    required this.language,
    required this.eventName,
    required this.text,
  }) : super(0x4D);

  final String language;
  final Uint8List eventName;
  final Uint8List text;
}

/// 拡張形式イベントの1項目。
class ExtendedEventItem {
  const ExtendedEventItem({required this.description, required this.item});

  final Uint8List description;
  final Uint8List item;
}

/// 拡張形式イベント記述子 (0x4E)。
class ExtendedEventDescriptor extends EitDescriptor {
  const ExtendedEventDescriptor({
    required this.descriptorNumber,
    required this.lastDescriptorNumber,
    required this.language,
    required this.items,
  }) : super(0x4E);

  final int descriptorNumber;
  final int lastDescriptorNumber;
  final String language;
  final List<ExtendedEventItem> items;
}

/// コンテント記述子 (0x54) の1項目。
class ContentNibble {
  const ContentNibble({
    required this.level1,
    required this.level2,
    required this.userNibble,
  });

  final int level1;
  final int level2;
  final int userNibble;
}

/// コンテント記述子 (0x54)。
class ContentDescriptor extends EitDescriptor {
  const ContentDescriptor(this.contents) : super(0x54);

  final List<ContentNibble> contents;
}

/// コンポーネント記述子 (0x50)。
class ComponentDescriptor extends EitDescriptor {
  const ComponentDescriptor({
    required this.streamContent,
    required this.componentType,
  }) : super(0x50);

  final int streamContent;
  final int componentType;
}

/// 音声コンポーネント記述子 (0xC4)。
class AudioComponentDescriptor extends EitDescriptor {
  const AudioComponentDescriptor({
    required this.componentType,
    required this.mainComponentFlag,
    required this.samplingRate,
    required this.language,
    required this.secondLanguage,
  }) : super(0xC4);

  final int componentType;
  final bool mainComponentFlag;
  final int samplingRate;
  final String language;

  /// デュアルモノ時の副言語。なければ null。
  final String? secondLanguage;
}

/// 未対応の記述子。読み飛ばし用に保持する。
class UnknownDescriptor extends EitDescriptor {
  const UnknownDescriptor(super.tag, this.payload);

  final Uint8List payload;
}

String _languageCode(Uint8List bytes) => String.fromCharCodes(bytes);

/// 記述子ループをパースする。必要な5種のみ型付きで返し、他は捨てる。
List<EitDescriptor> parseDescriptors(Uint8List bytes) {
  final out = <EitDescriptor>[];
  var offset = 0;
  while (offset + 2 <= bytes.length) {
    final tag = bytes[offset];
    final length = bytes[offset + 1];
    if (offset + 2 + length > bytes.length) break;
    final payload = bytes.sublist(offset + 2, offset + 2 + length);
    final descriptor = _parseOne(tag, payload);
    if (descriptor != null) out.add(descriptor);
    offset += 2 + length;
  }
  return out;
}

EitDescriptor? _parseOne(int tag, Uint8List payload) {
  switch (tag) {
    case 0x4D:
      if (payload.length < 4) return null;
      final language = _languageCode(payload.sublist(0, 3));
      final nameLen = payload[3];
      if (4 + nameLen + 1 > payload.length) return null;
      final name = payload.sublist(4, 4 + nameLen);
      final textLen = payload[4 + nameLen];
      if (4 + nameLen + 1 + textLen > payload.length) return null;
      final text = payload.sublist(4 + nameLen + 1, 4 + nameLen + 1 + textLen);
      return ShortEventDescriptor(
        language: language,
        eventName: name,
        text: text,
      );
    case 0x4E:
      if (payload.length < 5) return null;
      final descriptorNumber = (payload[0] >> 4) & 0x0F;
      final lastDescriptorNumber = payload[0] & 0x0F;
      final language = _languageCode(payload.sublist(1, 4));
      final itemsLen = payload[4];
      final items = <ExtendedEventItem>[];
      var p = 5;
      final itemsEnd = p + itemsLen;
      if (itemsEnd > payload.length) return null;
      while (p + 2 <= itemsEnd) {
        final descLen = payload[p];
        if (p + 1 + descLen + 1 > itemsEnd) return null;
        final desc = payload.sublist(p + 1, p + 1 + descLen);
        final itemLen = payload[p + 1 + descLen];
        if (p + 1 + descLen + 1 + itemLen > itemsEnd) return null;
        final item = payload.sublist(
          p + 1 + descLen + 1,
          p + 1 + descLen + 1 + itemLen,
        );
        items.add(ExtendedEventItem(description: desc, item: item));
        p += 1 + descLen + 1 + itemLen;
      }
      return ExtendedEventDescriptor(
        descriptorNumber: descriptorNumber,
        lastDescriptorNumber: lastDescriptorNumber,
        language: language,
        items: items,
      );
    case 0x54:
      final contents = <ContentNibble>[];
      var p = 0;
      while (p + 2 <= payload.length) {
        contents.add(
          ContentNibble(
            level1: (payload[p] >> 4) & 0x0F,
            level2: payload[p] & 0x0F,
            userNibble: payload[p + 1],
          ),
        );
        p += 2;
      }
      return ContentDescriptor(contents);
    case 0x50:
      if (payload.length < 6) return null;
      return ComponentDescriptor(
        streamContent: payload[0] & 0x0F,
        componentType: payload[1],
      );
    case 0xC4:
      if (payload.length < 9) return null;
      final esMulti = (payload[5] & 0x80) != 0;
      final mainFlag = (payload[5] & 0x40) != 0;
      final samplingRate = (payload[5] >> 1) & 0x07;
      final language = _languageCode(payload.sublist(6, 9));
      String? second;
      if (esMulti) {
        if (payload.length < 12) return null;
        second = _languageCode(payload.sublist(9, 12));
      }
      return AudioComponentDescriptor(
        componentType: payload[1],
        mainComponentFlag: mainFlag,
        samplingRate: samplingRate,
        language: language,
        secondLanguage: second,
      );
    default:
      return null;
  }
}

/// EITの1イベント。
class EitEvent {
  const EitEvent({
    required this.eventId,
    required this.startTimeBytes,
    required this.durationBytes,
    required this.freeCaMode,
    required this.descriptors,
  });

  final int eventId;
  final Uint8List startTimeBytes;
  final Uint8List durationBytes;
  final bool freeCaMode;
  final List<EitDescriptor> descriptors;
}

/// EITセクション (EIT[p/f] の1セクション)。
class EitSection {
  const EitSection({
    required this.tableId,
    required this.serviceId,
    required this.versionNumber,
    required this.currentNext,
    required this.sectionNumber,
    required this.transportStreamId,
    required this.originalNetworkId,
    required this.events,
  });

  final int tableId;
  final int serviceId;
  final int versionNumber;
  final bool currentNext;
  final int sectionNumber;
  final int transportStreamId;
  final int originalNetworkId;
  final List<EitEvent> events;
}

/// EITセクションをパースする。CRC不正・形式不正は null を返す。
EitSection? parseEitSection(Uint8List section) {
  if (section.length < 14) return null;
  if (mpeg2CrcRemainder(section) != 0) return null;
  final reader = TsBitReader(section);
  final tableId = reader.uimsbf(8);
  if (tableId != 0x4E && tableId != 0x4F) return null;
  reader.skip(1); // section_syntax_indicator
  reader.skip(1); // reserved_future_use
  reader.skip(2); // reserved
  final sectionLength = reader.uimsbf(12);
  if (section.length < 3 + sectionLength) return null;
  final serviceId = reader.uimsbf(16);
  reader.skip(2);
  final versionNumber = reader.uimsbf(5);
  final currentNext = reader.bslbf(1) == 1;
  final sectionNumber = reader.uimsbf(8);
  reader.uimsbf(8);
  final transportStreamId = reader.uimsbf(16);
  final originalNetworkId = reader.uimsbf(16);
  reader.uimsbf(8);
  reader.uimsbf(8);
  final events = <EitEvent>[];
  final endBits = (3 + sectionLength - 4) * 8;
  while (reader.position + 12 * 8 <= endBits) {
    final eventId = reader.uimsbf(16);
    final startTime = reader.readBytes(5);
    final duration = reader.readBytes(3);
    reader.uimsbf(3);
    final freeCa = reader.bslbf(1) == 1;
    final loopLength = reader.uimsbf(12);
    if (reader.position + loopLength * 8 > endBits) break;
    final loopBytes = reader.readBytes(loopLength);
    events.add(
      EitEvent(
        eventId: eventId,
        startTimeBytes: startTime,
        durationBytes: duration,
        freeCaMode: freeCa,
        descriptors: parseDescriptors(loopBytes),
      ),
    );
  }
  return EitSection(
    tableId: tableId,
    serviceId: serviceId,
    versionNumber: versionNumber,
    currentNext: currentNext,
    sectionNumber: sectionNumber,
    transportStreamId: transportStreamId,
    originalNetworkId: originalNetworkId,
    events: events,
  );
}

/// 188バイトTSパケットからPSIセクションを再構成する。
///
/// [packets] はヘッダー付きTS (`setTsPacketHeader` 済み想定)。
/// 戻り値はPIDごとの完成セクション一覧。PID 0x12以外も含むため、
/// 呼び出し側でEIT[p/f] (`tableId == 0x4E`) に絞ること。
class TsSectionAssembler {
  final Map<int, List<int>> _buffers = {};

  /// [packets] を投入し、完成した `(pid, section)` を返す。
  List<({int pid, Uint8List section})> addPackets(Uint8List packets) {
    final out = <({int pid, Uint8List section})>[];
    for (var offset = 0; offset + 188 <= packets.length; offset += 188) {
      if (packets[offset] != 0x47) continue;
      final pusi = (packets[offset + 1] & 0x40) != 0;
      final pid = ((packets[offset + 1] & 0x1F) << 8) | packets[offset + 2];
      final afc = (packets[offset + 3] >> 4) & 0x03;
      // ペイロード無し (afc=0 は予約値) は無視する。
      if ((afc & 0x01) == 0) continue;
      var payloadStart = offset + 4;
      if ((afc & 0x02) != 0) {
        final adaptationLen = packets[offset + 4];
        payloadStart += 1 + adaptationLen;
      }
      if (payloadStart >= offset + 188) continue;
      final payload = packets.sublist(payloadStart, offset + 188);
      final buffer = _buffers.putIfAbsent(pid, () => <int>[]);
      if (!pusi) {
        buffer.addAll(payload);
        _emitCompleted(out, buffer, pid);
        continue;
      }
      if (payload.isEmpty) continue;
      final pointer = payload[0];
      final nextStart = 1 + pointer;
      if (nextStart > payload.length) continue;
      if (pointer > 0) {
        // pointer_field が示すバイト数は「前セクションの続き」。
        // これを足さないと、複数パケットにまたがるセクションが
        // 次のセクションの開始と同一パケットに入った時点で破棄される。
        // 概要・詳細が長いNHK総合の現在番組がこれで取れなくなる。
        buffer.addAll(payload.sublist(1, nextStart));
        _emitCompleted(out, buffer, pid);
      }
      buffer.clear();
      if (nextStart < payload.length) {
        buffer.addAll(payload.sublist(nextStart));
        _emitCompleted(out, buffer, pid);
      }
    }
    return out;
  }

  /// [buffer] 先頭から完成セクションを取り出す。
  ///
  /// 末尾の 0xFF 詰め (stuffing) はここで打ち切る。
  void _emitCompleted(
    List<({int pid, Uint8List section})> out,
    List<int> buffer,
    int pid,
  ) {
    while (buffer.length >= 3) {
      // table_id 0xFF は stuffing。ariblib `packet.py` と同じくここで打ち切る。
      // 実TSには 0xFF が混ざるので、ここをガードしないと
      // section_length=0xFFF のデジャグセクション诞生して
      // 次のセクションの解析がずれる。
      if (buffer[0] == 0xFF) {
        buffer.clear();
        return;
      }
      final sectionLength = ((buffer[1] & 0x0F) << 8) | buffer[2];
      final total = 3 + sectionLength;
      if (buffer.length < total) break;
      out.add((
        pid: pid,
        section: Uint8List.fromList(buffer.sublist(0, total)),
      ));
      buffer.removeRange(0, total);
    }
  }

  /// 内部バッファを破棄する。
  void reset() => _buffers.clear();
}
