/// ニコニコ実況チャンネル ID (`jk1` 等) と MPEG-TS の network_id/service_id の対応表。
///
/// NX-Jikkyo は実況チャンネルを `jk1`…`jk992` の固定 ID でしか認識せず、
/// Mirakurun の `service_id`/`network_id` も KonomiTV の `display_channel_id` も
/// 持たない。両バックエンドが共通して持つ network_id + service_id だけが
/// 共通キーで、NX-Jikkyo の ID へ変換するには対応表が要る。
///
/// 表は KonomiTV の `server/static/jikkyo_channels.json` (362行) より移植。
/// うち4組が同じ (network_id, service_id) を共有しているため、キー数は358。
/// 重複組はどれも `jk` ID が同一なので畳んでも解決結果は変わらない。
/// 判定ロジックも KonomiTV の `server/app/utils/JikkyoClient.py` に合わせている。
/// ref: https://github.com/tsukumijima/KonomiTV/blob/master/server/app/utils/JikkyoClient.py
///
/// 地上波の network_id は実 NID では 0x7880〜0x7FEF だが、表内では番線値 15 に
/// 束ねられている (`JikkyoClient.match()` と同じ理由)。そのため地上波では
/// service_id を `sid`, `sid - 1`, `sid - 2` の順に引いて接地する必要がある
/// (1つ前の SID を持つチャンネルがNHK総合2・東京のように実在する)。
///
/// なお地上波の判定は network_id の範囲ではなく [ChannelType] で行う。CATV の
/// network_id (代表値は 0x7CA0) が地上波の範囲に数値的に含まれうるため、
/// 種別で判別するしかない。
library;

import '../../domain/entities/channel_type.dart';

