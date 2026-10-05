import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/widgets/program_detail_body.dart';
import '../../domain/entities/channel_item.dart';
import '../../domain/entities/tv_program.dart';
import 'capture_list_panel.dart';
import 'channel_switch_panel.dart';
import 'comment_list_panel.dart';
import 'jikkyo_comment_source.dart';
import 'player_capture.dart';

/// 情報パネル下端のナビゲーションバーの高さ。
const playerInfoTabsHeight = 64.0;

/// タブ付き情報パネルの土台。ライブ視聴と録画再生で共有する。
///
/// `IndexedStack` は `index` が子の範囲外だと例外を投げるため、選択されて
/// いないタブも `SizedBox.shrink()` で埋めて **子と [tabCount] 件を必ず**渡す。
/// 未選択タブを `if` で取り除くと、コメント選択時 (index 2) に子が1件しか
/// 残らず範囲外.Assertion を出す。
class PlayerInfoTabs extends StatelessWidget {
  const PlayerInfoTabs({
    super.key,
    required this.tabCount,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.children,
    required this.destinations,
  });

  /// タブの数。[children] の個数と必ず一致させる。
  final int tabCount;

  /// 選択中のタブ番号。
  final int selectedIndex;

  /// タブ選択時のコールバック。
  final ValueChanged<int> onDestinationSelected;

  /// 各タブの中身。**長さは [tabCount] と必ず一致させる。** 選択されていない
  /// タブは `SizedBox.shrink()` を入れる。
  final List<Widget> children;

  /// 下端のナビゲーションバーの項目。
  final List<NavigationDestination> destinations;

  @override
  Widget build(BuildContext context) {
    assert(
      children.length == tabCount,
      'children は tabCount=$tabCount 件ちょうどを渡してください',
    );
    assert(
      destinations.length == tabCount,
      'destinations は tabCount=$tabCount 件ちょうどを渡してください',
    );
    return Column(
      children: [
        Expanded(
          child: IndexedStack(index: selectedIndex, children: children),
        ),
        NavigationBar(
          // 横画面ではパネルが幅 400px のサイドバーになるため縦幅を詰める。
          height: playerInfoTabsHeight,
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          destinations: destinations,
        ),
      ],
    );
  }
}

/// 視聴画面用の番組情報パネル。
///
/// 表示内容 (上から): チャンネルヘッダー (ロゴ+番号・局名) / 現在の番組
/// (タイトル・放送時間・ジャンル) / 次の番組 (タイトルと放送時間のみ) /
/// 番組概要 / 番組詳細。
///
/// 現在・次番組はライブEIT[p/f]からのみ取得する ([livePresent] /
/// [liveFollowing])。`/api/channels` 由来の番組は使わない。未受信時は
/// パネルの中央に `CircularProgressIndicator` だけを出す。
///
/// 自身でスクロールする (`SingleChildScrollView`)。呼び出し側は縦画面なら
/// 映像の下の `Expanded` に、横画面なら映像の右の固定幅ボックスに置く。
///
/// 下端に [NavigationBar] を置き、番組情報・チャンネル切替・実況コメント・
/// キャプチャを切り替える (土台は [PlayerInfoTabs])。
///
/// **タブの選択状態は持たない** (制御コンポーネント)。このウィジェットは
/// 視聴画面の `Row` / `Column` 切り替えの内側に置かれるため、画面の向きが変わると
/// Element ごと作り直されて State を失う。選択を保つには呼び出し側が
/// `watchInfoTabProvider` (keepAlive) を持つ必要がある。
class ProgramInfoPanel extends StatelessWidget {
  const ProgramInfoPanel({
    super.key,
    required this.item,
    required this.controller,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onChannelSelected,
    required this.captures,
    this.livePresent,
    this.liveFollowing,
  });

  final ChannelItem item;

  /// 実況コメントの取得状態。呼び出し側 (`_WatchLayoutState`) が所有する。
  final JikkyoCommentSource controller;

  /// 選択中のタブ。
  /// [programTab] / [channelTab] / [commentTab] / [captureTab] のいずれか。
  final int selectedIndex;

  /// タブ選択時のコールバック。
  final ValueChanged<int> onDestinationSelected;

  /// チャンネル切替タブでチャンネルを選んだときのコールバック。
  final ValueChanged<String> onChannelSelected;

  /// キャプチャ一覧の通知元。呼び出し側 (`_WatchLayoutState`) が所有する。
  /// 購読はキャプチャタブの中だけに行う (映像の再構築に巻き込まないため)。
  final ValueListenable<List<CaptureEntry>> captures;

  /// ライブEIT[p/f] 由来の現在番組。未受信時は取得中表示になる。
  final TvProgram? livePresent;

  /// ライブEIT[p/f] 由来の次番組。未受信時は出さない。
  final TvProgram? liveFollowing;

  /// タブのインデックス定数。
  static const programTab = 0;
  static const channelTab = 1;
  static const commentTab = 2;
  static const captureTab = 3;

  @override
  Widget build(BuildContext context) {
    return PlayerInfoTabs(
      tabCount: 4,
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.tv_outlined),
          selectedIcon: Icon(Icons.tv),
          label: '番組情報',
        ),
        NavigationDestination(
          icon: Icon(Icons.grid_view_outlined),
          selectedIcon: Icon(Icons.grid_view),
          label: 'チャンネル',
        ),
        NavigationDestination(
          icon: Icon(Icons.chat_bubble_outline),
          selectedIcon: Icon(Icons.chat_bubble),
          label: 'コメント',
        ),
        NavigationDestination(
          icon: Icon(Icons.photo_library_outlined),
          selectedIcon: Icon(Icons.photo_library),
          label: 'キャプチャ',
        ),
      ],
      children: [
        // 番組情報の中身はビデオ詳細と共有する [ProgramDetailBody]。
        // 次番組はジャンルと番組概要の間にタイトルと放送時間だけ出す。
        // EIT未受信時はスクロールせず、パネル中央にインジケータだけを出す
        // (`/api/channels` 由来の番組は使わない)。
        if (livePresent == null && liveFollowing == null)
          const _LoadingProgram()
        else
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ProgramDetailBody(
              channel: item.channel,
              program: livePresent,
              following: liveFollowing,
            ),
          ),
        // チャンネル切替タブは選択されている間だけ載せる。選択中の種別の
        // タブ位置を初期値として持ち直すため、作り直しても問題ない。
        if (selectedIndex == channelTab)
          ChannelSwitchPanel(
            currentChannelId: item.channel.id,
            onChannelSelected: onChannelSelected,
          )
        else
          const SizedBox.shrink(),
        // コメントタブが選択されている間だけ載せる。ソケットは [controller] が
        // 保持しているので、ここで外しても接続は切れない (向きが変わるとこの
        // ウィジェットは破棄されるため)。
        if (selectedIndex == commentTab)
          CommentListPanel(controller: controller)
        else
          const SizedBox.shrink(),
        // キャプチャタブが選択されている間だけ載せる。不可視の画像デコードを
        // 避けるため (コメントタブと同じ)。
        if (selectedIndex == captureTab)
          CaptureListPanel(captures: captures)
        else
          const SizedBox.shrink(),
      ],
    );
  }
}

/// EIT未受信時の取得中表示。パネル中央にインジケータだけを出す。
class _LoadingProgram extends StatelessWidget {
  const _LoadingProgram();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}
