import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/backends/konomi/konomi_live.dart';
import '../../domain/entities/live_stream.dart';
import '../../domain/providers/backend_provider.dart';
import '../tv/tv_providers.dart';
import 'program_info_panel.dart';

part 'watch_providers.g.dart';

/// 視聴中の画質 (KonomiTV用)。永続化しない。既定は `original`。
///
/// セッション中は保持する (keepAlive)。チャンネル切り替えやコントロールの
/// 破棄・再生成で状態が初期値に戻らないようにするため。
@Riverpod(keepAlive: true)
class WatchQuality extends _$WatchQuality {
  @override
  String build() => defaultKonomiQuality;

  /// 画質を切り替える。不正値は `original` に正規化される。
  void setQuality(String quality) {
    state = normalizeKonomiQuality(quality);
  }
}

/// 情報パネルの選択中タブ。永続化しない。既定は番組情報。
///
/// セッション中は保持する (keepAlive)。情報パネルは画面回転でも選択を保つが、
/// チャンネル切り替えは `go` で視聴画面ごと置き換えるため State が消える。
/// ここに残さないとチャンネルを切り替えるたびに番組情報タブに戻ってしまう。
@Riverpod(keepAlive: true)
class WatchInfoTab extends _$WatchInfoTab {
  @override
  int build() => ProgramInfoPanel.programTab;

  /// タブを切り替える。範囲外の値は無視する。
  void select(int index) {
    if (index < ProgramInfoPanel.programTab ||
        index > ProgramInfoPanel.commentTab) {
      return;
    }
    if (state == index) return;
    state = index;
  }
}

/// 指定チャンネルのライブストリーム情報。画質変更に追従する。
///
/// チャンネル解決は放送中一覧のキャッシュから行う。見つからなければ例外送出し、
/// UI側で「見つかりません」表示に使う。
@riverpod
Future<LiveStream> liveStream(Ref ref, String channelId) async {
  final quality = ref.watch(watchQualityProvider);
  final items = await ref.watch(nowOnAirChannelsProvider.future);
  final item = items.where((e) => e.channel.id == channelId).firstOrNull;
  if (item == null) {
    throw const ChannelNotFoundException();
  }
  final repository = ref.watch(tvRepositoryProvider);
  return repository.getLiveStream(item.channel, quality: quality);
}

/// 視聴対象チャンネルが一覧キャッシュに無い場合の例外。
class ChannelNotFoundException implements Exception {
  const ChannelNotFoundException();
}
