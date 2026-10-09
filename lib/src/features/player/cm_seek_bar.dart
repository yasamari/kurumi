import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video_controls/src/controls/methods/video_state.dart';

import '../../domain/entities/cm_section.dart';
import 'cm_material_controls.dart';
import 'cm_material_desktop_controls.dart';
import 'cm_sections.dart';
import 'player_controls_theme.dart';

/// トラックに重ねるCM区間の不透明度。進捗・バッファを透けさせたまま
/// tertiary系の色味を残す。
const _cmOverlayAlpha = 0.55;

/// CM区間付きシークバー。media_kit の `MaterialSeekBar` /
/// `MaterialDesktopSeekBar` のフォーク。
///
/// トラックの3層 (地・バッファ・再生位置) にCM区間を重ね、つまみを最前面に
/// 置く。標準シークバーと同じ余白・寸法・操作を使うため、見た目の位置は
/// CM区間がなくても変わらない。
///
/// **なぜフォークなのか**: media_kit はシークバーのマーカー類を持たず、
/// 既存のトラックに何かを重ねる方法も提供していない。下端ボタン行の
/// `Stack` に被せる案は `Row` 内の非有界幅で `Stack` がレイアウトできず
/// (ヒットテスト不能)、コントロール層の外に置く案は自動非表示との連動が
/// 取れないため、標準コントロールのうちシークバーだけを复制して持つ。
/// 差分は `// KURUMI-CM` を付け、テーマ・ボタン類は package のものを使う
/// (AGENTS.md の「Native media stack」節を参照)。
class CmSeekBar extends StatefulWidget {
  const CmSeekBar({
    super.key,
    this.delta,
    this.onSeekStart,
    this.onSeekEnd,
    required this.cmSections,
    required this.isDesktop,
  });

  final ValueNotifier<Duration>? delta;
  final VoidCallback? onSeekStart;
  final VoidCallback? onSeekEnd;

  /// CM区間一覧 ([normalizeCmSections] 済みを想定)。空なら標準シークバーと
  /// 同じ見た目になる。
  final List<CmSection> cmSections;

  /// デスクトップ (ホバーで伸びるシークバー) かどうか。
  final bool isDesktop;

  @override
  CmSeekBarState createState() => CmSeekBarState();
}

class CmSeekBarState extends State<CmSeekBar> {
  bool tapped = false;
  double slider = 0.0;

  late bool playing = controller(context).player.state.playing;
  late Duration position = controller(context).player.state.position;
  late Duration duration = controller(context).player.state.duration;
  late Duration buffer = controller(context).player.state.buffer;

  /// デスクトップのホバー状態。トラックを少し厚くし、つまみを出す。
  bool hover = false;

  final List<StreamSubscription> subscriptions = [];

