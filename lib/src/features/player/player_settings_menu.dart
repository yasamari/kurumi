import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../data/ts/audio_layout.dart';
import '../shell/app_destinations.dart';
import 'audio_switch.dart';
import 'danmaku_settings.dart';

/// 設定メニューの幅。`showMenu` の既定より広く取る。
const _settingsMenuWidth = 320.0;

/// 設定メニューの最大高さ。
const _settingsMenuMaxHeight = 480.0;

/// 設定メニューの最低高さ。内容が少なくてもスクロール領域を保つわけではなく、
/// 上下どちらに置いてもボタンと干渉しない高さの目安。
const _settingsMenuMinSpace = 200.0;

/// ボタンとメニューの間隔。メニューがボタンに重ならないように空ける。
const _settingsMenuGap = 8.0;

/// 画面端とメニューの余白。
const _settingsMenuMargin = 8.0;

/// ボトムシートにする画面の上端からの最大の高さ。
const _settingsSheetMaxHeightRatio = 0.7;

/// スマホ幅で縦向きならボトムシート、それ以外はボタン横のポップアップにする。
///
/// 幅の基準はシェルのスマホ/タブレット切り替え ([AdaptiveBreakpoints.rail]) に
/// 揃える。横向きは縦幅が広い (幅より縦に長い) ためポップアップのまま。
bool _useBottomSheet(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return size.width < AdaptiveBreakpoints.rail && size.height > size.width;
}

/// プレイヤーの設定ボタン。画質・弾幕・音声をまとめたメニューを開く。
///
/// フルスクリーンボタンの左に置く。字幕ボタンはさらにその左に置く
/// ([SubtitleToggleButton] 参照)。押すとボタンの近くに一覧メニューが開き、
/// 画質・弾幕・音声の3ページに分かれる。
///
/// `PopupMenuButton` は使わない。media_kit のコントロールは自動非表示に
/// なると `mount=false` としてツリーから取り除かれるため、メニュー選択時点で
/// このウィジェットが破棄されていることがある。その場合 Flutter 内部の
/// `if (!mounted) return;` により `onSelected` が呼ばれず、選択が反映されない。
/// そのため専用のポップアップルート ([showPlayerSettingsMenu]) を直接開き、
/// 選択結果をコールバックで返す。呼び出し側 (コントロールより上位の
/// ウィジェット) で状態に反映すること。
class PlayerSettingsButton extends StatelessWidget {
  const PlayerSettingsButton({
    super.key,
    required this.player,
    required this.dualMonoChannel,
    required this.onAudioSelected,
    this.audioLayout,
    this.danmakuSupported = false,
    this.danmakuPreferences = const DanmakuPreferences(),
    this.onDanmakuPreferencesChanged,
    this.qualityCurrent,
    this.qualities = const [],
    this.onQualitySelected,
  });

  final Player player;

  /// 現在選択中の二重モノラルのチャンネル。null はステレオ (主＋副)。
  final DualMonoChannel? dualMonoChannel;

  /// 音声選択時のコールバック。呼び出し側で状態に反映すること。
  final ValueChanged<AudioChoice> onAudioSelected;

  /// 音声構成の通知元。EIT[p/f] からの取得状況をここに渡す。
  ///
  /// ライブ視聴は `_LiveSettingsButton` が渡し、録画再生のように TS を
  /// 見ない画面は null (＝ [LiveAudioLayout.unknown]、mpv に委ねる)。
  /// 購読はせず notifier の参照だけ持ち、購読はメニュー内
  /// ([_SettingsMenuPanel]) で行う。ボタン側で購読すると映像側の再構築に
  /// 巻き込まれうるため。
  final ValueListenable<LiveAudioLayout>? audioLayout;

  /// 実況チャンネルが対応している場合のみ弾幕ページを出す。
  final bool danmakuSupported;

  /// 弾幕の表示設定 (on/off と文字サイズ・透明度・速度)。メニューを開いた
  /// 時点の値。
  final DanmakuPreferences danmakuPreferences;