/// 地上波 (network_id 15 に束ねられたもの) の service_id → 実況チャンネル ID。
///
/// `jikkyo_id: -1` のエントリ (実況非対応: 群馬テレビなど) も `null` として
/// 保持する。落としてしまうと sid-1/sid-2 のフォールバックが別地域の SID に
/// マッチして誤検出するため。KonomiTV も同じく `-1` エントリ的一致では
/// return せず次の候補へ進む。
const _terrestrialByServiceId = <int, String?>{
  1024: 'jk1',
  1032: 'jk2',
  1040: 'jk4',
  1048: 'jk6',
  1056: 'jk8',
  1064: 'jk5',
  1072: 'jk7',
  2056: 'jk2',
  2064: 'jk6',
  2072: 'jk5',
  2080: 'jk8',
  2088: 'jk4',
  3080: 'jk2',
  3088: 'jk8',
  3096: 'jk6',
  3104: 'jk5',
  3112: 'jk4',
  4112: 'jk6',
  4120: 'jk4',
  4128: 'jk5',
  4136: 'jk8',
  4144: 'jk7',
  5136: 'jk4',
  5144: 'jk5',
  5152: 'jk6',
  5160: 'jk7',
  5168: 'jk8',
  6160: 'jk8',
  6168: 'jk6',
  6176: 'jk4',
  10240: 'jk1',
  10248: 'jk2',
  10256: 'jk6',
  10264: 'jk4',
  10272: 'jk5',
  10280: 'jk8',
  10288: 'jk7',
  11264: 'jk1',
  11272: 'jk2',
  11280: 'jk6',
  11288: 'jk4',
  11296: 'jk5',
  11304: 'jk8',
  11312: 'jk7',
  12288: 'jk1',
  12296: 'jk2',
  12304: 'jk6',
  12312: 'jk4',
  12320: 'jk5',
  12328: 'jk8',
  12336: 'jk7',
  13312: 'jk1',
  13320: 'jk2',
  13328: 'jk6',
  13336: 'jk4',
  13344: 'jk5',
  13352: 'jk8',
  13360: 'jk7',
  14336: 'jk1',
  14344: 'jk2',
  14352: 'jk6',
  14360: 'jk4',
  14368: 'jk5',
  14376: 'jk8',
  14384: 'jk7',
  15360: 'jk1',
  15368: 'jk2',
  15376: 'jk6',
  15384: 'jk4',
  15392: 'jk5',
  15400: 'jk8',
  15408: 'jk7',
  16384: 'jk1',
  16392: 'jk2',
  16400: 'jk6',
  16408: 'jk4',
  16416: 'jk5',
  16424: 'jk8',
  16432: 'jk7',
  17408: 'jk1',
  17416: 'jk2',
  17424: 'jk6',
  17432: 'jk8',
  17440: 'jk4',
  17448: 'jk5',
  18432: 'jk1',
  18440: 'jk2',
  18448: 'jk4',
  18456: 'jk8',
  18464: 'jk5',
  19456: 'jk1',
  19464: 'jk2',
  19472: 'jk4',
  19480: 'jk5',
  19488: 'jk6',
  19496: 'jk8',
  20480: 'jk1',
  20488: 'jk2',
  20496: 'jk6',
  20504: 'jk4',
  20512: 'jk8',
  20520: 'jk5',
  21504: 'jk1',
  21512: 'jk2',
  21520: 'jk8',
  21528: 'jk4',
  21536: 'jk5',
  21544: 'jk6',
  22528: 'jk1',
  22536: 'jk2',
  22544: 'jk4',
  22552: 'jk6',
  22560: 'jk5',
  23608: 'jk9',
  23610: 'jk9',
  24632: 'jk11',
  25600: 'jk1',
  25656: null,
  26624: 'jk1',
  27704: 'jk12',
  28672: 'jk1',
  28728: null,
  29752: 'jk10',
  30720: 'jk1',
  30728: 'jk2',
  30736: 'jk4',
  30744: 'jk5',
  30752: 'jk6',
  30760: 'jk8',
  31744: 'jk1',
  31752: 'jk2',
  31760: 'jk6',
  31768: 'jk8',
  31776: 'jk4',
  31784: 'jk5',
  32768: 'jk1',
  32776: 'jk2',
  32784: 'jk4',
  32792: 'jk6',
  33792: 'jk1',
  33840: 'jk7',
  34816: 'jk1',
  34824: 'jk2',
  34832: 'jk4',
  34840: 'jk5',
  34848: 'jk6',
  34856: 'jk8',
  35840: 'jk1',
  35848: 'jk2',
  35856: 'jk6',
  35864: 'jk8',
  35872: 'jk4',
  35880: 'jk5',
  36864: 'jk1',
  36872: 'jk2',
  36880: 'jk4',
  36888: 'jk8',
  37888: 'jk1',
  37896: 'jk2',
  37904: 'jk4',
  37912: 'jk8',
  37920: 'jk6',
  38912: 'jk1',
  38960: null,
  39936: 'jk1',
  39984: null,
  40960: 'jk1',
  41008: 'jk7',
  41984: 'jk1',
  42032: 'jk14',
  43008: 'jk1',
  43056: 'jk13',
  44032: 'jk1',
  44080: null,
  45056: 'jk1',
  45104: null,
  46080: 'jk1',
  46128: null,
  47104: 'jk1',
  47112: 'jk2',
  47120: 'jk6',
  47128: 'jk4',
  47136: 'jk5',
  47144: 'jk8',
  48128: 'jk1',
  48136: 'jk2',
  49152: 'jk1',
  49160: 'jk2',
  50176: 'jk1',
  50184: 'jk2',
  51200: 'jk1',
  51208: 'jk2',
  51216: 'jk4',
  51224: 'jk6',
  51232: 'jk5',
  52224: 'jk1',
  52232: 'jk2',
  52240: 'jk4',
  52248: 'jk5',
  52256: 'jk6',
  52264: 'jk8',
  53248: 'jk1',
  53256: 'jk2',
  54272: 'jk1',
  54280: 'jk2',
  54288: 'jk4',
  55296: 'jk1',
  55304: 'jk2',
  55312: 'jk4',
  55320: 'jk6',
  55328: 'jk8',
  56320: 'jk1',
  56832: 'jk1',
  56328: 'jk2',
  56840: 'jk2',
  56336: 'jk5',
  56344: 'jk6',
  56352: 'jk4',
  56360: 'jk7',
  56368: 'jk8',
  57344: 'jk1',
  57352: 'jk2',
  57360: 'jk6',
  57368: 'jk8',
  57376: 'jk4',
  57384: 'jk5',
  58368: 'jk1',
  58376: 'jk2',
  58384: 'jk6',
  58392: 'jk8',
  58400: 'jk5',
  58408: 'jk4',
  59392: 'jk1',
  59400: 'jk2',
  59408: 'jk6',
  59416: 'jk8',
  59424: 'jk5',
  59432: 'jk4',
  60416: 'jk1',
  60424: 'jk2',
  60432: 'jk6',
  60440: 'jk8',
  61440: 'jk1',
  61448: 'jk2',
  61456: 'jk6',
  61464: 'jk4',
  61472: 'jk5',
  62464: 'jk1',
  62472: 'jk2',
  62480: 'jk8',
  63488: 'jk1',
  63496: 'jk2',
  63504: 'jk6',
  63520: 'jk5',
  63544: 'jk8',
};

