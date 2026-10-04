import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'player_controls_theme.dart';
import 'player_status_views.dart';

/// 標準コントロールを表示した時間を決める待ち時間。
///
/// 既定3秒だと画質メニュー (全17件) を操作する前に消えてしまうため、長く
/// 表示し続ける。
const playerControlsHoverDuration = Duration(seconds: 15);

/// 標準コントロールのボタン構成の取り方。
///
/// ライブ視聴と録画再生で標準コントロールの挙動が異なる (シークするか、
/// 中央・下端のボタンが何か) ため、テーマデータの組み立てはこの2通りだけ。
/// ボタン行は media_kit のテーマデータが非 nullable なので、既定のままに
/// する方を分岐で切り替える (既定値を自前で書き写さない)。
enum PlayerControlsLayout {
  /// 録画再生。シークバーを出し、前/次ボタンは media_kit の既定に任せる。
  seekable,

  /// ライブ視聴。シークバーを出さず、前/次チャンネル送りを中央に置き、
  /// 下端から再生時刻表示を外す。
  live,
}

/// 映像+標準コントロール+弾幕+エラー表示。ライブ視聴と録画再生で共有する。
///
/// media_kit 標準のコントロールをプラットフォームごとに自動選択させる。
/// シーク可否やボタン構成の違いは [layout] で表す。
///
/// **このウィジェットは向きに依存しない単一の `Stack` を返す。** 画面回転や
/// media_kit の fullscreen (ウィンドウサイズが変わる°) で映像のサブツリーが
/// 破棄されると、State が持つ mpv のプレイヤーと再生セッションが解放され、
/// fullscreen 側は破棄済みの [VideoController] を参照したままになる。結果として
/// 映像は黒く止まり、音声だけは作り直されたプレイヤーから出る。親を `Row`/
/// `Column` で出し分けないこと (`PlayerSplitLayout` のコメントを参照)。
///
/// [danmaku] の描画位置は**映像の controls レイヤーの内側**。media_kit の
/// `Video` は「映像テクスチャ → 字幕 → 標準コントロール」を内側の `Stack` で
/// 描画しているため、外側の `Stack` に重ねると (1) コントロールより上になる/
/// (2) 順序を入れ替えると映像テクスチャより下になって見えない、のどちらかで
/// 破綻する。差し込めるのは controls レイヤーの内側だけ。
///
/// コントロール自動非表示時 (`mount=false`) でもビルダーの返り値はツリーに
/// 残るため、弾幕だけが消えることはない。
class PlayerVideoView extends StatelessWidget {
  const PlayerVideoView({
    super.key,
    required this.videoController,
    required this.topButtonBar,
    required this.layout,
    this.livePrimaryButtonBar,
    this.liveBottomButtonBar,
    this.liveDesktopBottomButtonBar,
    this.seekableBottomButtonBar,
    this.seekableDesktopBottomButtonBar,
    this.danmaku,
    this.errorMessage,
    this.onRetry,
  }) : assert(
         layout != PlayerControlsLayout.live ||
             (livePrimaryButtonBar != null &&
                 liveBottomButtonBar != null &&
                 liveDesktopBottomButtonBar != null),
         'ライブではボタン行をすべて指定する必要があります',
       );

  /// 映像のコントローラー。
  final VideoController videoController;

  /// 標準コントロールの上部ボタンバー。戻るボタン・タイトル。
  final List<Widget> topButtonBar;

  /// 標準コントロールのボタン構成。
  final PlayerControlsLayout layout;

  /// ライブのモバイル中央ボタン行 ([PlayerControlsLayout.live] のみ使う)。
  final List<Widget>? livePrimaryButtonBar;

  /// ライブのモバイル下端ボタン行 ([PlayerControlsLayout.live] のみ使う)。
  final List<Widget>? liveBottomButtonBar;

  /// ライブのデスクトップ下端ボタン行 ([PlayerControlsLayout.live] のみ使う)。
  final List<Widget>? liveDesktopBottomButtonBar;

  /// 録画のモバイル下端ボタン行 ([PlayerControlsLayout.seekable] のみ使う)。
  /// null のときは media_kit の既定を使う。
  final List<Widget>? seekableBottomButtonBar;

  /// 録画のデスクトップ下端ボタン行 ([PlayerControlsLayout.seekable] のみ使う)。
  /// null のときは media_kit の既定を使う。
  final List<Widget>? seekableDesktopBottomButtonBar;

  /// controls レイヤー内に描く弾幕。null なら描かない。
  ///
  /// レターボックスに掛からないよう `JikkyoDanmakuLayer` で矩形を絞った
  /// ものを渡す。
  final Widget? danmaku;

  /// 再生エラーの内容。null ならエラー表示しない。
  final String? errorMessage;

  /// エラー表示の「再試行」。[errorMessage] が null のときは表示しない。
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    // 映像が画面端まで描画されているかどうか (横画面) を表す。標準コントロールは
    // 映像の `Stack` 内に載るため映像からはみ出すことはないが、横画面は外側の
    // `SafeArea` が無いので、コントロール自身がシステムインセットを避ける。
    // 下端のボタン (フルスクリーン) がシステムナビゲーションに重ならないため
    // だが、上端の戻るボタンもノッチを避けることになる。
    final fullBleed =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    // シークバーはアプリの Dynamic Color に合わせる (既定は白+赤)。
    // ライブでは出さないが、録画再生と配色がバラバラにならないよう両方の
    // テーマデータに入れておく。
    final seekBar = seekBarColorsFrom(Theme.of(context).colorScheme);

