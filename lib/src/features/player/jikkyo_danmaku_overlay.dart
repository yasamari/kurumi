import 'dart:async';

import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/material.dart';

import '../../data/nx_jikkyo/jikkyo_comment.dart';
import 'jikkyo_comment_controller.dart';
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
/// 実況の接続自体は [JikkyoCommentController] が別に保持しているため、回転して
/// も切れない。
class JikkyoDanmakuOverlay extends StatefulWidget {
  const JikkyoDanmakuOverlay({
    super.key,
    required this.controller,
    required this.enabled,
  });

  final JikkyoCommentController controller;
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
