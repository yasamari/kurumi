import 'dart:typed_data';

import '../../../core/utils/program_text.dart';
import '../../../domain/entities/tv_program.dart';
import 'arib_text.dart';
import 'eit.dart';

/// 番組開始時刻が未定のときに使う基準値 (KonomiTVの `IProgramDefault` と同等)。
///
/// `2000-01-01T00:00:00+09:00` を絶対時刻で表したもの。
final DateTime liveProgramEmptyStart = DateTime.utc(1999, 12, 31, 15, 0, 0);

/// タイトル欠落時に使う文言 (KonomiTV Webと同文)。
const _missingTitle = '番組情報がありません';

/// 概要欠落時に使う文言 (KonomiTV Webと同文)。
const _missingDescription = 'この時間の番組情報を取得できませんでした。';

/// EIT[p/f]セクションが情報パネル対象かを判定する。
///
/// KonomiTV `generateIProgramFromEPG` のガード部と同等:
/// current/next指示があり、イベントが1件で、NID/SIDが一致する。
bool isLiveEitSection(
  EitSection eit, {
  required int networkId,
  required int serviceId,
}) {
  if (!eit.currentNext) return false;
  if (eit.tableId != 0x4E) return false;
  if (eit.events.length != 1) return false;
  if (eit.originalNetworkId != networkId) return false;
  if (eit.serviceId != serviceId) return false;
  return true;
}

/// EIT[p/f]の1セクションから [TvProgram] を組み立てる。
///
/// 対象外セクションは null を返す ([isLiveEitSection] 参照)。
/// 映像・音声情報は [TvProgram] に載せないため読み捨てる。
/// 詳細の組み立て・ジャンル表はKonomiTV Webと同等。
/// 文字列整形は [formatProgramText] を使う。
TvProgram? buildLiveTvProgram(
  EitSection eit, {
  required int networkId,
  required int serviceId,
}) {
  if (!isLiveEitSection(eit, networkId: networkId, serviceId: serviceId)) {
    return null;
  }
  final event = eit.events.single;

  final startAt = decodeEitStartTime(event.startTimeBytes);
  final durationSecs = decodeEitDuration(event.durationBytes);
  final start = startAt ?? liveProgramEmptyStart;
  final end = durationSecs == null ? start : start.add(
    Duration(seconds: durationSecs),
  );

  final shorts = event.descriptors.whereType<ShortEventDescriptor>().toList();
  final extendeds = event.descriptors
      .whereType<ExtendedEventDescriptor>()
      .toList();
  final contents = event.descriptors.whereType<ContentDescriptor>().toList();

  var title = _missingTitle;
  var description = _missingDescription;
  if (shorts.isNotEmpty) {
    title = formatProgramText(decodeAribText(shorts.first.eventName));
    description = formatProgramText(decodeAribText(shorts.first.text));
    if (title.isEmpty) title = _missingTitle;
  }

  final detail = <String, String>{};
  final detailParts = <({String head, Uint8List raw})>[];
  for (final descriptor in extendeds) {
    for (final item in descriptor.items) {
      if (item.description.isEmpty) {
        if (detailParts.isEmpty) {
          detailParts.add((head: '', raw: item.item));
        } else {
          final last = detailParts.last;
          final merged = Uint8List(last.raw.length + item.item.length)
            ..setRange(0, last.raw.length, last.raw)
            ..setRange(last.raw.length, last.raw.length + item.item.length, item.item);
          detailParts[detailParts.length - 1] = (head: last.head, raw: merged);
        }
      } else {
        var head = formatProgramText(decodeAribText(item.description));
        final original = head;
        var suffix = '';
        while (detailParts.any((d) => d.head == original + suffix)) {
          suffix += '\t';
        }
        head += suffix;
        detailParts.add((head: head, raw: item.item));
      }
    }
  }
  for (final part in detailParts) {
    var head = part.head.replaceAll('◇', '').replaceAll(
      RegExp(r'[ \r\n]+'),
      '',
    );
    if (head.isEmpty) head = '番組内容';
    while (detail.containsKey(head)) {
      head += '\t';
    }
    final body = formatProgramText(decodeAribText(part.raw)).trim();
    if (description.trim().isEmpty) description = body;
    detail[head] = body;
  }
  if (title.isEmpty) title = _missingTitle;

  final genres = <String>[];
  for (final descriptor in contents) {
    for (final content in descriptor.contents) {
      final major = _contentMajor[content.level1];
      if (major == null) continue;
      var middle = _contentMiddle[content.level1]?[content.level2] ?? '未定義';
      if (major == '拡張') {
        if (middle == 'BS/地上デジタル放送用番組付属情報') {
          middle = _userType[content.userNibble] ?? '未定義';
        } else {
          continue;
        }
      }
      final label = middle.isEmpty || middle == major ? major : '$major・$middle';
      if (label.isEmpty || genres.contains(label)) continue;
      genres.add(label);
    }
  }

  return TvProgram(
    eventId: event.eventId,
    title: title,
    description: description,
    startAt: start,
    endAt: end,
    genres: genres,
    detail: detail,
  );
}

/// コンテント記述子の大分類 (KonomiTV `ProgramUtils.CONTENT_TYPE` と同等)。
const Map<int, String> _contentMajor = {
  0x0: 'ニュース・報道',
  0x1: 'スポーツ',
  0x2: '情報・ワイドショー',
  0x3: 'ドラマ',
  0x4: '音楽',
  0x5: 'バラエティ',
  0x6: '映画',
  0x7: 'アニメ・特撮',
  0x8: 'ドキュメンタリー・教養',
  0x9: '劇場・公演',
  0xA: '趣味・教育',
  0xB: '福祉',
  0xE: '拡張',
  0xF: 'その他',
};

