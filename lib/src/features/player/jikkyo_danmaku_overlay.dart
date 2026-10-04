import 'dart:async';

import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/material.dart';

import '../../data/nx_jikkyo/jikkyo_comment.dart';
import '../../data/nx_jikkyo/jikkyo_comment_list.dart';
import 'jikkyo_comment_source.dart';
import 'jikkyo_danmaku_item.dart';

/// 映像に重なる弾幕オーバーレイ。
///
/// media_kit の `Video` の `controls` ビルダーが返す `Stack` の中に
/// `Positioned.fill` で乗せる (`watch_screen.dart` 参照)。映像テクスチャと
/// 操作オーバーレイ (標準コントロール) の**間**に描くため、コントロールの
/// ボタンに隠れない。`DanmakuScreen` は `LayoutBuilder` で親の制約からサイズを
/// 取るため `Positioned.fill` が必須 (`Stack` の既定の loose では子にサイズが
/// 付かず幅 0 になる)。
///
/// [enabled] が false のときは [DanmakuScreen] を組まない。弾幕は明示的に
/// 有効にした時だけ Ticker を回したい。
///
/// 描画状態 ([DanmakuStore]) と時刻 ([DanmakuClock]) は回転・フルスクリーンで
/// 作り直されない所有者 (視聴画面のレイアウト State・録画の映像 State) が持ち、
/// ここでは参照するだけ。通常表示と media_kit のフルスクリーン (同じ
/// `controls` ビルダーから作られる別サブツリー) の両方から同じ store/clock を
/// 見るため、切替時に描画中の弾幕が消えない。コメントの二重購読は store の
/// 重複排除キーで吸収する。
///
/// コメントの取り込みは2通り:
/// - ライブ ([birthMsOf] が null): [JikkyoCommentSource.liveComments] を購読し、
///   受信時の時計値を birth にして登録する。
/// - 録画 ([birthMsOf] 指定): コントローラーの全件 (`state.comments`) を
///   `birthMsOf` で時刻換算して一括登録する。再生位置ではなく時計が可視窓を
///   決めるため、シーク先の表示期間内コメントは途中位置から描画される。
class JikkyoDanmakuOverlay extends StatefulWidget {
  const JikkyoDanmakuOverlay({
    super.key,
    required this.controller,
    required this.store,
    required this.clock,
    required this.enabled,
    this.birthMsOf,
  });

  final JikkyoCommentSource controller;

  /// セッション所有の共有ストア (通常表示・フルスクリーンで共有)。
  final DanmakuStore<int> store;

  /// セッション所有の共有時計 (通常表示・フルスクリーンで共有)。
  final DanmakuClock clock;

  final bool enabled;

  /// 録画用: コメントの時計 birth (再生位置0起点のms) を返す純粋関数。
  /// null ならライブ扱いで受信時を birth にする。
  final int Function(JikkyoComment comment)? birthMsOf;

  @override
  State<JikkyoDanmakuOverlay> createState() => _JikkyoDanmakuOverlayState();
}

class _JikkyoDanmakuOverlayState extends State<JikkyoDanmakuOverlay> {
  /// 弾幕の表示設定。
  ///
  /// 画面サイズに追従して軌道数が自動計算されるため、ここでのみ指定する。
  static const _option = DanmakuOption(
    // 既定16では実況の高速コメントが読めない。
    fontSize: 24,
    // 黒背景で読みやすくする。
    strokeWidth: 2.0,
    // 既定10秒は横流しが遅く感じる。
    duration: 8.0,
    // 全面に表示する。
    //
    // `safeArea` は `area == 1.0` のときだけ下端の字幕用トラックを1つ削る。
    // 全面表示を優先して無効にしている。字幕との重なりを優先する場合は true。
    area: 1.0,
    safeArea: false,
    // 軌道が埋まったら重ねずに捨てる (重ならない方が読みやすい)。
    massiveMode: false,
    // `ue` / `shita` を表現するため隠さない。
    hideTop: false,
    hideBottom: false,
  );

  StreamSubscription<JikkyoComment>? _liveSub;

  /// 録画モードで登録済みの取得状態。同一 state の二重登録を防ぐ。
  JikkyoCommentsState? _addedState;

  bool get _isLive => widget.birthMsOf == null;

  @override
  void initState() {
    super.initState();
    if (_isLive) {
      // 弾幕に出すのは購読直後のバックログを除いた新規コメントだけ。
      _liveSub = widget.controller.liveComments.listen(_onLiveComment);
    } else {
      widget.controller.addListener(_onSourceChanged);
      _onSourceChanged();
    }
  }