  @override
  void setState(VoidCallback fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  void listener() {
    setState(() {
      final delta = widget.delta?.value ?? Duration.zero;
      position = controller(context).player.state.position + delta;
    });
  }

  @override
  void initState() {
    super.initState();
    widget.delta?.addListener(listener);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (subscriptions.isEmpty && widget.delta == null) {
      subscriptions.addAll([
        controller(context).player.stream.playing.listen((event) {
          setState(() {
            playing = event;
          });
        }),
        controller(context).player.stream.completed.listen((event) {
          setState(() {
            position = Duration.zero;
          });
        }),
        controller(context).player.stream.position.listen((event) {
          setState(() {
            if (!tapped) {
              position = event;
            }
          });
        }),
        controller(context).player.stream.duration.listen((event) {
          setState(() {
            duration = event;
          });
        }),
        controller(context).player.stream.buffer.listen((event) {
          setState(() {
            buffer = event;
          });
        }),
      ]);
    }
  }

  @override
  void dispose() {
    widget.delta?.removeListener(listener);
    for (final subscription in subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  void onPointerMove(PointerMoveEvent e, BoxConstraints constraints) {
    final percent = e.localPosition.dx / constraints.maxWidth;
    setState(() {
      tapped = true;
      slider = percent.clamp(0.0, 1.0);
    });
    controller(context).player.seek(duration * slider);
  }

  void onPointerDown() {
    widget.onSeekStart?.call();
    setState(() {
      tapped = true;
    });
  }

  void onPointerUp() {
    widget.onSeekEnd?.call();
    setState(() {
      // Explicitly set the position to prevent the slider from jumping.
      tapped = false;
      position = duration * slider;
    });
    controller(context).player.seek(duration * slider);
  }

  void onPanStart(DragStartDetails e, BoxConstraints constraints) {
    final percent = e.localPosition.dx / constraints.maxWidth;
    setState(() {
      tapped = true;
      slider = percent.clamp(0.0, 1.0);
    });
  }

  void onPanDown(DragDownDetails e, BoxConstraints constraints) {
    final percent = e.localPosition.dx / constraints.maxWidth;
    setState(() {
      tapped = true;
      slider = percent.clamp(0.0, 1.0);
    });
  }

  void onPanUpdate(DragUpdateDetails e, BoxConstraints constraints) {
    final percent = e.localPosition.dx / constraints.maxWidth;
    setState(() {
      tapped = true;
      slider = percent.clamp(0.0, 1.0);
    });
  }

  // KURUMI-CM: デスクトップのホバー。標準側 (`MaterialDesktopSeekBar`) の
  // `onHover` / `onEnter` / `onExit` と同じ。
  void onHover(PointerHoverEvent e, BoxConstraints constraints) {
    final percent = e.localPosition.dx / constraints.maxWidth;
    setState(() {
      hover = true;
      slider = percent.clamp(0.0, 1.0);
    });
  }

  void onEnter(PointerEnterEvent e, BoxConstraints constraints) {
    final percent = e.localPosition.dx / constraints.maxWidth;
    setState(() {
      hover = true;
      slider = percent.clamp(0.0, 1.0);
    });
  }

  void onExit(PointerExitEvent e) {
    setState(() {
      hover = false;
      slider = 0.0;
    });
  }

  /// Returns the current playback position in percentage.
  double get positionPercent {
    if (position == Duration.zero || duration == Duration.zero) {
      return 0.0;
    } else {
      final value = position.inMilliseconds / duration.inMilliseconds;
      return value.clamp(0.0, 1.0);
    }
  }

  /// Returns the current playback buffer position in percentage.
  double get bufferPercent {
    if (buffer == Duration.zero || duration == Duration.zero) {
      return 0.0;
    } else {
      final value = buffer.inMilliseconds / duration.inMilliseconds;
      return value.clamp(0.0, 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = cmSeekBarThemeOf(context, isDesktop: widget.isDesktop);
    final cmColor = cmSectionColorFrom(Theme.of(context).colorScheme);
    final durationSec = duration.inMilliseconds / 1000.0;
    final fractions = cmSectionFractions(widget.cmSections, durationSec);
    // KURUMI-CM: ホバー位置の表示はデスクトップだけ。
    final showHover = widget.isDesktop && hover;
    final trackHeight = showHover ? theme.hoverHeight : theme.height;
    return Container(
      clipBehavior: Clip.none,
      margin: theme.margin,
      child: LayoutBuilder(
        builder: (context, constraints) => MouseRegion(
          cursor: SystemMouseCursors.click,
          onHover: widget.isDesktop ? (e) => onHover(e, constraints) : null,
          onEnter: widget.isDesktop ? (e) => onEnter(e, constraints) : null,
          onExit: widget.isDesktop ? onExit : null,
          child: GestureDetector(
            onHorizontalDragUpdate: (_) {},
            onPanStart: (e) => onPanStart(e, constraints),
            onPanDown: (e) => onPanDown(e, constraints),
            onPanUpdate: (e) => onPanUpdate(e, constraints),
            child: Listener(
              onPointerMove: (e) => onPointerMove(e, constraints),
              onPointerDown: (_) => onPointerDown(),
              onPointerUp: (_) => onPointerUp(),
              child: Container(
                color: const Color(0x00000000),
                width: constraints.maxWidth,
                alignment: theme.alignment,
                height: theme.containerHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerLeft,
                  children: [
                    AnimatedContainer(
                      width: constraints.maxWidth,
                      height: trackHeight,
                      alignment: Alignment.centerLeft,
                      duration: widget.isDesktop
                          ? const Duration(milliseconds: 150)
                          : Duration.zero,
                      color: theme.track,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.centerLeft,
                        children: [
                          // KURUMI-CM: ホバー位置の表示 (デスクトップのみ)。
                          if (showHover)
                            Container(
                              width: constraints.maxWidth * slider,
                              color: theme.hover,
                            ),
                          Container(
                            width: constraints.maxWidth * bufferPercent,
                            color: theme.buffer,
                          ),
                          Container(
                            width: tapped
                                ? constraints.maxWidth * slider
                                : constraints.maxWidth * positionPercent,
                            color: theme.position,
                          ),
                          // KURUMI-CM: CM区間。進捗より上・つまみより下に
                          // 重ねる。再生尺が未確定なら割合が出ない。
                          for (final fraction in fractions)
                            Positioned(
                              left: constraints.maxWidth * fraction.start,
                              width:
                                  constraints.maxWidth *
                                  (fraction.end - fraction.start),
                              top: 0,
                              bottom: 0,
                              child: Container(
                                color: cmColor.withValues(
                                  alpha: _cmOverlayAlpha,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: tapped
                          ? (constraints.maxWidth - theme.thumbSize / 2) *
                                slider
                          : (constraints.maxWidth - theme.thumbSize / 2) *
                                positionPercent,
                      child: Center(
                        child: AnimatedContainer(
                          width: widget.isDesktop && !(hover || tapped)
                              ? 0.0
                              : theme.thumbSize,
                          height: widget.isDesktop && !(hover || tapped)
                              ? 0.0
                              : theme.thumbSize,
                          duration: widget.isDesktop
                              ? const Duration(milliseconds: 150)
                              : Duration.zero,
                          decoration: BoxDecoration(
                            color: theme.thumb,
                            borderRadius: BorderRadius.circular(
                              theme.thumbSize / 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// シークバーのテーマ値。モバイル / デスクトップの別クラスから同じ形で
/// 取り出す ([CmSeekBar] が両方で使うため)。
({
  EdgeInsets margin,
  Alignment alignment,
  double containerHeight,
  double height,
  double hoverHeight,
  Color track,
  Color buffer,
  Color position,
  double thumbSize,
  Color thumb,
  Color hover,
})
cmSeekBarThemeOf(BuildContext context, {required bool isDesktop}) {
  if (isDesktop) {
    final theme = cmDesktopVideoControlsThemeOf(context);
    return (
      margin: theme.seekBarMargin,
      alignment: Alignment.centerLeft,
      containerHeight: theme.seekBarContainerHeight,
      height: theme.seekBarHeight,
      hoverHeight: theme.seekBarHoverHeight,
      track: theme.seekBarColor,
      buffer: theme.seekBarBufferColor,
      position: theme.seekBarPositionColor,
      thumbSize: theme.seekBarThumbSize,
      thumb: theme.seekBarThumbColor,
      hover: theme.seekBarHoverColor,
    );
  }
  final theme = cmMobileVideoControlsThemeOf(context);
  return (
    margin: theme.seekBarMargin,
    alignment: theme.seekBarAlignment,
    containerHeight: theme.seekBarContainerHeight,
    height: theme.seekBarHeight,
    hoverHeight: theme.seekBarHeight,
    track: theme.seekBarColor,
    buffer: theme.seekBarBufferColor,
    position: theme.seekBarPositionColor,
    thumbSize: theme.seekBarThumbSize,
    thumb: theme.seekBarThumbColor,
    hover: theme.seekBarBufferColor,
  );
}

/// CM区間中の手動スキップボタン。下端ボタン行に置く。
///
/// 再生位置がCM区間に入っている間だけ現れる (それ以外は大きさゼロで
/// ボタン行の並びに影響しない)。下端ボタン行は標準コントロールの表示中
/// だけ組まれるため、自動非表示・PiP・フルスクリーン切替に連動する。
///
/// 位置購読はこのサブツリーの中だけで行い、映像の再構築には波及させない。
class CmSkipButton extends StatelessWidget {
  const CmSkipButton({
    super.key,
    required this.player,
    required this.cmSections,
    this.color,
  });

  /// 再生中の mpv プレイヤー。
  final Player player;

  /// CM区間一覧。
  final List<CmSection> cmSections;

  /// アイコンの色。下端ボタン行の他のボタンに合わせる (既定は白)。
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (cmSections.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<Duration>(
      stream: player.stream.position,
      initialData: player.state.position,
      builder: (context, snapshot) {
        final positionSec =
            (snapshot.data ?? player.state.position).inMilliseconds / 1000.0;
        if (cmSectionAt(cmSections, positionSec) == null) {
          return const SizedBox.shrink();
        }
        return IconButton(
          icon: const Icon(Icons.fast_forward),
          color: color ?? const Color(0xFFFFFFFF),
          tooltip: 'CMスキップ',
          onPressed: () {
            final target = cmSkipTargetSec(cmSections, positionSec);
            if (target == null) return;
            unawaited(
              player.seek(Duration(milliseconds: (target * 1000).round())),
            );
          },
        );
      },
    );
  }
}
