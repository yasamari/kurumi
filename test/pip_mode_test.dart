import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/core/pip/pip_mode.dart';
import 'package:simple_pip_mode/actions/pip_action.dart';
import 'package:simple_pip_mode/actions/pip_actions_layout.dart';

/// テストは Linux 上で動くので `Platform.isAndroid` が false になり、ネイティブ
/// 呼び出しは一切発生しない。`enable` / `disable` の Dart 側の状態機械だけを
/// 検証できる。
void main() {
  // バインディングが無いと assert で止まるので先に初期化する。
  TestWidgetsFlutterBinding.ensureInitialized();

  final pip = PipMode.instance;
  final oldScreen = Object();
  final newScreen = Object();
  void ignoreAction(PipAction action) {}

  // 解除は次のイベントループに回されるため、待って変わるのを確かめる。
  Future<void> settle() => pumpEventQueue();

  group('PiP の所有者管理', () {
    test('新画面の mount が済んでいれば、後から dispose されても残る', () async {
      await pip.enable(
        owner: oldScreen,
        actions: PipActionsLayout.media,
        onAction: ignoreAction,
      );
      // チャンネル切替など「新画面の mount → 旧画面の dispose」の順。
      await pip.enable(
        owner: newScreen,
        actions: PipActionsLayout.media,
        onAction: ignoreAction,
      );
      await pip.disable(owner: oldScreen);
      await settle();
      expect(pip.enabled, isTrue);
      expect(pip.actionsLayout, PipActionsLayout.media);
    });

    test('旧画面の dispose が先なら、新画面の mount が打ち消す', () async {
      await pip.enable(
        owner: oldScreen,
        actions: PipActionsLayout.media,
        onAction: ignoreAction,
      );
      // 「旧画面の dispose → 新画面の mount」の順。
      await pip.disable(owner: oldScreen);
      await pip.enable(
        owner: newScreen,
        actions: PipActionsLayout.media,
        onAction: ignoreAction,
      );
      await settle();
      expect(pip.enabled, isTrue);
      expect(pip.actionsLayout, PipActionsLayout.media);
    });

    test('持ち主がそのまま離れると PiP の設定を外す', () async {
      await pip.enable(
        owner: newScreen,
        actions: PipActionsLayout.media,
        onAction: ignoreAction,
      );
      await pip.disable(owner: newScreen);
      await settle();
      expect(pip.enabled, isFalse);
      expect(pip.actionsLayout, PipActionsLayout.none);
    });

    test('ボタン構成を変えると持ち主ごと差し替える', () async {
      await pip.enable(
        owner: newScreen,
        actions: PipActionsLayout.media,
        onAction: ignoreAction,
      );
      await pip.enable(
        owner: newScreen,
        actions: PipActionsLayout.mediaOnlyPause,
        onAction: ignoreAction,
      );
      expect(pip.actionsLayout, PipActionsLayout.mediaOnlyPause);
      expect(pip.enabled, isTrue);
      await pip.disable(owner: newScreen);
      await settle();
    });
  });
}
