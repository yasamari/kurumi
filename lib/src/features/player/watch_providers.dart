import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/network_type_monitor.dart';
import '../../core/settings/app_settings.dart';
import '../../domain/entities/backend_type.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/live_stream.dart';
import '../../domain/providers/backend_provider.dart';
import '../../domain/repositories/tv_repository.dart';
import '../tv/epg_providers.dart';
import '../tv/tv_providers.dart';
import 'program_info_panel.dart';

part 'watch_providers.g.dart';

/// 視聴中の画質。永続化しない。
///
/// セッション中は保持する (keepAlive)。チャンネル切り替えやコントロールの
/// 破棄・再生成で状態が初期値に戻らないようにするため。
///
/// 初期値は設定の回線別画質 (KonomiTV) から選ぶ。回線種別は build 時に
/// 一度だけ読む (購読しない) ので、再生中の回線切替では画質を変えない
/// ([NetworkTypeMonitor] 参照)。
@Riverpod(keepAlive: true)
class WatchQuality extends _$WatchQuality {
  @override
  String build() {
    final repository = ref.watch(tvRepositoryProvider);
    final networkType = NetworkTypeMonitor.instance.value.value;
    final configured = ref.watch(
      appSettingsProvider.select(
        (settings) => settings.value?.konomiLiveQualityFor(networkType),
      ),
    );
    if (configured == null) return repository.getDefaultLiveQuality();
    return repository.normalizeLiveQuality(configured);
  }

  /// 画質を切り替える。不正値は既定画質に正規化される。
  void setQuality(String quality) {
    final repository = ref.read(tvRepositoryProvider);
    state = repository.normalizeLiveQuality(quality);
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
        index > ProgramInfoPanel.captureTab) {
      return;
    }
    if (state == index) return;
    state = index;
  }
}

/// 指定チャンネルのライブストリーム情報。画質変更に追従する。
///
/// チャンネル解決はバックエンド別に行う。KonomiTV は放送中一覧のキャッシュ、
/// Mirakurun はEPGキャッシュのチャンネル行 (時刻に依存しない one-shot 読出)
/// から行う。見つからなければ例外送出し、UI側で「見つかりません」表示に使う。
///
/// Mirakurun で放送中一覧 (`nowOnAirChannelsProvider`) を使わないのは、
/// あちらが毎分再計算されるため。ここで購読すると毎分 loading を経由して
/// 映像スロット (`_LivePlayer` の State ごと) が作り直されてしまう。
@riverpod
Future<LiveStream> liveStream(Ref ref, String channelId) async {
  final quality = ref.watch(watchQualityProvider);
  final backendType = ref.watch(
    appSettingsProvider.select(
      (settings) => settings.value?.backendType ?? BackendType.mirakurun,
    ),
  );
  final Channel channel;
  if (backendType == BackendType.konomiTv) {
    final items = await ref.watch(nowOnAirChannelsProvider.future);
    final item = items.where((e) => e.channel.id == channelId).firstOrNull;
    if (item == null) {
      throw const ChannelNotFoundException();
    }
    channel = item.channel;
  } else {
    channel = await ref.watch(mirakurunEpgChannelProvider(channelId).future);
  }
  final repository = ref.watch(tvRepositoryProvider);
  return repository.getLiveStream(channel, quality: quality);
}