    // 通常表示とフルスクリーンは余白が違うのでテーマデータを分ける
    // (縦画面の通常表示は外側の `SafeArea` がインセットを消費済み)。
    MaterialVideoControlsThemeData mobileTheme({required bool fullscreen}) {
      final insets = playerMobileControlsInsets(
        fullBleed: fullBleed,
        fullscreen: fullscreen,
        systemPadding: MediaQuery.paddingOf(context),
      );
      if (layout == PlayerControlsLayout.live) {
        // 中央ボタンは既定のプレイリスト送り (単品再生では無動作) の代わりに、
        // 前/次チャンネル送りを置く。大きさ・間隔は既定の構成を踏襲する。
        return MaterialVideoControlsThemeData(
          displaySeekBar: false,
          seekGesture: false,
          seekOnDoubleTap: false,
          automaticallyImplySkipNextButton: false,
          automaticallyImplySkipPreviousButton: false,
          primaryButtonBar: livePrimaryButtonBar!,
          // ライブに再生時刻表示は不要のため、時刻表示を外して
          // フルスクリーンボタンだけ残す。
          bottomButtonBar: liveBottomButtonBar!,
          // 既定 (`padding` が null) では下端のボタンが画面最下端に載り、
          // 横画面ではシステムナビゲーションに重なる。回避はテーマデータ側で
          // しかできないので明示する。
          padding: insets.padding,
          seekBarColor: seekBar.track,
          seekBarBufferColor: seekBar.buffer,
          seekBarPositionColor: seekBar.position,
          seekBarThumbColor: seekBar.thumb,
          topButtonBar: topButtonBar,
          // 画面を開いた直後は操作ボタン (戻るボタン等) を表示しておく。
          visibleOnMount: true,
          controlsHoverDuration: playerControlsHoverDuration,
        );
      }
      var theme = MaterialVideoControlsThemeData(
        // 既定 (`EdgeInsets.zero`) ではシークバーがボタン行の下・画面端に落ち
        // るので、横画面・フルスクリーンではボタン行の上へ持ち上げる。
        seekBarMargin: insets.seekBarMargin,
        padding: insets.padding,
        seekBarColor: seekBar.track,
        seekBarBufferColor: seekBar.buffer,
        seekBarPositionColor: seekBar.position,
        seekBarThumbColor: seekBar.thumb,
        topButtonBar: topButtonBar,
        // 画面を開いた直後は操作ボタン (戻るボタン等) を表示しておく。
        visibleOnMount: true,
        controlsHoverDuration: playerControlsHoverDuration,
      );
      // 録画の下端ボタン行は字幕・設定をフルスクリーンの左に足すときだけ
      // 上書きする。null のときは media_kit の既定のまま (書き写さない)。
      final seekableBottom = seekableBottomButtonBar;
      if (seekableBottom != null) {
        theme = theme.copyWith(bottomButtonBar: seekableBottom);
      }
      return theme;
    }

    MaterialDesktopVideoControlsThemeData desktopTheme() {
      if (layout == PlayerControlsLayout.live) {
        return MaterialDesktopVideoControlsThemeData(
          displaySeekBar: false,
          automaticallyImplySkipNextButton: false,
          automaticallyImplySkipPreviousButton: false,
          // ライブに再生時刻表示は不要のため、時刻表示を外して
          // 前/次 (チャンネル送り)・再生・音量・フルスクリーンボタンを残す。
          bottomButtonBar: liveDesktopBottomButtonBar!,
          // モバイル側と同じ配色 (ライブではシークバーを出さない)。
          seekBarColor: seekBar.track,
          seekBarBufferColor: seekBar.buffer,
          seekBarPositionColor: seekBar.position,
          seekBarThumbColor: seekBar.thumb,
          topButtonBar: topButtonBar,
          // 画面を開いた直後は操作ボタン (戻るボタン等) を表示しておく。
          visibleOnMount: true,
          controlsHoverDuration: playerControlsHoverDuration,
        );
      }
      var theme = MaterialDesktopVideoControlsThemeData(
        seekBarColor: seekBar.track,
        seekBarBufferColor: seekBar.buffer,
        seekBarPositionColor: seekBar.position,
        seekBarThumbColor: seekBar.thumb,
        topButtonBar: topButtonBar,
        // 画面を開いた直後は操作ボタン (戻るボタン等) を表示しておく。
        visibleOnMount: true,
        controlsHoverDuration: playerControlsHoverDuration,
      );
      // モバイル側と同じく、録画の下端ボタン行の上書きは指定があるときだけ。
      final seekableBottom = seekableDesktopBottomButtonBar;
      if (seekableBottom != null) {
        theme = theme.copyWith(bottomButtonBar: seekableBottom);
      }
      return theme;
    }

    final desktop = desktopTheme();
    final error = errorMessage;
    final retry = onRetry;
    final danmakuLayer = danmaku;
    return Stack(
      children: [
        MaterialVideoControlsTheme(
          normal: mobileTheme(fullscreen: false),
          fullscreen: mobileTheme(fullscreen: true),
          child: MaterialDesktopVideoControlsTheme(
            normal: desktop,
            fullscreen: desktop,
            // media_kit 標準 UI。プラットフォームで自動切替される。
            child: Video(
              controller: videoController,
              controls: (state) => Stack(
                // `Video` 側は `Positioned.fill` で tight 制約を渡している。
                // 標準コントロールに loose な制約を渡すとグラデーション等が
                // 縮むため、`Video` と同じ tight 制約を渡す。
                fit: StackFit.expand,
                children: [
                  if (danmakuLayer != null)
                    Positioned.fill(child: danmakuLayer),
                  AdaptiveVideoControls(state),
                ],
              ),
            ),
          ),
        ),
        if (error != null && retry != null)
          PlayerErrorOverlay(message: error, onRetry: retry),
      ],
    );
  }
}
