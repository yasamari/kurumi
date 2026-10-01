import 'package:dio/dio.dart';

import 'jikkyo_comment.dart';
import 'jikkyo_past_comment_filter.dart';

/// 過去ログ取得に失敗したときの例外。UI側で理由表示・再試行に使う。
class JikkyoKakologException implements Exception {
  const JikkyoKakologException(this.message);

  /// ユーザー向けの失敗理由。
  final String message;
}

/// ニコニコ実況 過去ログ API (`jikkyo.tsukumijima.net`) クライアント。
///
/// KonomiTVサーバーを経由せず直接取得する。取得範囲には録画期間
/// (`recorded_video` の `recording_start/end_time`) を指定する。
class JikkyoKakologClient {
  JikkyoKakologClient()
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'https://jikkyo.tsukumijima.net',
            connectTimeout: const Duration(seconds: 10),
            // 過去ログ応答は重いためサーバー実装に合わせて30秒待つ
            receiveTimeout: const Duration(seconds: 30),
          ),
        );

  final Dio _dio;

  /// 指定範囲の過去コメントを投稿時刻順で返す。
  ///
  /// 範囲がAPI上限 (3日) を超える場合は分割取得する。該当コメントなしは
  /// 空リスト (エラーにしない。API仕様どおり)。
  Future<List<JikkyoComment>> fetchPastComments({
    required String jkId,
    required DateTime start,
    required DateTime end,
  }) async {
    final chunks = <List<JikkyoComment>>[];
    for (final (rangeStart, rangeEnd) in splitKakologRange(
      start: start,
      end: end,
    )) {
      chunks.add(
        await _fetchRange(jkId: jkId, start: rangeStart, end: rangeEnd),
      );
    }
    return mergePastJikkyoComments(chunks);
  }

  Future<List<JikkyoComment>> _fetchRange({
    required String jkId,
    required DateTime start,
    required DateTime end,
  }) async {
    late final Response<dynamic> response;
    try {
      response = await _dio.get<dynamic>(
        '/api/kakolog/$jkId',
        queryParameters: {
          'starttime': start.millisecondsSinceEpoch ~/ 1000,
          'endtime': end.millisecondsSinceEpoch ~/ 1000,
          'format': 'json',
        },
      );
    } on DioException {
      throw const JikkyoKakologException(
        '過去ログAPIに接続できませんでした',
      );
    }
    final data = response.data;
    if (data is Map<String, dynamic> && data['error'] is String) {
      throw JikkyoKakologException(data['error'] as String);
    }
    if (data is! Map<String, dynamic>) {
      throw const JikkyoKakologException('過去ログAPIの応答形式が不正です');
    }
    return parseKakologPacket(data['packet']);
  }
}
