import 'dart:async';

import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../data/nx_jikkyo/jikkyo_comment.dart';
import '../../data/nx_jikkyo/jikkyo_comment_list.dart';
import 'danmaku_settings.dart';
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
/// [preferences] が enabled のときは [DanmakuScreen] を組む。弾幕は明示的に
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
///
/// 表示設定 ([preferences]) はここで購読し、変更は (1) 各 [DanmakuScreen] の
/// [DanmakuController.updateOption] で配り、(2) 画面の組み直しで初期値を渡す。
/// `DanmakuScreen` は `option` を `initState` でしか読まない
/// (`didUpdateWidget` が無い) ため、引数 [DanmakuScreen.option] の差し替え
/// だけでは反映されない。購読はこの層の中に閉じる — 設定を変えるたびに映像まで
/// 作り直さないため ([PlayerPlaybackController] のコメント参照)。
class JikkyoDanmakuOverlay extends StatefulWidget {
  const JikkyoDanmakuOverlay({
    super.key,
    required this.controller,
    required this.store,
    required this.clock,
    required this.preferences,
    this.birthMsOf,
  });

  final JikkyoCommentSource controller;

  /// セッション所有の共有ストア (通常表示・フルスクリーンで共有)。
  final DanmakuStore<int> store;

  /// セッション所有の共有時計 (通常表示・フルスクリーンで共有)。
  final DanmakuClock clock;

  /// 弾幕の表示設定 (on/off と文字サイズ・不透明度・速度) の通知元。
  ///
  /// ここ (弾幕の層の中) で購読する。設定変更は弾幕のサブツリーにだけ
  /// 届かせ、映像を作り直さない。
  final ValueListenable<DanmakuPreferences> preferences;

  /// 録画用: コメントの時計 birth (再生位置0起点のms) を返す純粋関数。
  /// null ならライブ扱いで受信時を birth にする。
  final int Function(JikkyoComment comment)? birthMsOf;

  @override
  State<JikkyoDanmakuOverlay> createState() => _JikkyoDanmakuOverlayState();
}

class _JikkyoDanmakuOverlayState extends State<JikkyoDanmakuOverlay> {
  StreamSubscription<JikkyoComment>? _liveSub;

  /// 録画モードで登録済みの取得状態。同一 state の二重登録を防ぐ。
  JikkyoCommentsState? _addedState;

  /// 設定変更を配る対象の画面コントローラー。
  ///
  /// 通常表示とフルスクリーンの両方が同時に view として存在するため、登録
  /// 済みの画面すべてに配る。破棄された view は [_onDetach] で外す。外さないと
  /// 破棄済み notifier に触って `ChangeNotifier` の例外になる。
  final Set<DanmakuController<int>> _controllers = {};

  /// 幅のキャッシュを現在の文字サイズへ測り直した時の文字サイズ。
  ///
  /// 文字サイズが変わったことを ([_onPreferencesChanged] で) 判定する基準値。
  /// [initState] で [widget.preferences] の値から初期化する。
  double _measuredFontSize = 0;

  /// 破棄済みの State へ登録させないため [_onAttach] で弾く。
  bool _disposed = false;

  bool get _isLive => widget.birthMsOf == null;

