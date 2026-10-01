import 'package:flutter/material.dart';

import '../../core/widgets/program_detail_body.dart';
import '../../domain/entities/channel_item.dart';
import 'channel_switch_panel.dart';
import 'comment_list_panel.dart';
import 'jikkyo_comment_source.dart';

/// 視聴画面用の番組情報パネル。
///
/// 表示内容 (上から): チャンネルヘッダー (ロゴ+番号・局名) / 番組タイトル /
/// 放送時間 / ジャンル / 番組概要 (説明) / 番組詳細。
///
/// 自身でスクロールする (`SingleChildScrollView`)。呼び出し側は縦画面なら
/// 映像の下の `Expanded` に、横画面なら映像の右の固定幅ボックスに置く。
///
/// 下端に [NavigationBar] を置き、番組情報・チャンネル切替・実況コメントを
/// 切り替える。
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
  });

  final ChannelItem item;

  /// 実況コメントの取得状態。呼び出し側 ([_LivePlayerState]) が所有する。
  final JikkyoCommentSource controller;

  /// 選択中のタブ。[programTab] / [channelTab] / [commentTab] のいずれか。
  final int selectedIndex;

  /// タブ選択時のコールバック。
  final ValueChanged<int> onDestinationSelected;

  /// チャンネル切替タブでチャンネルを選んだときのコールバック。
  final ValueChanged<String> onChannelSelected;

  /// タブのインデックス定数。
  static const programTab = 0;
  static const channelTab = 1;
  static const commentTab = 2;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          // `IndexedStack` は `index` が子の範囲外だと例外を投げるため、
          // 選択されていないタブもダミーで埋めて **3件を必ず**渡す
          // (`if` で取り除くとコメント選択時に index 2 に対して子1件になり壊れる)。
          child: IndexedStack(
            index: selectedIndex,
            children: [
              // 番組情報の中身はビデオ詳細と共有する [ProgramDetailBody]。
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ProgramDetailBody(
                  channel: item.channel,
                  program: item.nowOnAir,
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
              // コメントタブが選択されている間だけ載せる。ソケットは
              // [controller] が保持しているので、ここで外しても接続は切れない
              // (向きが変わるとこのウィジェットは破棄されるため)。
              if (selectedIndex == commentTab)
                CommentListPanel(controller: controller)
              else
                const SizedBox.shrink(),
            ],
          ),
        ),
        NavigationBar(
          // 横画面ではパネルが幅 400px のサイドバーになるため縦幅を詰める。
          height: 64,
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
          ],
        ),
      ],
    );
  }
}