  /// 弾幕の表示設定を変えたときのコールバック。呼び出し側で状態に反映し、
  /// 永続化まで行うこと。
  ///
  /// null のときスライダーとスイッチを無効にする。購読はボタン側で行わない。
  /// 映像側の再構築に巻き込まれるため ([audioLayout] と同じ理屈)。
  final ValueChanged<DanmakuPreferences>? onDanmakuPreferencesChanged;

  /// 現在の画質。null のときは画質ページを出さない。
  final String? qualityCurrent;

  /// 選択肢の画質一覧。空のときは画質ページを出さない。
  final List<String> qualities;

  /// 画質選択時のコールバック。
  final ValueChanged<String>? onQualitySelected;

  /// 画質ページを出すかどうか。
  bool get hasQualityPage =>
      qualityCurrent != null &&
      qualities.isNotEmpty &&
      onQualitySelected != null;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.settings_outlined),
      color: Colors.white,
      tooltip: '設定',
      onPressed: () => showPlayerSettingsMenu(
        context,
        player: player,
        dualMonoChannel: dualMonoChannel,
        onAudioSelected: onAudioSelected,
        audioLayout: audioLayout,
        danmakuSupported: danmakuSupported,
        danmakuPreferences: danmakuPreferences,
        onDanmakuPreferencesChanged: onDanmakuPreferencesChanged,


        qualityCurrent: qualityCurrent,
        qualities: qualities,
        onQualitySelected: onQualitySelected,
      ),
    );
  }
}

/// 設定メニューのページ。
enum _SettingsPage {
  /// 一覧 (画質・弾幕・音声への入口)。
  main,

  /// 画質の選択。
  quality,

  /// 弾幕の on/off。
  danmaku,

  /// 音声の選択。
  audio,
}

/// mpv が常に足す `auto` / `no` を除いた実トラック。
List<AudioTrack> _realAudioTracks(List<AudioTrack> tracks) {
  final reserved = {AudioTrack.auto().id, AudioTrack.no().id};
  return tracks.where((t) => !reserved.contains(t.id)).toList();
}

/// 設定メニューを開く。画質・弾幕・音声の3ページ構成。
///
/// スマホ幅の縦画面では画面下からせり出すボトムシート、それ以外はボタンの
/// 上下どちらか広い側に寄せたポップアップにする。メニューを閉じた後の選択結果は
/// コールバックで返す。
Future<void> showPlayerSettingsMenu(
  BuildContext context, {
  required Player player,
  required DualMonoChannel? dualMonoChannel,
  required ValueChanged<AudioChoice> onAudioSelected,
  ValueListenable<LiveAudioLayout>? audioLayout,
  bool danmakuSupported = false,
  DanmakuPreferences danmakuPreferences = const DanmakuPreferences(),
  ValueChanged<DanmakuPreferences>? onDanmakuPreferencesChanged,
  String? qualityCurrent,
  List<String> qualities = const [],
  ValueChanged<String>? onQualitySelected,
}) {
  if (_useBottomSheet(context)) {
    return showModalBottomSheet<void>(
      context: context,
      // パネル自身が Material カードとして描くため、シートの背景は出さない。
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      isScrollControlled: true,
      // 縦高を自分で決めるため既定の上限 (9/16) に収めない。
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.sizeOf(context).height * _settingsSheetMaxHeightRatio,
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(_settingsMenuMargin),
        child: _SettingsMenuPanel(
          maxHeight: MediaQuery.sizeOf(context).height *
              _settingsSheetMaxHeightRatio,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(16),
          ),
          player: player,
          dualMonoChannel: dualMonoChannel,
          onAudioSelected: onAudioSelected,
          audioLayout: audioLayout,
          danmakuSupported: danmakuSupported,
          danmakuPreferences: danmakuPreferences,
          onDanmakuPreferencesChanged: onDanmakuPreferencesChanged,


          qualityCurrent: qualityCurrent,
          qualities: qualities,
          onQualitySelected: onQualitySelected,
        ),
      ),
    );
  }
  final anchorBox = context.findRenderObject() as RenderBox?;
  final overlay = Overlay.of(context);
  final overlayBox = overlay.context.findRenderObject() as RenderBox?;
  if (anchorBox == null || !anchorBox.hasSize) return Future.value();
  if (overlayBox == null || !overlayBox.hasSize) return Future.value();

  final origin = anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox);
  // ボタンが破棄されてもメニューを開けるよう、押下時の矩形だけ持ち込む
  // (コントロール自動非表示でボタンが消えるため)。
  final anchorRect = origin & anchorBox.size;
  return Navigator.of(context).push<void>(
    _PlayerSettingsMenuRoute(
      settings: const RouteSettings(name: 'player_settings'),
      anchorRect: anchorRect,
      player: player,
      dualMonoChannel: dualMonoChannel,
      onAudioSelected: onAudioSelected,
      audioLayout: audioLayout,
      danmakuSupported: danmakuSupported,
      danmakuPreferences: danmakuPreferences,
      onDanmakuPreferencesChanged: onDanmakuPreferencesChanged,


      qualityCurrent: qualityCurrent,
      qualities: qualities,
      onQualitySelected: onQualitySelected,
    ),
  );
}

