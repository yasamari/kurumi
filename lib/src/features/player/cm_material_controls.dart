// This file is a part of media_kit (https://github.com/media-kit/media-kit).
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the LICENSE file.
// ignore_for_file: non_constant_identifier_names
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:media_kit_video/media_kit_video_controls/src/controls/extensions/duration.dart';
import 'package:media_kit_video/media_kit_video_controls/src/controls/methods/video_state.dart';
import 'package:media_kit_video/media_kit_video_controls/src/controls/widgets/video_controls_theme_data_injector.dart';

import '../../domain/entities/cm_section.dart';
import '../../domain/entities/video_thumbnail_tiles.dart';
import 'cm_seek_bar.dart';

// KURUMI-CM: media_kit_video 2.0.1 のフォーク。CM区間表示のため、テーマ・
// ボタン類は package のものをそのまま使い、状態とシークバーのみを持つ。
// `// KURUMI-CM` 付きの差分だけが独自分。更新時は upstream 差分に付け直す
// (AGENTS.md 参照)。

/// CM区間付きのモバイル標準コントロール。使い方は
/// [MaterialVideoControls] と同じで、[cmSections] が空でないときに
/// シークバーへ重ねて表示する。
///
/// [seekThumbnail] を与えると、シークバーのホバー位置にサムネイル
/// プレビューを出す (録画再生のみ。ライブでは null)。
Widget CmMaterialVideoControls(
  VideoState state, {
  List<CmSection> cmSections = const [],
  VideoThumbnailTiles? seekThumbnail,
}) {
  return VideoControlsThemeDataInjector(
    child: _MaterialVideoControls(
      cmSections: cmSections,
      seekThumbnail: seekThumbnail,
    ),
  );
}

// KURUMI-CM: テーマは package のものを使う (同名宣言は削除済み)。
MaterialVideoControlsThemeData _theme(BuildContext context) =>
    FullscreenInheritedWidget.maybeOf(context) == null
    ? MaterialVideoControlsTheme.maybeOf(context)?.normal ??
          kDefaultMaterialVideoControlsThemeData
    : MaterialVideoControlsTheme.maybeOf(context)?.fullscreen ??
          kDefaultMaterialVideoControlsThemeDataFullscreen;

// KURUMI-CM: [CmSeekBar] が同じテーマを読むための公開アクセサー。
MaterialVideoControlsThemeData cmMobileVideoControlsThemeOf(
  BuildContext context,
) => _theme(context);

/// {@macro material_video_controls}
class _MaterialVideoControls extends StatefulWidget {
  // KURUMI-CM: CM区間一覧。シークバーとスキップボタンが使う。
  const _MaterialVideoControls({
    this.cmSections = const [],
    this.seekThumbnail,
  });

  final List<CmSection> cmSections;

  /// シークバーのホバー位置に出すサムネイル並び。null なら出さない。
  final VideoThumbnailTiles? seekThumbnail;

  @override
  State<_MaterialVideoControls> createState() => _MaterialVideoControlsState();
}

/// {@macro material_video_controls}
class _MaterialVideoControlsState extends State<_MaterialVideoControls> {
  late bool mount;
  late bool visible;
  Timer? _timer;

  double _brightnessValue = 0.0;
  bool _brightnessIndicator = false;
  Timer? _brightnessTimer;
  double _currentRate = 1.0;
  double _volumeValue = 0.0;
  bool _volumeIndicator = false;
  Timer? _volumeTimer;

  void Function()? _onBrightnessReset;

  Offset _dragInitialDelta =
      Offset.zero; // Initial position for horizontal drag
  int swipeDuration = 0; // Duration to seek in video
  bool showSwipeDuration = false; // Whether to show the seek duration overlay

  bool _speedUpIndicator = false;
  late /* private */ var playlist = controller(context).player.state.playlist;
  late bool buffering = controller(context).player.state.buffering;

  bool _mountSeekBackwardButton = false;
  bool _mountSeekForwardButton = false;
  bool _hideSeekBackwardButton = false;
  bool _hideSeekForwardButton = false;
  Timer? _timerSeekBackwardButton;
  Timer? _timerSeekForwardButton;

  final ValueNotifier<Duration> _seekBarDeltaValueNotifier =
      ValueNotifier<Duration>(Duration.zero);

  final List<StreamSubscription> subscriptions = [];

  double get subtitleVerticalShiftOffset =>
      (_theme(context).padding?.bottom ?? 0.0) +
      (_theme(context).bottomButtonBarMargin.vertical) +
      (_theme(context).bottomButtonBar.isNotEmpty
          ? _theme(context).buttonBarHeight
          : 0.0);
  Offset? _tapPosition;

  void _handleDoubleTapDown(TapDownDetails details) {
    setState(() {
      _tapPosition = details.localPosition;
    });
  }

  void _handleLongPress() {
    setState(() {
      _speedUpIndicator = true;
    });
    _currentRate = controller(context).player.state.rate;
    controller(context).player.setRate(_theme(context).speedUpFactor);
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    setState(() {
      _speedUpIndicator = false;
    });
    controller(context).player.setRate(_currentRate);
  }