/// 地上波以外の (network_id, service_id) → 実況チャンネル ID。
const _byNetworkService = <(int, int), String?>{
  (4, 101): 'jk101',
  (4, 102): 'jk101',
  (4, 103): 'jk103',
  (4, 104): 'jk103',
  (4, 141): 'jk141',
  (4, 142): 'jk141',
  (4, 143): 'jk141',
  (4, 151): 'jk151',
  (4, 152): 'jk151',
  (4, 153): 'jk151',
  (4, 161): 'jk161',
  (4, 162): 'jk161',
  (4, 163): 'jk161',
  (4, 171): 'jk171',
  (4, 172): 'jk171',
  (4, 173): 'jk171',
  (4, 181): 'jk181',
  (4, 182): 'jk181',
  (4, 183): 'jk181',
  (4, 191): 'jk191',
  (4, 192): 'jk192',
  (4, 193): 'jk193',
  (4, 200): 'jk200',
  (4, 201): 'jk201',
  (4, 202): 'jk202',
  (4, 211): 'jk211',
  (4, 222): 'jk222',
  (4, 231): 'jk231',
  (4, 232): 'jk231',
  (4, 234): 'jk234',
  (4, 236): 'jk236',
  (4, 241): 'jk241',
  (4, 242): 'jk242',
  (4, 243): 'jk243',
  (4, 244): 'jk244',
  (4, 245): 'jk245',
  (4, 251): 'jk251',
  (4, 252): 'jk252',
  (4, 255): 'jk255',
  (4, 256): 'jk256',
  (4, 260): 'jk260',
  (4, 263): 'jk200',
  (4, 265): 'jk265',
  (11, 101): 'jk103',
  (11, 141): 'jk141',
  (11, 151): 'jk151',
  (11, 161): 'jk161',
  (11, 171): 'jk171',
  (11, 181): 'jk181',
  (6, 55): null,
  (7, 161): null,
  (6, 218): null,
  (6, 219): null,
  (7, 223): null,
  (7, 227): null,
  (7, 240): null,
  (7, 250): null,
  (7, 254): null,
  (7, 257): null,
  (7, 262): null,
  (7, 290): null,
  (7, 292): null,
  (7, 293): null,
  (7, 294): null,
  (7, 295): null,
  (6, 296): null,
  (7, 297): null,
  (6, 298): null,
  (6, 299): null,
  (7, 300): null,
  (7, 301): null,
  (7, 305): null,
  (7, 307): null,
  (7, 308): null,
  (7, 309): null,
  (7, 310): null,
  (7, 311): null,
  (7, 312): null,
  (7, 314): null,
  (7, 316): null,
  (6, 317): null,
  (6, 318): null,
  (7, 321): null,
  (7, 322): null,
  (7, 323): null,
  (7, 324): null,
  (7, 325): null,
  (7, 329): null,
  (7, 330): null,
  (7, 331): null,
  (7, 333): 'jk333',
  (6, 339): null,
  (7, 340): null,
  (7, 341): null,
  (7, 342): null,
  (7, 343): null,
  (6, 349): null,
  (7, 351): null,
  (7, 353): null,
  (7, 354): null,
  (7, 363): null,
  (6, 800): null,
  (6, 801): null,
};