/// コンテント記述子の中分類。
const Map<int, Map<int, String>> _contentMiddle = {
  0x0: {
    0x0: '定時・総合',
    0x1: '天気',
    0x2: '特集・ドキュメント',
    0x3: '政治・国会',
    0x4: '経済・市況',
    0x5: '海外・国際',
    0x6: '解説',
    0x7: '討論・会談',
    0x8: '報道特番',
    0x9: 'ローカル・地域',
    0xA: '交通',
    0xF: 'その他',
  },
  0x1: {
    0x0: 'スポーツニュース',
    0x1: '野球',
    0x2: 'サッカー',
    0x3: 'ゴルフ',
    0x4: 'その他の球技',
    0x5: '相撲・格闘技',
    0x6: 'オリンピック・国際大会',
    0x7: 'マラソン・陸上・水泳',
    0x8: 'モータースポーツ',
    0x9: 'マリン・ウィンタースポーツ',
    0xA: '競馬・公営競技',
    0xF: 'その他',
  },
  0x2: {
    0x0: '芸能・ワイドショー',
    0x1: 'ファッション',
    0x2: '暮らし・住まい',
    0x3: '健康・医療',
    0x4: 'ショッピング・通販',
    0x5: 'グルメ・料理',
    0x6: 'イベント',
    0x7: '番組紹介・お知らせ',
    0xF: 'その他',
  },
  0x3: {
    0x0: '国内ドラマ',
    0x1: '海外ドラマ',
    0x2: '時代劇',
    0xF: 'その他',
  },
  0x4: {
    0x0: '国内ロック・ポップス',
    0x1: '海外ロック・ポップス',
    0x2: 'クラシック・オペラ',
    0x3: 'ジャズ・フュージョン',
    0x4: '歌謡曲・演歌',
    0x5: 'ライブ・コンサート',
    0x6: 'ランキング・リクエスト',
    0x7: 'カラオケ・のど自慢',
    0x8: '民謡・邦楽',
    0x9: '童謡・キッズ',
    0xA: '民族音楽・ワールドミュージック',
    0xF: 'その他',
  },
  0x5: {
    0x0: 'クイズ',
    0x1: 'ゲーム',
    0x2: 'トークバラエティ',
    0x3: 'お笑い・コメディ',
    0x4: '音楽バラエティ',
    0x5: '旅バラエティ',
    0x6: '料理バラエティ',
    0xF: 'その他',
  },
  0x6: {
    0x0: '洋画',
    0x1: '邦画',
    0x2: 'アニメ',
    0xF: 'その他',
  },
  0x7: {
    0x0: '国内アニメ',
    0x1: '海外アニメ',
    0x2: '特撮',
    0xF: 'その他',
  },
  0x8: {
    0x0: '社会・時事',
    0x1: '歴史・紀行',
    0x2: '自然・動物・環境',
    0x3: '宇宙・科学・医学',
    0x4: 'カルチャー・伝統文化',
    0x5: '文学・文芸',
    0x6: 'スポーツ',
    0x7: 'ドキュメンタリー全般',
    0x8: 'インタビュー・討論',
    0xF: 'その他',
  },
  0x9: {
    0x0: '現代劇・新劇',
    0x1: 'ミュージカル',
    0x2: 'ダンス・バレエ',
    0x3: '落語・演芸',
    0x4: '歌舞伎・古典',
    0xF: 'その他',
  },
  0xA: {
    0x0: '旅・釣り・アウトドア',
    0x1: '園芸・ペット・手芸',
    0x2: '音楽・美術・工芸',
    0x3: '囲碁・将棋',
    0x4: '麻雀・パチンコ',
    0x5: '車・オートバイ',
    0x6: 'コンピュータ・ＴＶゲーム',
    0x7: '会話・語学',
    0x8: '幼児・小学生',
    0x9: '中学生・高校生',
    0xA: '大学生・受験',
    0xB: '生涯教育・資格',
    0xC: '教育問題',
    0xF: 'その他',
  },
  0xB: {
    0x0: '高齢者',
    0x1: '障害者',
    0x2: '社会福祉',
    0x3: 'ボランティア',
    0x4: '手話',
    0x5: '文字（字幕）',
    0x6: '音声解説',
    0xF: 'その他',
  },
  0xE: {
    0x0: 'BS/地上デジタル放送用番組付属情報',
    0x1: '広帯域CSデジタル放送用拡張',
    0x2: '衛星デジタル音声放送用拡張',
    0x3: 'サーバー型番組付属情報',
    0x4: 'IP放送用番組付属情報',
  },
  0xF: {
    0xF: 'その他',
  },
};

/// 番組付属情報 (KonomiTV `ProgramUtils.USER_TYPE` と同等)。
const Map<int, String> _userType = {
  0x00: '中止の可能性あり',
  0x01: '延長の可能性あり',
  0x02: '中断の可能性あり',
  0x03: '同一シリーズの別話数放送の可能性あり',
  0x04: '編成未定枠',
  0x05: '繰り上げの可能性あり',
  0x10: '中断ニュースあり',
  0x11: '当該イベントに関連する臨時サービスあり',
  0x20: '当該イベント中に3D映像あり',
};
