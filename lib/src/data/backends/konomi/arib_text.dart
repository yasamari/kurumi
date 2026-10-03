import 'dart:typed_data';

import 'package:jis0208/jis0208.dart';

import 'arib_tables.dart';

/// ARIB STD-B24の文字コード種別 (node-aribts `char.ts` の移植)。
abstract final class _CharCode {
  static const hiragana = 0x30;
  static const katakana = 0x31;
  static const propAscii = 0x36;
  static const propHiragana = 0x37;
  static const propKatakana = 0x38;
  static const jisKanji1 = 0x39;
  static const jisKanji2 = 0x3A;
  static const symbol = 0x3B;
  static const kanji = 0x42;
  static const ascii = 0x4A;
  static const jisX0201Katakana = 0x49;
}

abstract final class _CharMode {
  static const graphic = 1;
  static const drcs = 2;
  static const other = 3;
}

/// ARIB文字列 (EITの番組名・概要等) をUnicodeにデコードする。
///
/// node-aribts `TsChar` の移植。DRCS外字は読み飛ばし、JIS互換外字は
/// Unicode変換表で復元する。SJISバイト列の変換には `jis0208` を使う。
String decodeAribText(Uint8List bytes) {
  return _AribDecoder(bytes).decode();
}

class _AribDecoder {
  _AribDecoder(this.buffer);

  final Uint8List buffer;

  int position = 0;
  List<int> graphic = [
    _CharCode.kanji,
    _CharCode.ascii,
    _CharCode.hiragana,
    _CharCode.katakana,
  ];
  List<int> graphicMode = [
    _CharMode.graphic,
    _CharMode.graphic,
    _CharMode.graphic,
    _CharMode.graphic,
  ];
  List<int> graphicByte = [2, 1, 1, 1];
  int graphicL = 0;
  int graphicR = 2;
  bool graphicNormal = true;

  final List<int> sjis = [];
  final StringBuffer result = StringBuffer();

  String decode() {
    try {
      while (position < buffer.length) {
        final byte = buffer[position];
        if (byte <= 0x20) {
          _readC0();
        } else if (byte <= 0x7E) {
          _readGL();
        } else if (byte <= 0xA0) {
          _readC1();
        } else if (byte != 0xFF) {
          _readGR();
        } else {
          position++;
        }
      }
    } on StateError {
      // バッファ終端・未知コードはここで打ち切る (参照実装と同等)。
    }
    _flushSjis();
    return result.toString();
  }

  void _flushSjis() {
    if (sjis.isEmpty) return;
    result.write(
      Windows31JDecoder(allowMalformed: true).convert(sjis),
    );
    sjis.clear();
  }

  int _getNext() {
    if (position >= buffer.length) throw StateError('終端に達しました');
    return buffer[position++];
  }

  void _readC0() {
    switch (_getNext()) {
      case 0x20:
        if (graphicNormal) {
          sjis.addAll([0x81, 0x40]);
        } else {
          sjis.add(0x20);
        }
        break;
      case 0x0D:
        sjis.addAll([0x0D, 0x0A]);
        break;
      case 0x0E:
        graphicL = 1;
        break;
      case 0x0F:
        graphicL = 0;
        break;
      case 0x19:
        _readSS2();
        break;
      case 0x1D:
        _readSS3();
        break;
      case 0x1B:
        _readESC();
        break;
      case 0x16:
        position += 1;
        break;
      case 0x1C:
        position += 2;
        break;
    }
  }

  void _readC1() {
    switch (_getNext()) {
      case 0x89:
        graphicNormal = false;
        break;
      case 0x8A:
        graphicNormal = true;
        break;
      case 0x88:
        graphicNormal = false;
        break;
      case 0x8B:
        graphicNormal = _getNext() != 0x60;
        break;
      case 0x90:
        if (_getNext() == 0x20) position += 1;
        break;
      case 0x91:
        position += 1;
        break;
      case 0x93:
        position += 1;
        break;
      case 0x94:
        position += 1;
        break;
      case 0x95:
        while (position < buffer.length && buffer[position] != 0x4F) {
          position++;
        }
        break;
      case 0x97:
        position += 1;
        break;
      case 0x98:
        position += 1;
        break;
      case 0x9D:
        if (_getNext() == 0x20) {
          position += 1;
        } else {
          while (position < buffer.length &&
              buffer[position] < 0x40 &&
              buffer[position] > 0x43) {
            position++;
          }
        }
        break;
      case 0x9B:
        _readCSI();
        break;
    }
  }

  void _readGL() {
    if (graphicMode[graphicL] != _CharMode.graphic) {
      position += graphicByte[graphicL];
      return;
    }
    switch (graphic[graphicL]) {
      case _CharCode.propAscii:
      case _CharCode.ascii:
      case _CharCode.jisX0201Katakana:
        final mapped = aribAscii[_getNext()];
        if (mapped == null) throw StateError('未知のASCIIコードです');
        if (graphicNormal) {
          sjis.addAll(mapped);
        } else {
          sjis.add(buffer[position - 1]);
        }
        break;
      case _CharCode.hiragana:
      case _CharCode.propHiragana:
        final mapped = aribHiragana[_getNext()];
        if (mapped == null) throw StateError('未知のひらがなコードです');
        sjis.addAll(mapped);
        break;
      case _CharCode.katakana:
      case _CharCode.propKatakana:
        final mapped = aribKatakana[_getNext()];
        if (mapped == null) throw StateError('未知のカタカナコードです');
        sjis.addAll(mapped);
        break;
      case _CharCode.jisKanji1:
      case _CharCode.jisKanji2:
      case _CharCode.symbol:
      case _CharCode.kanji:
        final first = _getNext();
        final second = _getNext();
        if (_useUnicode(first, second)) {
          _flushSjis();
          result.write(_getUnicode(first, second));
        } else {
          sjis.addAll(_getSjis(first, second));
        }
        break;
    }
  }