  @override
  void initState() {
    super.initState();
    _measuredFontSize = danmakuOptionOf(
      widget.preferences.value.settings,
    ).fontSize;
    widget.preferences.addListener(_onPreferencesChanged);
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
    if (!identical(oldWidget.preferences, widget.preferences)) {
      oldWidget.preferences.removeListener(_onPreferencesChanged);
      widget.preferences.addListener(_onPreferencesChanged);
      // 購読先が変わったぶん、今の設定を各画面へ配り直す。
      _onPreferencesChanged();
    }
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

  /// 設定変更を各画面へ配る。
  ///
  /// 文字サイズが変わると、ストア内の幅と描画テクスチャは旧サイズのものなので
  /// 測り直す。`DanmakuScreen` 側の `updateOption` も同じキャッシュを落とす
  /// ため二重になるが、その間の再測定は起きない (同期的に連続して呼ぶだけ)。
  /// ここで落としておかないと、画面が作り直された直後に旧サイズで測った幅を
  /// 使ったまま描画してしまう。
  void _onPreferencesChanged() {
    final option = danmakuOptionOf(widget.preferences.value.settings);
    if (option.fontSize != _measuredFontSize) {
      _measuredFontSize = option.fontSize;
      widget.store.resetMeasurements();
      // 測定キャッシュを落としたこともストアの通知なので、次のフレームを立てる。
      _ensureFrame();
    }
    for (final controller in _controllers) {
      controller.updateOption(option);
    }
  }

  void _onAttach(DanmakuController<int> controller) {
    if (_disposed) return;
    _controllers.add(controller);
  }

  void _onDetach(DanmakuController<int> controller) {
    _controllers.remove(controller);
  }

  /// コメントの重複排除キー。通常表示とフルスクリーンの両方が購読するため、
  /// 同一コメントが二重に届く。
  static String _commentKey(JikkyoComment comment) =>
      '${comment.threadId}:${comment.no}';

  /// **ストア更新のあと、次のフレームを必ず立てる。**
  ///
  /// `DanmakuScreen` はストアの通知を受けて**描画されるフレームの最後**で起き
  /// 上がる (`_requestWake` が `SchedulerBinding.addPostFrameCallback` を
  /// 使う)。post-frame callback は描画されたフレームでしか走らないため、
  /// フレームが立たないままでは起き上がりが永久に届かない。
  ///
  /// 弾幕が1つも無い間はビューも ticker も止まっている (エンジンの「Ticker
  /// 自動停止」の最適化)。他に dirty なものが無ければフレーム自体継がず、
  /// **コメントがストアに溜まり続けるのに描画されない**。次に何かがフレームを
  /// 立てたとき (情報パネルのタブ切替・操作オーバーレイの表示など) ようやく
  /// 描画されるため、「何か操作するまで弾幕が出ない」という症状になる。
  /// Android は映像テクスチャの更新が常にフレームを立てるので表面化しにくいが、
  /// Linux/Wayland ではそのまま出る (実測)。
  ///
  /// 本来はエンジンの `_requestWake` に `ensureVisualUpdate()` を足すべきところ
  /// だが、ストアを書く当の層が「次のフレームが立つ」ことを保証する形にした
  /// ほうが確実で、フォークを持ち上げて revision を上げる必要も無い。
  /// 各地点での通知は 1 フレームへまとめられる (`_wakeScheduled` で合流)。
  void _ensureFrame() => SchedulerBinding.instance.ensureVisualUpdate();

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
    _ensureFrame();
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
      _ensureFrame();
    } else if (state.status == JikkyoCommentStatus.connecting) {
      // 取得し直し: 古い登録を捨て、完了時に取り直す。
      _addedState = null;
      widget.store.clear();
      _ensureFrame();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    widget.preferences.removeListener(_onPreferencesChanged);
    _controllers.clear();
    _liveSub?.cancel();
    widget.controller.removeListener(_onSourceChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // on/off と各項目の変更は弾幕の層の中に閉じる。設定ごとに映像の `Stack` を
    // 作り直さないため [preferences] をここで購読し、画面の組み直しだけを
    // 差し替える。既に作られている画面への反映は [DanmakuController.updateOption]
    // が担当する ([_onPreferencesChanged] 参照)。
    return ValueListenableBuilder<DanmakuPreferences>(
      valueListenable: widget.preferences,
      builder: (context, preferences, _) {
        if (!preferences.enabled) return const SizedBox.shrink();
        // 設定変更は [DanmakuController.updateOption] で配るので、ここは
        // 作られた時点の値でよい ([_onPreferencesChanged] 参照)。後から作られた
        // 画面がこの値をそのまま受け取る。
        return _DanmakuScreenView(
          option: danmakuOptionOf(preferences.settings),
          clock: widget.clock,
          store: widget.store,
          onAttach: _onAttach,
          onDetach: _onDetach,
        );
      },
    );
  }
}

/// `DanmakuScreen` 1つ分の view。コントローラーの登録生命周期だけを持つ。
///
/// `DanmakuScreen` は自身の破棄を親に通知しない ([DanmakuScreen] に
/// `dispose` コールバックが無い) ため、登録の解除はここ State の
/// [State.dispose] で行う。親が解除しないと、通常表示 → フルスクリーン
/// 切替や弾幕の on/off で破棄済みの notifier に `updateOption` を呼び、
/// `ChangeNotifier was used after being disposed` で落ちる。
class _DanmakuScreenView extends StatefulWidget {
  const _DanmakuScreenView({
    required this.option,
    required this.clock,
    required this.store,
    required this.onAttach,
    required this.onDetach,
  });

