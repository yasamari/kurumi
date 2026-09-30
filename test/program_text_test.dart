import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/core/utils/program_text.dart';

/// 囲み文字テーブルの全件検証。
///
/// KonomiTV `ProgramUtils` の `enclosed_characters_table` との対応表。
/// コードポイントを整数で指定し、実装側の文字リテラルの誤記を検出する。
const _enclosedCases = <int, String>{
  0x1F14A: '[HV]',
  0x1F13F: '[P]',
  0x1F14C: '[SD]',
  0x1F146: '[W]',
  0x1F14B: '[MV]',
  0x1F210: '[手]',
  0x1F211: '[字]',
  0x1F212: '[双]',
  0x1F213: '[デ]',
  0x1F142: '[S]',
  0x1F214: '[二]',
  0x1F215: '[多]',
  0x1F216: '[解]',
  0x1F14D: '[SS]',
  0x1F131: '[B]',
  0x1F13D: '[N]',
  0x1F217: '[天]',
  0x1F218: '[交]',
  0x1F219: '[映]',
  0x1F21A: '[無]',
  0x1F21B: '[料]',
  0x1F21C: '[前]',
  0x1F21D: '[後]',
  0x1F21E: '[再]',
  0x1F21F: '[新]',
  0x1F220: '[初]',
  0x1F221: '[終]',
  0x1F222: '[生]',
  0x1F223: '[販]',
  0x1F224: '[声]',
  0x1F225: '[吹]',
  0x1F14E: '[PPV]',
  0x1F200: '[ほか]',
  0x1F19B: '[3D]',
  0x1F19C: '[2ndScr]',
  0x1F19D: '[2K]',
  0x1F19E: '[4K]',
  0x1F19F: '[8K]',
  0x1F1A0: '[5.1]',
  0x1F1A1: '[7.1]',
  0x1F1A2: '[22.2]',
  0x1F1A3: '[60P]',
  0x1F1A4: '[120P]',
  0x1F1A5: '[d]',
  0x1F1A6: '[HC]',
  0x1F1A7: '[HDR]',
  0x1F1A8: '[Hi-Res]',
  0x1F1A9: '[Lossless]',
  0x1F1AA: '[SHV]',
  0x1F1AB: '[UHD]',
  0x1F1AC: '[VOD]',
  0x1F23B: '[配]',
};

void main() {
  test('全角英数・記号を半角に置換する', () {
    expect(formatProgramText('ＡＢＣ１２３'), 'ABC123');
    expect(formatProgramText('ａｂｃ'), 'abc');
    expect(formatProgramText('（）［］　'), '()[] ');
  });

  test('見栄えのため一部は全角・別文字に置換する', () {
    expect(formatProgramText('本当!?'), '本当！？');
    expect(formatProgramText('第１話*再'), '第1話＊再');
    expect(formatProgramText('12:00~13:00'), '12:00～13:00');
    expect(formatProgramText('概要〜詳細'), '概要～詳細');
    expect(formatProgramText('♯１'), '#1');
  });

  test('ARIB外字の囲み文字を大かっこ表記に置換する', () {
    // コードポイント指定で検証し、変換テーブルの誤記を検出する。
    String enclosed(int codePoint) => String.fromCharCode(codePoint);
    expect(formatProgramText(enclosed(0x1F211)), '[字]');
    expect(
      formatProgramText('${enclosed(0x1F21F)}${enclosed(0x1F21E)}'),
      '[新][再]',
    );
    expect(
      formatProgramText('${enclosed(0x1F19E)}${enclosed(0x1F19F)}'),
      '[4K][8K]',
    );
    expect(formatProgramText(enclosed(0x1F23B)), '[配]');
  });

  test('囲み文字テーブルがKonomiTVと一致する', () {
    for (final entry in _enclosedCases.entries) {
      expect(
        formatProgramText(String.fromCharCode(entry.key)),
        entry.value,
        reason: 'U+${entry.key.toRadixString(16).toUpperCase()} の変換が不正',
      );
    }
  });

  test('通常の日本語は変えない', () {
    const text = 'ニュース・報道 テスト太郎 １月１日';
    expect(formatProgramText(text), 'ニュース・報道 テスト太郎 1月1日');
  });

  test('文字列を通常文と記号に分割する', () {
    final segments = parseProgramTextSymbols('[新]ドラマ[字][解]再放送');
    expect(segments, [
      (text: '新', isSymbol: true),
      (text: 'ドラマ', isSymbol: false),
      (text: '字', isSymbol: true),
      (text: '解', isSymbol: true),
      (text: '再放送', isSymbol: false),
    ]);
  });

  test('空かっこや閉じていないかっこは記号にしない', () {
    final segments = parseProgramTextSymbols('[]未定[字');
    expect(segments, [
      (text: '[]未定[字', isSymbol: false),
    ]);
  });

  test('記号なし・空文字は通常文のまま', () {
    expect(parseProgramTextSymbols('ニュース'), [
      (text: 'ニュース', isSymbol: false),
    ]);
    expect(parseProgramTextSymbols(''), isEmpty);
  });
}
