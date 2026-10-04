import 'dart:async';

import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/material.dart';

import '../../data/nx_jikkyo/jikkyo_comment.dart';
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
/// **このウィジェットは映像の `Stack` 内にあるため画面回転で作り直される。**
/// 参照と購読はこの State が持ち、作り直しのたびに `createdController` で取り
/// 直す。弾幕は一時的なアニメーションなので作り直しで消えるのは許容する。
/// 実況の接続自体は [JikkyoCommentSource] が別に保持しているため、回転して
/// も切れない。
class JikkyoDanmakuOverlay extends StatefulWidget {
  const JikkyoDanmakuOverlay({
    super.key,
    required this.controller,
    required this.enabled,
  });

  final JikkyoCommentSource controller;
  final bool enabled;

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

  DanmakuController<int>? _danmaku;
  StreamSubscription<JikkyoComment>? _liveSub;
  Brightness _brightness = Brightness.light;

  @override
  void initState() {
    super.initState();
    // 弾幕に出すのは購読直後のバックログを除いた新規コメントだけ。
    _liveSub = widget.controller.liveComments.listen(_onComment);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _brightness = Theme.of(context).brightness;
  }

  @override
  void didUpdateWidget(JikkyoDanmakuOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.controller, widget.controller)) return;
    _liveSub?.cancel();
    _liveSub = widget.controller.liveComments.listen(_onComment);
  }

  void _onComment(JikkyoComment comment) {
    // まだ `DanmakuScreen` が initState に入っていない (無効時) は捨てる。
    final danmaku = _danmaku;
    if (danmaku == null) return;
    danmaku.addDanmaku(buildJikkyoDanmaku(comment, brightness: _brightness));
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();
    return DanmakuScreen<int>(
      // 画面回転で作り直されたときに旧 controller を掴まないように、毎回ここで
      // 参照を差し替える。旧 State の controller を掴んだままだと破棄済みなので
      // 何も描画されない。
      createdController: (controller) => _danmaku = controller,
      // 設定は画面固定なので `initState` で読まれるこの引数で十分。変更したい
      // 場合は `controller.updateOption` を使うこと。
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