  void _readGR() {
    if (graphicMode[graphicR] != _CharMode.graphic) {
      position += graphicByte[graphicR];
      return;
    }
    switch (graphic[graphicR]) {
      case _CharCode.propAscii:
      case _CharCode.ascii:
        final code = _getNext() & 0x7F;
        final mapped = aribAscii[code];
        if (mapped == null) throw StateError('未知のASCIIコードです');
        if (graphicNormal) {
          sjis.addAll(mapped);
        } else {
          sjis.add(code);
        }
        break;
      case _CharCode.hiragana:
      case _CharCode.propHiragana:
        final code = _getNext() & 0x7F;
        final mapped = aribHiragana[code];
        if (mapped == null) throw StateError('未知のひらがなコードです');
        sjis.addAll(mapped);
        break;
      case _CharCode.katakana:
      case _CharCode.propKatakana:
      case _CharCode.jisX0201Katakana:
        final code = _getNext() & 0x7F;
        final mapped = aribKatakana[code];
        if (mapped == null) throw StateError('未知のカタカナコードです');
        sjis.addAll(mapped);
        break;
      case _CharCode.jisKanji1:
      case _CharCode.jisKanji2:
      case _CharCode.symbol:
      case _CharCode.kanji:
        final first = _getNext() & 0x7F;
        final second = _getNext() & 0x7F;
        if (_useUnicode(first, second)) {
          _flushSjis();
          result.write(_getUnicode(first, second));
        } else {
          sjis.addAll(_getSjis(first, second));
        }
        break;
    }
  }

  void _readESC() {
    final byte = _getNext();
    if (byte == 0x24) {
      final byte2 = _getNext();
      if (byte2 >= 0x28 && byte2 <= 0x2B) {
        final byte3 = _getNext();
        if (byte3 == 0x20) {
          final byte4 = _getNext();
          graphic[byte2 - 0x28] = byte4;
          graphicMode[byte2 - 0x28] = _CharMode.drcs;
          graphicByte[byte2 - 0x28] = 2;
        } else if (byte3 == 0x28) {
          final byte4 = _getNext();
          graphic[byte2 - 0x28] = byte4;
          graphicMode[byte2 - 0x28] = _CharMode.other;
          graphicByte[byte2 - 0x28] = 1;
        } else {
          graphic[byte2 - 0x28] = byte3;
          graphicMode[byte2 - 0x28] = _CharMode.graphic;
          graphicByte[byte2 - 0x28] = 2;
        }
      } else {
        graphic[0] = byte2;
        graphicMode[0] = _CharMode.graphic;
        graphicByte[0] = 2;
      }
    } else if (byte >= 0x28 && byte <= 0x2B) {
      final byte2 = _getNext();
      if (byte2 == 0x20) {
        final byte3 = _getNext();
        graphic[byte - 0x28] = byte3;
        graphicMode[byte - 0x28] = _CharMode.drcs;
        graphicByte[byte - 0x28] = 1;
      } else {
        graphic[byte - 0x28] = byte2;
        graphicMode[byte - 0x28] = _CharMode.graphic;
        graphicByte[byte - 0x28] = 1;
      }
    } else if (byte == 0x6E) {
      graphicL = 2;
    } else if (byte == 0x6F) {
      graphicL = 3;
    } else if (byte == 0x7C) {
      graphicR = 3;
    } else if (byte == 0x7D) {
      graphicR = 2;
    } else if (byte == 0x7E) {
      graphicR = 1;
    }
  }

  void _readSS2() {
    final holdL = graphicL;
    graphicL = 2;
    _readGL();
    graphicL = holdL;
  }

  void _readSS3() {
    final holdL = graphicL;
    graphicL = 3;
    _readGL();
    graphicL = holdL;
  }

  void _readCSI() {
    // TODO (参照実装も未実装)
  }

  bool _useUnicode(int first, int second) {
    if (first >= 0x75 && second >= 0x21) {
      final code = (first << 8) | second;
      if (code >= 0x7521 && code <= 0x764B) return true;
      if (code >= 0x7A4D && code <= 0x7E7D) return true;
      return false;
    }
    return false;
  }

  List<int> _getSjis(int first, int second) {
    if (first >= 0x75 && second >= 0x21) {
      final code = (first << 8) | second;
      if (code >= 0x7521 && code <= 0x764B) {
        return aribGaiji2[code] ?? const [];
      } else if (code >= 0x7A4D && code <= 0x7E7D) {
        return aribGaiji1[code] ?? const [];
      }
      return const [];
    }
    final row = first < 0x5F ? 0x70 : 0xB0;
    final cell = (first & 1) != 0
        ? (second > 0x5F ? 0x20 : 0x1F)
        : 0x7E;
    first = (((first + 1) >> 1) + row) & 0xFF;
    second = (second + cell) & 0xFF;
    return [first, second];
  }

  String _getUnicode(int first, int second) {
    if (first >= 0x75 && second >= 0x21) {
      final code = (first << 8) | second;
      if (code >= 0x7521 && code <= 0x764B) {
        return aribGaiji2Unicode[code] ?? '';
      } else if (code >= 0x7A4D && code <= 0x7E7D) {
        return aribGaiji1Unicode[code] ?? '';
      }
      return '';
    }
    return '';
  }
}
