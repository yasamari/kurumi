import 'package:flutter/material.dart';

import '../../core/widgets/channel_logo.dart';
import '../../core/widgets/program_detail_body.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/channel_item.dart';
import '../../domain/entities/tv_program.dart';
import 'channel_switch_panel.dart';
import 'comment_list_panel.dart';
import 'jikkyo_comment_source.dart';

/// 視聴画面用の番組情報パネル。
///
/// 表示内容 (上から): チャンネルヘッダー (ロゴ+番号・局名) / 現在の番組
/// (タイトル・放送時間・ジャンル) / 次の番組 (タイトルと放送時間のみ) /
/// 番組概要 / 番組詳細。
///
/// 現在・次番組はライブEIT[p/f]からのみ取得する ([livePresent] /
/// [liveFollowing])。`/api/channels` 由来の番組は使わない。未受信時は
/// 「番組情報を取得中」と出す。
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
    this.livePresent,
    this.liveFollowing,
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

  /// ライブEIT[p/f] 由来の現在番組。未受信時は取得中表示になる。
  final TvProgram? livePresent;

  /// ライブEIT[p/f] 由来の次番組。未受信時は出さない。
  final TvProgram? liveFollowing;

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
              // 次番組はジャンルと番組概要の間にタイトルと放送時間だけ出す。
              // EIT未受信時は取得中表示になる (`/api/channels` は使わない)。
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: livePresent == null && liveFollowing == null
                    ? _LoadingProgram(channel: item.channel)
                    : ProgramDetailBody(
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

/// EIT未受信時の取得中表示。チャンネルヘッダーは出して待つ。
class _LoadingProgram extends StatelessWidget {
  const _LoadingProgram({required this.channel});

  final Channel channel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final number = channel.channelNumber;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (channel.logoUrl != null) ...[
              ChannelLogo(channel: channel),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                number.isEmpty ? channel.name : '$number ${channel.name}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text('番組情報を取得中…', style: theme.textTheme.bodyMedium),
          ],
        ),
      ],
    );
  }
}
