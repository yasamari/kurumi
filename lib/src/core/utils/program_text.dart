/// 番組情報文字列の正規化 (pure 関数)。
///
/// KonomiTV の `ProgramUtils.formatString()` と同等の処理を行う。
/// EIT 由来の生文字列 (全角英数・ARIB 外字の囲み文字など) を、
/// KonomiTV 形式の一律な表現に整える。バックエンド非依存のため、
/// 生文字列を返すバックエンド (Mirakurun など) の表示前に使う。
/// (KonomiTV バックエンドの文字列はサーバー側で正規化済みのため不要)
///
/// 変換内容:
/// - 全角英数→半角英数、全角記号→半角記号 (一部は見栄えのため全角化)
/// - ARIB 外字の Unicode 囲み文字→ `[字]` 形式の大かっこ表記
///
/// ref: https://github.com/tsukumijima/KonomiTV/blob/master/client/src/utils/ProgramUtils.ts
library;

/// 文字列に含まれる英数や記号を半角に置換し、一律な表現に整える。
String formatProgramText(String input) {
  var result = input;
  for (final entry in _translationMap.entries) {
    result = result.replaceAll(entry.key, entry.value);
  }
  return result;
}

/// [formatProgramText] で使う変換マップ。挿入順に適用される。
final Map<String, String> _translationMap =
    buildProgramTextTranslationMap();

/// 変換マップを構築する。
///
/// 可読性のため公開している。内容は KonomiTV の
/// `buildFormatStringTranslationMap()` と同等。
Map<String, String> buildProgramTextTranslationMap() {
  final map = <String, String>{};

  // 全角英数を半角英数に置換。
  for (var i = 0; i < 10; i++) {
    map[String.fromCharCode(0xFF10 + i)] = String.fromCharCode(0x30 + i);
  }
  for (var i = 0; i < 26; i++) {
    map[String.fromCharCode(0xFF21 + i)] = String.fromCharCode(0x41 + i);
    map[String.fromCharCode(0xFF41 + i)] = String.fromCharCode(0x61 + i);
  }

  // 全角記号を半角記号に置換。
  const symbolPairs = [
    ('＂', '"'),
    ('＃', '#'),
    ('＄', r'$'),
    ('％', '%'),
    ('＆', '&'),
    ('＇', "'"),
    ('（', '('),
    ('）', ')'),
    ('＋', '+'),
    ('，', ','),
    ('－', '-'),
    ('．', '.'),
    ('／', '/'),
    ('：', ':'),
    ('；', ';'),
    ('＜', '<'),
    ('＝', '='),
    ('＞', '>'),
    ('［', '['),
    ('＼', r'\'),
    ('］', ']'),
    ('＾', '^'),
    ('＿', '_'),
    ('｀', '`'),
    ('｛', '{'),
    ('｜', '|'),
    ('｝', '}'),
    ('　', ' '),
  ];
  for (final (from, to) in symbolPairs) {
    map[from] = to;
  }

  // 一部の半角記号を全角に置換 (見栄えのため全角の方が字面が良い)。
  map['!'] = '！';
  map['?'] = '？';
  map['*'] = '＊';
  map['~'] = '～';
  // シャープ→ハッシュ。
  map['♯'] = '#';
  // 波ダッシュ→全角チルダ (EDCB に合わせて統一)。
  map['〜'] = '～';

  // 番組表で使用される囲み文字の置換テーブル。
  for (final entry in _enclosedCharactersTableCodePoints.entries) {
    map[String.fromCharCode(entry.key)] = entry.value;
  }

  return map;
}

/// Unicode の囲み文字→大かっこ表記の対応表。
///
/// Mirakurun 3.9.0-beta.24 以降など、番組情報取得元から Unicode の囲み文字が
/// 送られてくる場合に対応するためのもの。文字リテラルの誤記を防ぐため、
/// コードポイントの整数で定義している。
const _enclosedCharactersTableCodePoints = <int, String>{
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