  @override
  void setState(VoidCallback fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (subscriptions.isEmpty) {
      mount = _theme(context).visibleOnMount;
      visible = _theme(context).visibleOnMount;
      _volumeValue = _theme(context).initialVolume ?? 0.5;
      _brightnessValue = _theme(context).initialBrightness ?? 0.5;
      _onBrightnessReset = _theme(context).onBrightnessReset;

      subscriptions.addAll([
        controller(context).player.stream.playlist.listen((event) {
          setState(() {
            playlist = event;
          });
        }),
        controller(context).player.stream.buffering.listen((event) {
          setState(() {
            buffering = event;
          });
        }),
      ]);

      if (_theme(context).visibleOnMount) {
        _timer = Timer(_theme(context).controlsHoverDuration, () {
          if (mounted) {
            setState(() {
              visible = false;
            });
            unshiftSubtitle();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    for (final subscription in subscriptions) {
      subscription.cancel();
    }
    _onBrightnessReset?.call();
    _timerSeekBackwardButton?.cancel();
    _timerSeekForwardButton?.cancel();
    super.dispose();
  }

  void shiftSubtitle() {
    if (_theme(context).shiftSubtitlesOnControlsVisibilityChange) {
      state(context).setSubtitleViewPadding(
        state(context).widget.subtitleViewConfiguration.padding +
            EdgeInsets.fromLTRB(0.0, 0.0, 0.0, subtitleVerticalShiftOffset),
      );
    }
  }

  void unshiftSubtitle() {
    if (_theme(context).shiftSubtitlesOnControlsVisibilityChange) {
      state(context).setSubtitleViewPadding(
        state(context).widget.subtitleViewConfiguration.padding,
      );
    }
  }

  void onTap() {
    if (!visible) {
      setState(() {
        mount = true;
        visible = true;
      });
      shiftSubtitle();
      _timer?.cancel();
      _timer = Timer(_theme(context).controlsHoverDuration, () {
        if (mounted) {
          setState(() {
            visible = false;
          });
          unshiftSubtitle();
        }
      });
    } else {
      setState(() {
        visible = false;
      });
      unshiftSubtitle();
      _timer?.cancel();
    }
  }

  void onDoubleTapSeekBackward() {
    setState(() {
      _mountSeekBackwardButton = true;
    });
  }

  void onDoubleTapSeekForward() {
    setState(() {
      _mountSeekForwardButton = true;
    });
  }

  void onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_dragInitialDelta == Offset.zero) {
      _dragInitialDelta = details.localPosition;
      return;
    }

    final diff = _dragInitialDelta.dx - details.localPosition.dx;
    final duration = controller(context).player.state.duration.inSeconds;
    final position = controller(context).player.state.position.inSeconds;

    final seconds =
        -(diff * duration / _theme(context).horizontalGestureSensitivity)
            .round();
    final relativePosition = position + seconds;

    if (relativePosition <= duration && relativePosition >= 0) {
      setState(() {
        swipeDuration = seconds;
        showSwipeDuration = true;
        _seekBarDeltaValueNotifier.value = Duration(seconds: seconds);
      });
    }
  }

  void onHorizontalDragEnd() {
    if (swipeDuration != 0) {
      Duration newPosition =
          controller(context).player.state.position +
          Duration(seconds: swipeDuration);
      newPosition = newPosition.clamp(
        Duration.zero,
        controller(context).player.state.duration,
      );
      controller(context).player.seek(newPosition);
    }

    setState(() {
      _dragInitialDelta = Offset.zero;
      showSwipeDuration = false;
    });
  }

  bool _isInSegment(double localX, int segmentIndex) {
    // Local variable with the list of ratios
    List<int> segmentRatios = _theme(context).seekOnDoubleTapLayoutTapsRatios;

    int totalRatios = segmentRatios.reduce((a, b) => a + b);

    double segmentWidthMultiplier = widgetWidth(context) / totalRatios;
    double start = 0;
    double end;

    for (int i = 0; i < segmentRatios.length; i++) {
      end = start + (segmentWidthMultiplier * segmentRatios[i]);

      // Check if the current index matches the segmentIndex and if localX falls within it
      if (i == segmentIndex && localX >= start && localX <= end) {
        return true;
      }

      // Set the start of the next segment
      start = end;
    }

    // If localX does not fall within the specified segment
    return false;
  }

  bool _isInRightSegment(double localX) {
    return _isInSegment(localX, 2);
  }

  bool _isInLeftSegment(double localX) {
    return _isInSegment(localX, 0);
  }

  void _handlePointerDown(PointerDownEvent event) {
    onTap();
  }

  void setVolume(double value) {
    _theme(context).onVolumeChanged?.call(value);
    setState(() {
      _volumeValue = value;
      _volumeIndicator = true;
    });
    _volumeTimer?.cancel();
    _volumeTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _volumeIndicator = false;
        });
      }
    });
  }

  void setBrightness(double value) {
    _theme(context).onBrightnessChanged?.call(value);
    setState(() {
      _brightnessValue = value;
      _brightnessIndicator = true;
    });
    _brightnessTimer?.cancel();
    _brightnessTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _brightnessIndicator = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    var seekOnDoubleTapEnabledWhileControlsAreVisible =
        (_theme(context).seekOnDoubleTap &&
        _theme(context).seekOnDoubleTapEnabledWhileControlsVisible);
    assert(
      _theme(context).seekOnDoubleTapLayoutTapsRatios.length == 3,
      "The number of seekOnDoubleTapLayoutTapsRatios must be 3, i.e. [1, 1, 1]",
    );
    assert(
      _theme(context).seekOnDoubleTapLayoutWidgetRatios.length == 3,
      "The number of seekOnDoubleTapLayoutWidgetRatios must be 3, i.e. [1, 1, 1]",
    );
    return Theme(
      data: Theme.of(context).copyWith(
        focusColor: const Color(0x00000000),
        hoverColor: const Color(0x00000000),
        splashColor: const Color(0x00000000),
        highlightColor: const Color(0x00000000),
      ),

      /// Add [Directionality] to ltr to avoid wrong animation of sides.
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Focus(
          focusNode: videoViewParametersNotifier(context).value.focusNode,
          autofocus: true,
          child: Material(
            elevation: 0.0,
            borderOnForeground: false,
            animationDuration: Duration.zero,
            color: const Color(0x00000000),
            shadowColor: const Color(0x00000000),
            surfaceTintColor: const Color(0x00000000),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Controls:
                AnimatedOpacity(
                  curve: Curves.easeInOut,
                  opacity: visible ? 1.0 : 0.0,
                  duration: _theme(context).controlsTransitionDuration,
                  onEnd: () {
                    setState(() {
                      if (!visible) {
                        mount = false;
                      }
                    });
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: Container(color: _theme(context).backdropColor),
                      ),
                      // We are adding 16.0 boundary around the actual controls (which contain the vertical drag gesture detectors).
                      // This will make the hit-test on edges (e.g. swiping to: show status-bar, show navigation-bar, go back in navigation) not activate the swipe gesture annoyingly.
                      Positioned.fill(
                        left: 16.0,
                        top: 16.0,
                        right: 16.0,
                        bottom: 16.0 + subtitleVerticalShiftOffset,
                        child: Listener(
                          onPointerDown: (event) => _handlePointerDown(event),
                          child: GestureDetector(
                            onDoubleTapDown: _handleDoubleTapDown,
                            onLongPress: _theme(context).speedUpOnLongPress
                                ? _handleLongPress
                                : null,
                            onLongPressEnd: _theme(context).speedUpOnLongPress
                                ? _handleLongPressEnd
                                : null,
                            onDoubleTap: () {
                              if (_tapPosition == null) {
                                return;
                              }
                              if (_isInRightSegment(_tapPosition!.dx)) {
                                if ((!mount &&
                                        _theme(context).seekOnDoubleTap) ||
                                    seekOnDoubleTapEnabledWhileControlsAreVisible) {
                                  onDoubleTapSeekForward();
                                }
                              } else {
                                if (_isInLeftSegment(_tapPosition!.dx)) {
                                  if ((!mount &&
                                          _theme(context).seekOnDoubleTap) ||
                                      seekOnDoubleTapEnabledWhileControlsAreVisible) {
                                    onDoubleTapSeekBackward();
                                  }
                                }
                              }
                            },
                            onHorizontalDragUpdate: (details) {
                              if ((!mount && _theme(context).seekGesture) ||
                                  (_theme(context).seekGesture &&
                                      _theme(
                                        context,
                                      ).gesturesEnabledWhileControlsVisible)) {
                                onHorizontalDragUpdate(details);
                              }
                            },
                            onHorizontalDragEnd: (details) {
                              onHorizontalDragEnd();
                            },
                            onVerticalDragUpdate: (e) async {
                              final delta = e.delta.dy;
                              final Offset position = e.localPosition;

                              if (position.dx <= widgetWidth(context) / 2) {
                                // Left side of screen swiped
                                if ((!mount &&
                                        _theme(context).brightnessGesture &&
                                        _theme(context).onBrightnessChanged !=
                                            null) ||
                                    (_theme(context).brightnessGesture &&
                                        _theme(
                                          context,
                                        ).gesturesEnabledWhileControlsVisible &&
                                        _theme(context).onBrightnessChanged !=
                                            null)) {
                                  final brightness =
                                      _brightnessValue -
                                      delta /
                                          _theme(context)
                                              .verticalGestureSensitivity;
                                  final result = brightness.clamp(0.0, 1.0);
                                  setBrightness(result);
                                }
                              } else {
                                // Right side of screen swiped

                                if ((!mount &&
                                        _theme(context).volumeGesture &&
                                        _theme(context).onVolumeChanged !=
                                            null) ||
                                    (_theme(context).volumeGesture &&
                                        _theme(
                                          context,
                                        ).gesturesEnabledWhileControlsVisible &&
                                        _theme(context).onVolumeChanged !=
                                            null)) {
                                  final volume =
                                      _volumeValue -
                                      delta /
                                          _theme(context)
                                              .verticalGestureSensitivity;
                                  final result = volume.clamp(0.0, 1.0);
                                  setVolume(result);
                                }
                              }
                            },
                            child: Container(color: const Color(0x00000000)),
                          ),
                        ),
                      ),
                      if (mount)
                        Padding(
                          padding:
                              _theme(context).padding ??
                              (
                              // Add padding in fullscreen!
                              isFullscreen(context)
                                  ? MediaQuery.of(context).padding
                                  : EdgeInsets.zero),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                height: _theme(context).buttonBarHeight,
                                margin: _theme(context).topButtonBarMargin,
                                child: Row(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: _theme(context).topButtonBar,
                                ),
                              ),
                              // Only display [primaryButtonBar] if [buffering] is false.
                              Expanded(
                                child: AnimatedOpacity(
                                  curve: Curves.easeInOut,
                                  opacity: buffering ? 0.0 : 1.0,
                                  duration: _theme(context)
                                      .controlsTransitionDuration,
                                  child: Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: _theme(context)
                                          .primaryButtonBar,
                                    ),
                                  ),
                                ),
                              ),
                              Stack(
                                alignment: Alignment.bottomCenter,
                                // KURUMI-CM: サムネイルプレビューは
                                // シークバーの上に溢れて描くため切らない。
                                clipBehavior: Clip.none,
                                children: [
                                  // KURUMI-CM: CM区間付きシークバーに
                                  // 差し替える (テーマ・余白は共通)。
                                  if (_theme(context).displaySeekBar)
                                    CmSeekBar(
                                      cmSections: widget.cmSections,
                                      isDesktop: false,
                                      seekThumbnail: widget.seekThumbnail,
                                      onSeekStart: () {
                                        _timer?.cancel();
                                      },
                                      onSeekEnd: () {
                                        _timer = Timer(
                                          _theme(context).controlsHoverDuration,
                                          () {
                                            if (mounted) {
                                              setState(() {
                                                visible = false;
                                              });
                                              unshiftSubtitle();
                                            }
                                          },
                                        );
                                      },
                                    ),
                                  Container(
                                    height: _theme(context).buttonBarHeight,
                                    margin: _theme(context)
                                        .bottomButtonBarMargin,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: _theme(context).bottomButtonBar,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                // Double-Tap Seek Seek-Bar:
                if (!mount)
                  if (_mountSeekBackwardButton ||
                      _mountSeekForwardButton ||
                      showSwipeDuration)
                    Column(
                      children: [
                        const Spacer(),
                        Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            // KURUMI-CM: ダブルタップシーク中の表示も
                            // CM区間付きシークバーで描く。
                            if (_theme(context).displaySeekBar)
                              CmSeekBar(
                                cmSections: widget.cmSections,
                                isDesktop: false,
                                delta: _seekBarDeltaValueNotifier,
                                // KURUMI-CM: プレビューは出さない
                                // (ドラッグ中の位置ではないため)。
                                seekThumbnail: null,
                              ),
                            Container(
                              height: _theme(context).buttonBarHeight,
                              margin: _theme(context).bottomButtonBarMargin,
                            ),
                          ],
                        ),
                      ],
                    ),
                // Buffering Indicator.
                IgnorePointer(
                  child: Padding(
                    padding:
                        _theme(context).padding ??
                        (
                        // Add padding in fullscreen!
                        isFullscreen(context)
                            ? MediaQuery.of(context).padding
                            : EdgeInsets.zero),
                    child: Column(
                      children: [
                        Container(
                          height: _theme(context).buttonBarHeight,
                          margin: _theme(context).topButtonBarMargin,
                        ),
                        Expanded(
                          child: Center(
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                begin: 0.0,
                                end: buffering ? 1.0 : 0.0,
                              ),
                              duration: _theme(context)
                                  .controlsTransitionDuration,
                              builder: (context, value, child) {
                                // Only mount the buffering indicator if the opacity is greater than 0.0.
                                // This has been done to prevent redundant resource usage in [CircularProgressIndicator].
                                if (value > 0.0) {
                                  return Opacity(
                                    opacity: value,
                                    child:
                                        _theme(context)
                                            .bufferingIndicatorBuilder
                                            ?.call(context) ??
                                        child!,
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                              child: const CircularProgressIndicator(
                                color: Color(0xFFFFFFFF),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          height: _theme(context).buttonBarHeight,
                          margin: _theme(context).bottomButtonBarMargin,
                        ),
                      ],
                    ),
                  ),
                ),
                // Volume Indicator.
                IgnorePointer(
                  child: AnimatedOpacity(
                    curve: Curves.easeInOut,
                    opacity:
                        (!mount ||
                                _theme(context)
                                    .gesturesEnabledWhileControlsVisible) &&
                            _volumeIndicator
                        ? 1.0
                        : 0.0,
                    duration: _theme(context).controlsTransitionDuration,
                    child:
                        _theme(context).volumeIndicatorBuilder
                            ?.call(context, _volumeValue) ??
                        Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0x88000000),
                            borderRadius: BorderRadius.circular(64.0),
                          ),
                          height: 52.0,
                          width: 108.0,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                height: 52.0,
                                width: 42.0,
                                alignment: Alignment.centerRight,
                                child: Icon(
                                  _volumeValue == 0.0
                                      ? Icons.volume_off
                                      : _volumeValue < 0.5
                                      ? Icons.volume_down
                                      : Icons.volume_up,
                                  color: const Color(0xFFFFFFFF),
                                  size: 24.0,
                                ),
                              ),
                              const SizedBox(width: 8.0),
                              Expanded(
                                child: Text(
                                  '${(_volumeValue * 100.0).round()}%',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 14.0,
                                    color: Color(0xFFFFFFFF),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16.0),
                            ],
                          ),
                        ),
                  ),
                ),
                // Brightness Indicator.
                IgnorePointer(
                  child: AnimatedOpacity(
                    curve: Curves.easeInOut,
                    opacity:
                        (!mount ||
                                _theme(context)
                                    .gesturesEnabledWhileControlsVisible) &&
                            _brightnessIndicator
                        ? 1.0
                        : 0.0,
                    duration: _theme(context).controlsTransitionDuration,
                    child:
                        _theme(context).brightnessIndicatorBuilder
                            ?.call(context, _brightnessValue) ??
                        Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0x88000000),
                            borderRadius: BorderRadius.circular(64.0),
                          ),
                          height: 52.0,
                          width: 108.0,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                height: 52.0,
                                width: 42.0,
                                alignment: Alignment.centerRight,
                                child: Icon(
                                  _brightnessValue < 1.0 / 3.0
                                      ? Icons.brightness_low
                                      : _brightnessValue < 2.0 / 3.0
                                      ? Icons.brightness_medium
                                      : Icons.brightness_high,
                                  color: const Color(0xFFFFFFFF),
                                  size: 24.0,
                                ),
                              ),
                              const SizedBox(width: 8.0),
                              Expanded(
                                child: Text(
                                  '${(_brightnessValue * 100.0).round()}%',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 14.0,
                                    color: Color(0xFFFFFFFF),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16.0),
                            ],
                          ),
                        ),
                  ),
                ),
                // Speedup Indicator.
                IgnorePointer(
                  child: Padding(
                    padding:
                        _theme(context).padding ??
                        (
                        // Add padding in fullscreen!
                        isFullscreen(context)
                            ? MediaQuery.of(context).padding
                            : EdgeInsets.zero),
                    child: Column(
                      children: [
                        Container(
                          height: _theme(context).buttonBarHeight,
                          margin: _theme(context).topButtonBarMargin,
                        ),
                        Expanded(
                          child: AnimatedOpacity(
                            duration: _theme(context)
                                .controlsTransitionDuration,
                            opacity: _speedUpIndicator ? 1 : 0,
                            child:
                                _theme(context).speedUpIndicatorBuilder?.call(
                                  context,
                                  _theme(context).speedUpFactor,
                                ) ??
                                Container(
                                  alignment: Alignment.topCenter,
                                  child: Container(
                                    margin: const EdgeInsets.all(16.0),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: const Color(0x88000000),
                                      borderRadius: BorderRadius.circular(64.0),
                                    ),
                                    height: 48.0,
                                    width: 108.0,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        const SizedBox(width: 16.0),
                                        Expanded(
                                          child: Text(
                                            '${_theme(context).speedUpFactor.toStringAsFixed(1)}x',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 14.0,
                                              color: Color(0xFFFFFFFF),
                                            ),
                                          ),
                                        ),
                                        Container(
                                          height: 48.0,
                                          width: 48.0 - 16.0,
                                          alignment: Alignment.centerRight,
                                          child: const Icon(
                                            Icons.fast_forward,
                                            color: Color(0xFFFFFFFF),
                                            size: 24.0,
                                          ),
                                        ),
                                        const SizedBox(width: 16.0),
                                      ],
                                    ),
                                  ),
                                ),
                          ),
                        ),
                        Container(
                          height: _theme(context).buttonBarHeight,
                          margin: _theme(context).bottomButtonBarMargin,
                        ),
                      ],
                    ),
                  ),
                ),
                // Seek Indicator.
                IgnorePointer(
                  child: AnimatedOpacity(
                    duration: _theme(context).controlsTransitionDuration,
                    opacity: showSwipeDuration ? 1 : 0,
                    child:
                        _theme(context).seekIndicatorBuilder
                            ?.call(context, Duration(seconds: swipeDuration)) ??
                        Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0x88000000),
                            borderRadius: BorderRadius.circular(64.0),
                          ),
                          height: 52.0,
                          width: 108.0,
                          child: Text(
                            swipeDuration > 0
                                ? "+ ${Duration(seconds: swipeDuration).label()}"
                                : "- ${Duration(seconds: swipeDuration).label()}",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14.0,
                              color: Color(0xFFFFFFFF),
                            ),
                          ),
                        ),
                  ),
                ),

                // Double-Tap Seek Button(s):
                if (!mount || seekOnDoubleTapEnabledWhileControlsAreVisible)
                  if (_mountSeekBackwardButton || _mountSeekForwardButton)
                    Positioned.fill(
                      child: Row(
                        children: [
                          Expanded(
                            flex: _theme(context)
                                .seekOnDoubleTapLayoutWidgetRatios[0],
                            child: _mountSeekBackwardButton
                                ? AnimatedOpacity(
                                    opacity: _hideSeekBackwardButton ? 0 : 1.0,
                                    duration: const Duration(milliseconds: 200),
                                    child: _BackwardSeekIndicator(
                                      duration: _theme(context)
                                          .seekOnDoubleTapBackwardDuration,
                                      onChanged: (value) {
                                        _seekBarDeltaValueNotifier.value =
                                            -value;
                                      },
                                      onSubmitted: (value) {
                                        _timerSeekBackwardButton?.cancel();
                                        _timerSeekBackwardButton = Timer(
                                          const Duration(milliseconds: 200),
                                          () {
                                            setState(() {
                                              _hideSeekBackwardButton = false;
                                              _mountSeekBackwardButton = false;
                                            });
                                          },
                                        );

                                        setState(() {
                                          _hideSeekBackwardButton = true;
                                        });
                                        var result =
                                            controller(context)
                                                .player
                                                .state
                                                .position -
                                            value;
                                        result = result.clamp(
                                          Duration.zero,
                                          controller(context)
                                              .player
                                              .state
                                              .duration,
                                        );
                                        controller(context).player.seek(result);
                                      },
                                    ),
                                  )
                                : const SizedBox(),
                          ),
                          //Area in the middle where the double-tap seek buttons are ignored in
                          if (_theme(context)
                                  .seekOnDoubleTapLayoutWidgetRatios[1] >
                              0)
                            Spacer(
                              flex: _theme(context)
                                  .seekOnDoubleTapLayoutWidgetRatios[1],
                            ),
                          Expanded(
                            flex: _theme(context)
                                .seekOnDoubleTapLayoutWidgetRatios[2],
                            child: _mountSeekForwardButton
                                ? AnimatedOpacity(
                                    opacity: _hideSeekForwardButton ? 0 : 1.0,
                                    duration: const Duration(milliseconds: 200),
                                    child: _ForwardSeekIndicator(
                                      duration: _theme(context)
                                          .seekOnDoubleTapForwardDuration,
                                      onChanged: (value) {
                                        _seekBarDeltaValueNotifier.value =
                                            value;
                                      },
                                      onSubmitted: (value) {
                                        _timerSeekForwardButton?.cancel();
                                        _timerSeekForwardButton = Timer(
                                          const Duration(milliseconds: 200),
                                          () {
                                            if (_hideSeekForwardButton) {
                                              setState(() {
                                                _hideSeekForwardButton = false;
                                                _mountSeekForwardButton = false;
                                              });
                                            }
                                          },
                                        );
                                        setState(() {
                                          _hideSeekForwardButton = true;
                                        });

                                        var result =
                                            controller(context)
                                                .player
                                                .state
                                                .position +
                                            value;
                                        result = result.clamp(
                                          Duration.zero,
                                          controller(context)
                                              .player
                                              .state
                                              .duration,
                                        );
                                        controller(context).player.seek(result);
                                      },
                                    ),
                                  )
                                : const SizedBox(),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double widgetWidth(BuildContext context) =>
      (context.findRenderObject() as RenderBox).paintBounds.width;
}

// SEEK BAR

/// Material design seek bar.
class MaterialSeekBar extends StatefulWidget {
  final ValueNotifier<Duration>? delta;
  final VoidCallback? onSeekStart;
  final VoidCallback? onSeekEnd;

  const MaterialSeekBar({
    super.key,
    this.delta,
    this.onSeekStart,
    this.onSeekEnd,
  });

  @override
  MaterialSeekBarState createState() => MaterialSeekBarState();
}

class MaterialSeekBarState extends State<MaterialSeekBar> {
  bool tapped = false;
  double slider = 0.0;

  late bool playing = controller(context).player.state.playing;
  late Duration position = controller(context).player.state.position;
  late Duration duration = controller(context).player.state.duration;
  late Duration buffer = controller(context).player.state.buffer;

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
    return Container(
      clipBehavior: Clip.none,
      margin: _theme(context).seekBarMargin,
      child: LayoutBuilder(
        builder: (context, constraints) => MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onHorizontalDragUpdate: (_) {},
            onPanStart: (e) => onPanStart(e, constraints),
            onPanDown: (e) => onPanDown(e, constraints),
            onPanUpdate: (e) => onPanUpdate(e, constraints),
            child: Listener(
              onPointerMove: (e) => onPointerMove(e, constraints),
              onPointerDown: (e) => onPointerDown(),
              onPointerUp: (e) => onPointerUp(),
              child: Container(
                color: Colors.transparent,
                width: constraints.maxWidth,
                alignment: _theme(context).seekBarAlignment,
                height: _theme(context).seekBarContainerHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    Container(
                      width: constraints.maxWidth,
                      height: _theme(context).seekBarHeight,
                      alignment: Alignment.bottomLeft,
                      color: _theme(context).seekBarColor,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.bottomLeft,
                        children: [
                          Container(
                            width: constraints.maxWidth * bufferPercent,
                            color: _theme(context).seekBarBufferColor,
                          ),
                          Container(
                            width: tapped
                                ? constraints.maxWidth * slider
                                : constraints.maxWidth * positionPercent,
                            color: _theme(context).seekBarPositionColor,
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: tapped
                          ? (constraints.maxWidth -
                                    _theme(context).seekBarThumbSize / 2) *
                                slider
                          : (constraints.maxWidth -
                                    _theme(context).seekBarThumbSize / 2) *
                                positionPercent,
                      bottom:
                          -1.0 * _theme(context).seekBarThumbSize / 2 +
                          _theme(context).seekBarHeight / 2,
                      child: Container(
                        width: _theme(context).seekBarThumbSize,
                        height: _theme(context).seekBarThumbSize,
                        decoration: BoxDecoration(
                          color: _theme(context).seekBarThumbColor,
                          borderRadius: BorderRadius.circular(
                            _theme(context).seekBarThumbSize / 2,
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

// BUTTON: PLAY/PAUSE

/// A material design play/pause button.
class MaterialPlayOrPauseButton extends StatefulWidget {
  /// Overriden icon size for [MaterialSkipPreviousButton].
  final double? iconSize;

  /// Overriden icon color for [MaterialSkipPreviousButton].
  final Color? iconColor;

  const MaterialPlayOrPauseButton({super.key, this.iconSize, this.iconColor});

  @override
  MaterialPlayOrPauseButtonState createState() =>
      MaterialPlayOrPauseButtonState();
}

class MaterialPlayOrPauseButtonState extends State<MaterialPlayOrPauseButton>
    with SingleTickerProviderStateMixin {
  late final animation = AnimationController(
    vsync: this,
    value: controller(context).player.state.playing ? 1 : 0,
    duration: const Duration(milliseconds: 200),
  );

  StreamSubscription<bool>? subscription;

  @override
  void setState(VoidCallback fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    subscription ??= controller(context).player.stream.playing.listen((event) {
      if (event) {
        animation.forward();
      } else {
        animation.reverse();
      }
    });
  }

  @override
  void dispose() {
    animation.dispose();
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: controller(context).player.playOrPause,
      iconSize: widget.iconSize ?? _theme(context).buttonBarButtonSize,
      color: widget.iconColor ?? _theme(context).buttonBarButtonColor,
      icon: IgnorePointer(
        child: AnimatedIcon(
          progress: animation,
          icon: AnimatedIcons.play_pause,
          size: widget.iconSize ?? _theme(context).buttonBarButtonSize,
          color: widget.iconColor ?? _theme(context).buttonBarButtonColor,
        ),
      ),
    );
  }
}

// BUTTON: SKIP NEXT

/// Material design skip next button.
class MaterialSkipNextButton extends StatelessWidget {
  /// Icon for [MaterialSkipNextButton].
  final Widget? icon;

  /// Overriden icon size for [MaterialSkipNextButton].
  final double? iconSize;

  /// Overriden icon color for [MaterialSkipNextButton].
  final Color? iconColor;

  const MaterialSkipNextButton({
    super.key,
    this.icon,
    this.iconSize,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    if (!_theme(context).automaticallyImplySkipNextButton ||
        (controller(context).player.state.playlist.medias.length > 1 &&
            _theme(context).automaticallyImplySkipNextButton)) {
      return IconButton(
        onPressed: controller(context).player.next,
        icon: icon ?? const Icon(Icons.skip_next),
        iconSize: iconSize ?? _theme(context).buttonBarButtonSize,
        color: iconColor ?? _theme(context).buttonBarButtonColor,
      );
    }
    return const SizedBox.shrink();
  }
}

// BUTTON: SKIP PREVIOUS

/// Material design skip previous button.
class MaterialSkipPreviousButton extends StatelessWidget {
  /// Icon for [MaterialSkipPreviousButton].
  final Widget? icon;

  /// Overriden icon size for [MaterialSkipPreviousButton].
  final double? iconSize;

  /// Overriden icon color for [MaterialSkipPreviousButton].
  final Color? iconColor;

  const MaterialSkipPreviousButton({
    super.key,
    this.icon,
    this.iconSize,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    if (!_theme(context).automaticallyImplySkipPreviousButton ||
        (controller(context).player.state.playlist.medias.length > 1 &&
            _theme(context).automaticallyImplySkipPreviousButton)) {
      return IconButton(
        onPressed: controller(context).player.previous,
        icon: icon ?? const Icon(Icons.skip_previous),
        iconSize: iconSize ?? _theme(context).buttonBarButtonSize,
        color: iconColor ?? _theme(context).buttonBarButtonColor,
      );
    }
    return const SizedBox.shrink();
  }
}

// BUTTON: FULL SCREEN

/// Material design fullscreen button.
class MaterialFullscreenButton extends StatelessWidget {
  /// Icon for [MaterialFullscreenButton].
  final Widget? icon;

  /// Overriden icon size for [MaterialFullscreenButton].
  final double? iconSize;

  /// Overriden icon color for [MaterialFullscreenButton].
  final Color? iconColor;

  const MaterialFullscreenButton({
    super.key,
    this.icon,
    this.iconSize,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => toggleFullscreen(context),
      icon:
          icon ??
          (isFullscreen(context)
              ? const Icon(Icons.fullscreen_exit)
              : const Icon(Icons.fullscreen)),
      iconSize: iconSize ?? _theme(context).buttonBarButtonSize,
      color: iconColor ?? _theme(context).buttonBarButtonColor,
    );
  }
}

// BUTTON: CUSTOM

/// Material design custom button.
class MaterialCustomButton extends StatelessWidget {
  /// Icon for [MaterialCustomButton].
  final Widget? icon;

  /// Icon size for [MaterialCustomButton].
  final double? iconSize;

  /// Icon color for [MaterialCustomButton].
  final Color? iconColor;

  /// The callback that is called when the button is tapped or otherwise activated.
  final VoidCallback onPressed;

  const MaterialCustomButton({
    super.key,
    this.icon,
    this.iconSize,
    this.iconColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: icon ?? const Icon(Icons.settings),
      padding: EdgeInsets.zero,
      iconSize: iconSize ?? _theme(context).buttonBarButtonSize,
      color: iconColor ?? _theme(context).buttonBarButtonColor,
    );
  }
}

// POSITION INDICATOR

/// Material design position indicator.
class MaterialPositionIndicator extends StatefulWidget {
  /// Overriden [TextStyle] for the [MaterialPositionIndicator].
  final TextStyle? style;
  const MaterialPositionIndicator({super.key, this.style});

  @override
  MaterialPositionIndicatorState createState() =>
      MaterialPositionIndicatorState();
}

class MaterialPositionIndicatorState extends State<MaterialPositionIndicator> {
  late Duration position = controller(context).player.state.position;
  late Duration duration = controller(context).player.state.duration;

  final List<StreamSubscription> subscriptions = [];

  @override
  void setState(VoidCallback fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (subscriptions.isEmpty) {
      subscriptions.addAll([
        controller(context).player.stream.position.listen((event) {
          setState(() {
            position = event;
          });
        }),
        controller(context).player.stream.duration.listen((event) {
          setState(() {
            duration = event;
          });
        }),
      ]);
    }
  }

  @override
  void dispose() {
    for (final subscription in subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '${position.label(reference: duration)} / ${duration.label(reference: duration)}',
      style:
          widget.style ??
          TextStyle(
            height: 1.0,
            fontSize: 12.0,
            color: _theme(context).buttonBarButtonColor,
          ),
    );
  }
}

class _BackwardSeekIndicator extends StatefulWidget {
  final Duration duration;
  final void Function(Duration) onChanged;
  final void Function(Duration) onSubmitted;
  const _BackwardSeekIndicator({
    required this.duration,
    required this.onChanged,
    required this.onSubmitted,
  });

  @override
  State<_BackwardSeekIndicator> createState() => _BackwardSeekIndicatorState();
}

class _BackwardSeekIndicatorState extends State<_BackwardSeekIndicator> {
  late Duration value = widget.duration;

  Timer? timer;

  @override
  void setState(VoidCallback fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  @override
  void initState() {
    super.initState();
    timer = Timer(const Duration(milliseconds: 400), () {
      widget.onSubmitted.call(value);
    });
  }

  void increment() {
    timer?.cancel();
    timer = Timer(const Duration(milliseconds: 400), () {
      widget.onSubmitted.call(value);
    });
    widget.onChanged.call(value);
    setState(() {
      value += const Duration(seconds: 10);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0x88767676), Color(0x00767676)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: InkWell(
        splashColor: const Color(0x44767676),
        onTap: increment,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.fast_rewind,
                size: 24.0,
                color: Color(0xFFFFFFFF),
              ),
              const SizedBox(height: 8.0),
              Text(
                '${value.inSeconds} seconds',
                style: const TextStyle(
                  fontSize: 12.0,
                  color: Color(0xFFFFFFFF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ForwardSeekIndicator extends StatefulWidget {
  final Duration duration;
  final void Function(Duration) onChanged;
  final void Function(Duration) onSubmitted;
  const _ForwardSeekIndicator({
    required this.duration,
    required this.onChanged,
    required this.onSubmitted,
  });

  @override
  State<_ForwardSeekIndicator> createState() => _ForwardSeekIndicatorState();
}

class _ForwardSeekIndicatorState extends State<_ForwardSeekIndicator> {
  late Duration value = widget.duration;

  Timer? timer;

  @override
  void setState(VoidCallback fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  @override
  void initState() {
    super.initState();
    timer = Timer(const Duration(milliseconds: 400), () {
      widget.onSubmitted.call(value);
    });
  }

  void increment() {
    timer?.cancel();
    timer = Timer(const Duration(milliseconds: 400), () {
      widget.onSubmitted.call(value);
    });
    widget.onChanged.call(value);
    setState(() {
      value += const Duration(seconds: 10);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0x00767676), Color(0x88767676)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: InkWell(
        splashColor: const Color(0x44767676),
        onTap: increment,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.fast_forward,
                size: 24.0,
                color: Color(0xFFFFFFFF),
              ),
              const SizedBox(height: 8.0),
              Text(
                '${value.inSeconds} seconds',
                style: const TextStyle(
                  fontSize: 12.0,
                  color: Color(0xFFFFFFFF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