  @override
  void didUpdateWidget(JikkyoDanmakuOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.controller, widget.controller) &&
        identical(oldWidget.store, widget.store) &&
        identical(oldWidget.clock, widget.clock)) {
      return;
    }
    _liveSub?.cancel();
    _liveSub = null;
    oldWidget.controller.removeListener(_onSourceChanged);
    _addedState = null;
    if (_isLive) {
      _liveSub = widget.controller.liveComments.listen(_onLiveComment);
    } else {
      widget.controller.addListener(_onSourceChanged);
      _onSourceChanged();
    }
  }

  /// コメントの重複排除キー。通常表示とフルスクリーンの両方が購読するため、
  /// 同一コメントが二重に届く。
  static String _commentKey(JikkyoComment comment) =>
      '${comment.threadId}:${comment.no}';

  void _onLiveComment(JikkyoComment comment) {
    // 受信時の時計値を birth にする。store へ直接登録するため、
    // `DanmakuScreen` 未構築 (無効時) でも捨てずに保持される。
    widget.store.add(
      DanmakuItem(
        content: buildJikkyoDanmaku(comment),
        width: 0,
        height: 0,
        birthTick: widget.clock.nowMs,
      ),
      key: _commentKey(comment),
    );
  }

  void _onSourceChanged() {
    final state = widget.controller.state;
    if (state.status == JikkyoCommentStatus.ready) {
      if (identical(state, _addedState)) return;
      _addedState = state;
      final birthMsOf = widget.birthMsOf;
      if (birthMsOf == null) return;
      widget.store.addAll(
        state.comments.map(
          (comment) => (
            content: buildJikkyoDanmaku(comment),
            birthTick: birthMsOf(comment),
            key: _commentKey(comment),
          ),
        ),
        widget.clock.nowMs,
      );
    } else if (state.status == JikkyoCommentStatus.connecting) {
      // 取得し直し: 古い登録を捨て、完了時に取り直す。
      _addedState = null;
      widget.store.clear();
    }
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    widget.controller.removeListener(_onSourceChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();
    return DanmakuScreen<int>(
      // 通常表示とフルスクリーンで同じセッションの store/clock を見る。
      // どちらが後に構築されても描画内容は時計窓から決まるため、従来の
      // controller 上書き問題は起きない。設定変更は現状ないため
      // controller は保持しない。
      clock: widget.clock,
      store: widget.store,
      createdController: (_) {},
      // 設定は画面固定なので `initState` で読まれるこの引数で十分。変更したい
      // 場合は `createdController` で受けた `controller.updateOption` を使うこと。
      option: _option,
    );
  }
}

/// 映像の**表示**矩形に収めて弾幕を載せる層。
///
/// `Video` は `FittedBox(fit: BoxFit.contain)` で描くため、そのまま重ねると
/// レターボックス (黒帯・柱状) にも弾幕が出る。[displayAspect] は表示
/// アスペクト比 (幅/高さ) で、これを指定した `Align` + `AspectRatio` は
/// `FittedBox(contain)` と**同じ矩形**になるので、幅高を自前で計算しなくてよい。
///
/// [displayAspect] が null のときは何も描画しない。比は mpv の `video-params`
/// が届くまで未定のため (起動直後・音声のみ)、この間に弾幕を出さない。
///
/// [displayAspect] には**符号化サイズではなく表示アスペクト比**を渡すこと。
/// 日本語デジタル放送には 1440x1080 を 16:9 に引き伸ばすチャンネルが多く、
/// mpv が PAR 12:11 として持つため `w`/`h` だと 1.333 になるが、表示は 1.778。
/// ここを間違えると矩形が縦に伸びて弾幕が黒帯に侵入し、かつ端に届かない。
/// 比の算出は `videoDisplayAspectOf` (pure 関数、`player_error.dart`) が行う。
///
/// この層は `PlayerVideoView` が映像の controls レイヤー内に載せる。描画位置の
/// 制約 (コントロールより上・映像テクスチャより下) はそちらのコメントを参照。
class JikkyoDanmakuLayer extends StatelessWidget {
  const JikkyoDanmakuLayer({
    super.key,
    required this.displayAspect,
    required this.child,
  });

  /// 映像の表示アスペクト比 (幅 / 高さ)。未確定なら null。
  final double? displayAspect;

  /// 矩形内に描くウィジェット ([JikkyoDanmakuOverlay])。
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final aspect = displayAspect;
    if (aspect == null) return const SizedBox.shrink();
    return Align(child: AspectRatio(aspectRatio: aspect, child: child));
  }
}