/// ボタンの近くに置く設定メニューのポップアップルート。
class _PlayerSettingsMenuRoute extends PopupRoute<void> {
  _PlayerSettingsMenuRoute({
    super.settings,
    required this.anchorRect,
    required this.player,
    required this.dualMonoChannel,
    required this.onAudioSelected,
    required this.audioLayout,
    required this.danmakuSupported,
    required this.danmakuPreferences,
    required this.onDanmakuPreferencesChanged,
    required this.qualityCurrent,
    required this.qualities,
    required this.onQualitySelected,
  });

  /// 押下時の設定ボタンの矩形 (Overlay 座標)。
  final Rect anchorRect;

  final Player player;
  final DualMonoChannel? dualMonoChannel;
  final ValueChanged<AudioChoice> onAudioSelected;
  final ValueListenable<LiveAudioLayout>? audioLayout;
  final bool danmakuSupported;
  final DanmakuPreferences danmakuPreferences;
  final ValueChanged<DanmakuPreferences>? onDanmakuPreferencesChanged;
  final String? qualityCurrent;
  final List<String> qualities;
  final ValueChanged<String>? onQualitySelected;

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => true;

  @override
  String get barrierLabel => '設定メニューを閉じる';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 180);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    // 画面回転で Overlay の大きさが変わっても追従するよう、配置は
    // その時点の制約から決める (ボタン矩形だけ押下時のものを使う)。
    return LayoutBuilder(
      builder: (context, constraints) {
        final overlayWidth = constraints.maxWidth;
        final overlayHeight = constraints.maxHeight;
        final padding = MediaQuery.paddingOf(context);
        final width = min(
          _settingsMenuWidth,
          overlayWidth - _settingsMenuMargin * 2,
        );
        final spaceAbove = anchorRect.top - padding.top - _settingsMenuMargin;
        final spaceBelow =
            overlayHeight - anchorRect.bottom - padding.bottom - _settingsMenuMargin;
        final placeAbove = spaceAbove >= spaceBelow;
        final maxHeight = (placeAbove ? spaceAbove : spaceBelow)
            .clamp(_settingsMenuMinSpace, _settingsMenuMaxHeight)
            .toDouble();
        final left = (anchorRect.right - width)
            .clamp(
              _settingsMenuMargin,
              max(
                _settingsMenuMargin,
                overlayWidth - width - _settingsMenuMargin,
              ),
            )
            .toDouble();
        return Stack(
          children: [
            Positioned(
              left: left,
              width: width,
              // ボタンとは間隔を空け、重ならないようにする。
              top: placeAbove ? null : anchorRect.bottom + _settingsMenuGap,
              bottom: placeAbove
                  ? overlayHeight - anchorRect.top + _settingsMenuGap
                  : null,
              child: _SettingsMenuPanel(
                maxHeight: maxHeight,
                player: player,
                dualMonoChannel: dualMonoChannel,
                onAudioSelected: onAudioSelected,
                audioLayout: audioLayout,
                danmakuSupported: danmakuSupported,
                danmakuPreferences: danmakuPreferences,
                onDanmakuPreferencesChanged: onDanmakuPreferencesChanged,


                qualityCurrent: qualityCurrent,
                qualities: qualities,
                onQualitySelected: onQualitySelected,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position:
            Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curved),
        child: child,
      ),
    );
  }
}

/// 一覧と子ページを横スライドで切り替えるメニュー本体。
class _SettingsMenuPanel extends StatefulWidget {
  const _SettingsMenuPanel({
    required this.maxHeight,
    required this.player,
    required this.dualMonoChannel,
    required this.onAudioSelected,
    required this.audioLayout,
    required this.danmakuSupported,
    required this.danmakuPreferences,
    required this.onDanmakuPreferencesChanged,
    required this.qualityCurrent,
    required this.qualities,
    required this.onQualitySelected,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  final double maxHeight;
  final Player player;
  final DualMonoChannel? dualMonoChannel;
  final ValueChanged<AudioChoice> onAudioSelected;

  /// 音声構成の通知元。null は [LiveAudioLayout.unknown] として扱う。
  final ValueListenable<LiveAudioLayout>? audioLayout;

  final bool danmakuSupported;
  final DanmakuPreferences danmakuPreferences;
  final ValueChanged<DanmakuPreferences>? onDanmakuPreferencesChanged;
  final String? qualityCurrent;
  final List<String> qualities;
  final ValueChanged<String>? onQualitySelected;

  /// ボトムシートでは上端だけ丸める。
  final BorderRadius borderRadius;

  @override
  State<_SettingsMenuPanel> createState() => _SettingsMenuPanelState();
}

class _SettingsMenuPanelState extends State<_SettingsMenuPanel> {
  _SettingsPage _page = _SettingsPage.main;

  /// 弾幕の表示設定の表示値。メニューを開いた時点の値を初期値にし、切り替え
  /// やスライダー操作後もメニューは開いたままにするためローカルで持つ
  /// (通知はコールバック経由。購読すると映像の作り直しに巻き込まれる)。
  late DanmakuPreferences _danmaku = widget.danmakuPreferences;

  /// 弾幕の表示設定を決めて反映する。メニューは開いたままにする。
  void _changeDanmaku(DanmakuPreferences preferences) {
    final onChanged = widget.onDanmakuPreferencesChanged;
    if (onChanged == null) return;
    setState(() => _danmaku = preferences);
    onChanged(preferences);
  }

  /// ページ遷移の向き。進むとき +1 (右から入る)、戻るとき -1 (左から入る)。
  double _slideSign = 1;

  void _go(_SettingsPage page, double slideSign) {
    setState(() {
      _page = page;
      _slideSign = slideSign;
    });
  }

  /// 値を選んだらメニューを閉じてからコールバックを呼ぶ。
  void _pick(VoidCallback onSelected) {
    Navigator.of(context).pop();
    onSelected();
  }

  @override
  Widget build(BuildContext context) {
    final audioLayout = widget.audioLayout;
    // 音声構成 (EIT[p/f]) はメニューを開いた後に届くことがある。ボタン側で
    // 購読すると映像側の再構築に巻き込まれるため、メニューの中で購読する
    // (ポップアップルート内なので映像には影響しない)。
    if (audioLayout == null) {
      return _buildPanel(context, LiveAudioLayout.unknown);
    }
    return ValueListenableBuilder<LiveAudioLayout>(
      valueListenable: audioLayout,
      builder: (context, layout, _) => _buildPanel(context, layout),
    );
  }

  Widget _buildPanel(BuildContext context, LiveAudioLayout layout) {
    final qualityCurrent = widget.qualityCurrent;
    final onQualitySelected = widget.onQualitySelected;
    final hasQualityPage =
        qualityCurrent != null &&
        widget.qualities.isNotEmpty &&
        onQualitySelected != null;
    return Material(
      type: MaterialType.card,
      elevation: 8,
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: widget.borderRadius,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: widget.maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 一覧には見出しを出さない (中身の行だけで完結させる)。
            if (_page != _SettingsPage.main) _menuHeader(context),
            Flexible(
              // ページの高さが変わるときは上端を基準に伸縮する。
              child: AnimatedSize(
                duration: const Duration(milliseconds: 200),
                reverseDuration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: _pageTransition,
                  // 遷移中の大きさは新しいページで決める。既定のままだと
                  // 新旧の大きい方に合わさり、縮む方向ではスライド終了後に
                  // 高さが変わって逐次的に見える。
                  layoutBuilder: _pageLayout,
                  child: KeyedSubtree(
                    key: ValueKey(_page),
                    child: switch (_page) {
                      _SettingsPage.main => _buildMainPage(
                        context,
                        hasQualityPage: hasQualityPage,
                        qualityCurrent: qualityCurrent,
                        layout: layout,
                      ),
                      _SettingsPage.quality => _buildQualityPage(
                        context,
                        qualityCurrent: qualityCurrent,
                        onQualitySelected: onQualitySelected,
                      ),
                      _SettingsPage.danmaku => _buildDanmakuPage(context),
                      _SettingsPage.audio => _buildAudioPage(context, layout),
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ページ遷移のアニメーション。新しいページが横からスライドして入り、
  /// 古いページは逆方向へ少し流れながら素早く消える。高さの伸縮
  /// ([AnimatedSize]) と同じ200msで同時進行する。
  Widget _pageTransition(Widget child, Animation<double> animation) {
    // 入ってくる子 (現在のページのキーを持つ) は横からスライドする。
    if (child.key == ValueKey(_page)) {
      final slide =
          Tween<Offset>(
            begin: Offset(_slideSign, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          );
      final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: fade,
        child: SlideTransition(position: slide, child: child),
      );
    }
    // 出ていく子はフェードアウトし、高さが縮む間の食み出しを目立たせない。
    final fade = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0, 0.6, curve: Curves.easeOut),
      ),
    );
    final drift =
        Tween<Offset>(
          begin: Offset.zero,
          end: Offset(-0.15 * _slideSign, 0),
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: const Interval(0, 0.6, curve: Curves.easeOut),
          ),
        );
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: drift, child: child),
    );
  }

  /// 遷移中の配置。古いページは大きさに寄与させず上端に重ねることで、
  /// 遷移開始と同時に新しいページの高さへ向かって伸縮する。
  Widget _pageLayout(Widget? currentChild, List<Widget> previousChildren) {
    final List<Widget> children = previousChildren
        .map<Widget>(
          (previousChild) => Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: previousChild,
          ),
        )
        .toList();
    final current = currentChild;
    if (current != null) children.add(current);
    return Stack(alignment: Alignment.topCenter, children: children);
  }

  /// 見出し行。子ページでのみ出す (戻るボタン＋ページ名。閉じるボタンは無く、
  /// 外側タップやスワイプで閉じる)。
  Widget _menuHeader(BuildContext context) {
    final title = switch (_page) {
      _SettingsPage.main => '',
      _SettingsPage.quality => '画質',
      _SettingsPage.danmaku => '弾幕',
      _SettingsPage.audio => '音声',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: '設定に戻る',
            onPressed: () => _go(_SettingsPage.main, -1),
          ),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
          // タイトルを中央に保つための余白 (閉じるボタンは置かない)。
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildMainPage(
    BuildContext context, {
    required bool hasQualityPage,
    required String? qualityCurrent,
    required LiveAudioLayout layout,
  }) {
    return ListView(
      shrinkWrap: true,
      children: [
        if (hasQualityPage)
          ListTile(
            leading: const Icon(Icons.high_quality_outlined),
            title: const Text('画質'),
            subtitle: Text(qualityCurrent ?? ''),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _go(_SettingsPage.quality, 1),
          ),
        if (widget.danmakuSupported)
          ListTile(
            leading: const Icon(Icons.comment_outlined),
            title: const Text('弾幕'),
            subtitle: Text(_danmaku.enabled ? '表示' : '非表示'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _go(_SettingsPage.danmaku, 1),
          ),
        StreamBuilder<Tracks>(
          stream: widget.player.stream.tracks,
          builder: (context, tracksSnapshot) {
            final tracks =
                tracksSnapshot.data?.audio ??
                widget.player.state.tracks.audio;
            return StreamBuilder<Track>(
              stream: widget.player.stream.track,
              builder: (context, trackSnapshot) {
                final current =
                    trackSnapshot.data?.audio ??
                    widget.player.state.track.audio;
                final realTracks = _realAudioTracks(tracks);
                final mode = audioMenuMode(
                  realAudioTrackCount: realTracks.length,
                  layout: layout,
                );
                // 選べないときはページも開かず、表示だけで示す。
                final selectable = mode != AudioMenuMode.single;
                return ListTile(
                  leading: const Icon(Icons.audiotrack),
                  title: const Text('音声'),
                  subtitle: Text(
                    audioMenuLabel(
                      mode: mode,
                      layout: layout,
                      realAudioTracks: realTracks,
                      current: current,
                      dualMonoChannel: widget.dualMonoChannel,
                    ),
                  ),
                  trailing: selectable
                      ? const Icon(Icons.chevron_right)
                      : null,
                  onTap: selectable
                      ? () => _go(_SettingsPage.audio, 1)
                      : null,
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildQualityPage(
    BuildContext context, {
    required String? qualityCurrent,
    required ValueChanged<String>? onQualitySelected,
  }) {
    final checkColor = Theme.of(context).colorScheme.primary;
    return ListView(
      shrinkWrap: true,
      children: [
        for (final q in widget.qualities)
          ListTile(
            title: Text(q),
            trailing: q == qualityCurrent
                ? Icon(Icons.check, color: checkColor)
                : null,
            onTap: () => _pick(() => onQualitySelected?.call(q)),
          ),
      ],
    );
  }

  /// 弾幕のページ。on/off のスイッチと、3項目のスライダー。
  ///
  /// どちらも1つ動かすごとに反映し、メニューは開いたままにする (選択ページと
  /// 違い閉じない)。値を確かめるため ([_pick] を使わない)。
  Widget _buildDanmakuPage(BuildContext context) {
    final editable = widget.onDanmakuPreferencesChanged != null;
    final switchTile = SwitchListTile(
      title: const Text('弾幕を表示'),
      value: _danmaku.enabled,
      // 切り替えてもメニューは開いたままにする (選択ページと違い閉じない)。
      onChanged: editable
          ? (value) => _changeDanmaku(_danmaku.copyWith(enabled: value))
          : null,
    );
    final settings = _danmaku.settings;
    return ListView(
      shrinkWrap: true,
      children: [
        switchTile,
        _danmakuSlider(
          label: '文字サイズ',
          value: danmakuFontSizeLabel(settings.fontSize),
          sliderValue: settings.fontSize,
          min: DanmakuDisplaySettings.minFontSize,
          max: DanmakuDisplaySettings.maxFontSize,
          divisions: DanmakuDisplaySettings.fontSizeSteps,
          // スライダーは刻み幅に丸めた値 ([danmaku*Of]) で作る。
          onChanged: editable
              ? (raw) => _changeDanmaku(
                  _danmaku.copyWith(
                    settings: settings.copyWith(
                      fontSize: danmakuFontSizeOf(raw),
                    ),
                  ),
                )
              : null,
        ),
        _danmakuSlider(
          label: '透明度',
          value: danmakuOpacityLabel(settings.opacity),
          sliderValue: settings.opacity,
          min: DanmakuDisplaySettings.minOpacity,
          max: DanmakuDisplaySettings.maxOpacity,
          divisions: DanmakuDisplaySettings.opacitySteps,
          onChanged: editable
              ? (raw) => _changeDanmaku(
                  _danmaku.copyWith(
                    settings: settings.copyWith(
                      opacity: danmakuOpacityOf(raw),
                    ),
                  ),
                )
              : null,
        ),
        _danmakuSlider(
          label: '速度',
          value: danmakuSpeedLabel(settings.speed),
          sliderValue: settings.speed,
          min: DanmakuDisplaySettings.minSpeed,
          max: DanmakuDisplaySettings.maxSpeed,
          divisions: DanmakuDisplaySettings.speedSteps,
          onChanged: editable
              ? (raw) => _changeDanmaku(
                  _danmaku.copyWith(
                    settings: settings.copyWith(
                      speed: danmakuSpeedOf(raw),
                    ),
                  ),
                )
              : null,
        ),
      ],
    );
  }

  /// スライダー1つ。見出し行にラベルと現在値、下にスライダーを置く。
  Widget _danmakuSlider({
    required String label,
    required String value,
    required double sliderValue,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(title: Text(label), trailing: Text(value)),
        // スライダーは見出し行と同じ幅に取る。
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Slider(
            value: sliderValue,
            min: min,
            max: max,
            divisions: divisions,
            label: value,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildAudioPage(BuildContext context, LiveAudioLayout layout) {
    final checkColor = Theme.of(context).colorScheme.primary;
    return StreamBuilder<Tracks>(
      stream: widget.player.stream.tracks,
      builder: (context, tracksSnapshot) {
        final tracks =
            tracksSnapshot.data?.audio ?? widget.player.state.tracks.audio;
        return StreamBuilder<Track>(
          stream: widget.player.stream.track,
          builder: (context, trackSnapshot) {
            final current =
                trackSnapshot.data?.audio ?? widget.player.state.track.audio;
            final realTracks = _realAudioTracks(tracks);
            final mode = audioMenuMode(
              realAudioTrackCount: realTracks.length,
              layout: layout,
            );
            if (mode == AudioMenuMode.tracks) {
              // `auto` 選択中などで現在値が一覧に無くても先頭 (再生中) に付ける。
              final selected = currentAudioTrackIndex(
                tracks: realTracks,
                current: current,
              );
              return ListView(
                shrinkWrap: true,
                children: [
                  for (var i = 0; i < realTracks.length; i++)
                    ListTile(
                      title: Text(
                        audioTrackLabel(
                          title: realTracks[i].title,
                          language: realTracks[i].language,
                          index: i + 1,
                        ),
                      ),
                      trailing: i == selected
                          ? Icon(Icons.check, color: checkColor)
                          : null,
                      onTap: () => _pick(
                        () => widget.onAudioSelected(
                          AudioTrackChoice(realTracks[i].id),
                        ),
                      ),
                    ),
                ],
              );
            }
            if (mode == AudioMenuMode.dualMono) {
              // 判定できた時点で主音声へ倒しているため、初期状態は主音声。
              return ListView(
                shrinkWrap: true,
                children: [
                  _dualMonoTile(
                    context,
                    title: DualMonoChannel.main.label,
                    checked:
                        widget.dualMonoChannel != DualMonoChannel.sub,
                    choice: const DualMonoChoice(DualMonoChannel.main),
                  ),
                  _dualMonoTile(
                    context,
                    title: DualMonoChannel.sub.label,
                    checked: widget.dualMonoChannel == DualMonoChannel.sub,
                    choice: const DualMonoChoice(DualMonoChannel.sub),
                  ),
                ],
              );
            }
            // 選べない。1行だけ出して開かない。
            return ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  title: Text(
                    audioMenuLabel(
                      mode: mode,
                      layout: layout,
                      realAudioTracks: realTracks,
                      current: current,
                      dualMonoChannel: widget.dualMonoChannel,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _dualMonoTile(
    BuildContext context, {
    required String title,
    required bool checked,
    required AudioChoice choice,
  }) {
    return ListTile(
      title: Text(title),
      trailing: checked
          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: () => _pick(() => widget.onAudioSelected(choice)),
    );
  }
}