  /// この view が最初に使う表示設定。以後の変更は親から配られる。
  final DanmakuOption option;

  final DanmakuClock clock;
  final DanmakuStore<int> store;

  /// 画面が作られるときに呼ばれる。親側で変更を配る対象に加える。
  final ValueChanged<DanmakuController<int>> onAttach;

  /// この view が破棄されるときに呼ばれる。親側の対象から外す。
  final ValueChanged<DanmakuController<int>> onDetach;

  @override
  State<_DanmakuScreenView> createState() => _DanmakuScreenViewState();
}

class _DanmakuScreenViewState extends State<_DanmakuScreenView> {
  DanmakuController<int>? _controller;

  void _onCreated(DanmakuController<int> controller) {
    // `DanmakuScreen` は自身を作り直すことが無いため原則1回だけ呼ばれる。
    final previous = _controller;
    if (previous != null) widget.onDetach(previous);
    _controller = controller;
    widget.onAttach(controller);
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) widget.onDetach(controller);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DanmakuScreen<int>(
      // 通常表示とフルスクリーンで同じセッションの store/clock を見る。
      // どちらが後に構築されても描画内容は時計窓から決まるため、従来の
      // controller 上書き問題は起きない。設定は `option` で渡したあとに
      // `updateOption` で配る (親側 [_JikkyoDanmakuOverlayState] 参照)。
      clock: widget.clock,
      store: widget.store,
      option: widget.option,
      createdController: _onCreated,
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
    this.repaintKey,
    this.fullscreenRepaintKey,
  });

  /// 映像の表示アスペクト比 (幅 / 高さ)。未確定なら null。
  final double? displayAspect;

  /// 矩形内に描くウィジェット ([JikkyoDanmakuOverlay])。
  final Widget child;

  /// 弾幕付きキャプチャ用の撮像境界のキー。
  ///
  /// 弾幕レイヤーの**内側** (表示矩形そのもの) に [RepaintBoundary] を置く。
  /// 外側に置くとレターボックス分も撮像され、mpv 撮像 (黒帯なし) との合成で
  /// ズレる。内側なら両者は同じ矩形なので 1:1 で重なる。
  ///
  /// 所有者は store/clock と同じく回転で生き残る State
  /// (`_WatchLayoutState` / `_VideoPlayerState`) が持ち、ここでは参照する
  /// だけ。null のときは撮像しない。
  final GlobalKey? repaintKey;

  /// フルスクリーン側の撮像境界のキー。
  ///
  /// media_kit のフルスクリーンは同じ `controls` ビルダーから別サブツリーを
  /// 組むため、通常表示とフルスクリーンが一時的に同時に存在する。両方に同じ
  /// [GlobalKey] を置くと、後から組まれた方が Element を奪い、配下の
  /// [JikkyoDanmakuOverlay] の State ごと持っていく。フルスクリーンを閉じると
  /// 奪われた State が破棄され、通常側は作り直されないまま残るため弾幕が
  /// 消える (コメント購読もその State と一緒に死ぬ)。通常表示と
  /// フルスクリーンで別のキーを持ち、描画位置 ([isFullscreen]) で使い分ける。
  final GlobalKey? fullscreenRepaintKey;

  @override
  Widget build(BuildContext context) {
    final aspect = displayAspect;
    if (aspect == null) return const SizedBox.shrink();
    // 通常表示とフルスクリーンで撮像境界のキーを使い分ける (上記コメント参照)。
    // 同一キーでの重複を避けるため、フルスクリーン側は [fullscreenRepaintKey]
    // だけを見る (null なら境界なし)。
    final repaintKey =
        isFullscreen(context) ? fullscreenRepaintKey : this.repaintKey;
    Widget content = child;
    if (repaintKey != null) {
      content = RepaintBoundary(key: repaintKey, child: content);
    }
    return Align(child: AspectRatio(aspectRatio: aspect, child: content));
  }
}