/// NX-Jikkyo が実況チャンネルとして認識する ID 全体。
///
/// 表には現在存在しない実況チャンネルの ID (例: `jk256`) も残るが、NX-Jikkyo は
/// 視聴セッションの接続時に 1008 で拒否する。接続先と突き合わせて必ず除外する。
/// 出典: NX-Jikkyo `server/app/constants.py` の `MASTER_CHANNEL_INFOS`、および
/// そこから機械生成される `KNOWN_JIKKYO_CHANNEL_IDS`。
const _knownJikkyoChannelIds = <String>{
  'jk1', 'jk2', 'jk4', 'jk5', 'jk6', 'jk7', 'jk8', 'jk9', 'jk10', 'jk11',
  'jk12', 'jk13', 'jk14', 'jk101', 'jk103', 'jk141', 'jk151', 'jk161',
  'jk171', 'jk181', 'jk191', 'jk192', 'jk193', 'jk200', 'jk201', 'jk211',
  'jk222', 'jk236', 'jk252', 'jk260', 'jk263', 'jk265', 'jk333', 'jk991',
  'jk992',
};

/// 地上波で何個前 (PID) まで辿って探すかの深さ。
///
/// NHK系列は `NHK総合1・東京` / `NHK総合2・東京` のように同じ放送局に SID が
/// 複数割り当てられており、いずれも同じ実況チャンネルに対応する。
const _terrestrialFallbackDepth = 2;

/// チャンネルの種別と MPEG-TS network_id / service_id から実況チャンネル ID を
/// 解決する。
///
/// 対応するニコニコ実況チャンネルが存在しない場合は null を返す。該当するのは
/// 実況非対応チャンネル (群馬テレビなど)、CATV・SKY、そして表には載っているが
/// NX-Jikkyo に登録が無い ID (jk256 など) である。
///
/// CATV と同等の network_id を持つ地上波があるため、NID の数値だけでは地上波と
/// 区別できず、[channelType] で判別する。
/// 引数化しているため単体テストしやすい。
String? resolveJikkyoChannelId({
  required ChannelType channelType,
  required int networkId,
  required int serviceId,
}) {
  // CATV・SKY・BS4K と同じ NID を持つ地上波があるため、NID の範囲だけでは
  // 地上波と判別できない。種別で決める。
  if (channelType == const ChannelType.gr()) {
    // 地上波は表内で番線値 15 に束ねられているため、network_id を捨てて
    // service_id だけで引く。
    for (var offset = 0; offset <= _terrestrialFallbackDepth; offset++) {
      final key = serviceId - offset;
      if (!_terrestrialByServiceId.containsKey(key)) continue;
      // 表に `null` として入っている = 実非対応。次の候補へ進む。
      final candidate = _terrestrialByServiceId[key];
      if (candidate == null) continue;
      return _knownJikkyoChannelIds.contains(candidate) ? candidate : null;
    }
    return null;
  }

  // CATV・SKY には実況チャンネル自体が存在しない。
  if (channelType == const ChannelType.catv() ||
      channelType == const ChannelType.sky() ||
      channelType == const ChannelType.unknown()) {
    return null;
  }

  // BS・CS・BS4K は network_id + service_id の一致だけで決まる。
  final key = (networkId, serviceId);
  if (!_byNetworkService.containsKey(key)) return null;
  final candidate = _byNetworkService[key];
  if (candidate == null) return null;
  return _knownJikkyoChannelIds.contains(candidate) ? candidate : null;
}

/// NX-Jikkyo の表で実況チャンネルとして登録されている ID のみを返す。
///
/// 対応表の解決結果を接続可能な ID に絞るため内部で使う。
bool isKnownJikkyoChannelId(String id) => _knownJikkyoChannelIds.contains(id);
