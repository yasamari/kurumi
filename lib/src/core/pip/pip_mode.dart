import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:simple_pip_mode/actions/pip_action.dart';
import 'package:simple_pip_mode/actions/pip_actions_layout.dart';
import 'package:simple_pip_mode/simple_pip.dart';

/// Android の PiP (ピクチャインピクチャ) の状態。アプリ全体で1つだけ持つ。
///
/// **Riverpod にも画面ごとの State にもしない。** PiP は平台的機能なので、
/// ライブ視聴・録画再生のどちらの画面からも同じ1つの状態 ([active]) を見る。
/// 画面側は [active] を `ValueListenableBuilder` で購読する ([PipMode] 側からは
/// 通知しない) ので、`PlayerPlaybackController.notifyListeners` にも乗らない。
///
/// **`SimplePip` のインスタンスは1個だけ生成すること。** 生成のたびに
/// `puntito.simple_pip_mode` のメソッドハンドラを `setMethodCallHandler` で
/// 上書きしてしまうため、複数作ると最後に作ったものだけが PiP のコールバックを
/// 受け、旧画面が登録したハンドラが黙って外される。
class PipMode {
  PipMode._() {
    // ハンドラの登録はコンストラクタが1回だけ行う。
    _pip = SimplePip(
      onPipEntered: () => _setActive(true),
      onPipExited: () => _setActive(false),
      onPipAction: (action) => _onAction?.call(action),
    );
  }

  /// PiP ウィンドウのアスペクト比 (16:9)。テレビ放送と同じ形にする。
  static const (int, int) aspectRatio = (16, 9);

  /// プロセス内で唯一点のインスタンス。
  static final PipMode instance = PipMode._();

  late final SimplePip _pip;

  /// PiP モードに入っているかどうかの通知元。
  ///
  /// ライブ視聴・録画再生はこの値を購読して、映像と情報パネルの配置を
  /// PiP 用に切り替える (向きで出し分けず、矩形だけ [playerSplitRects] に任せる
  /// のは映像のサブツリーを守りたいため)。
  final ValueNotifier<bool> active = ValueNotifier(false);

  /// PiP ウィンドウの操作ボタンが押されたときの通知先。
  ///
  /// 再生中のプレイヤーを持つ画面が [enable] で登録し、[disable] で外す。
  /// 押せるボタンの構成は [enable] で選んだ [PipActionsLayout] に依存する。
  ValueChanged<PipAction>? _onAction;

  /// Android 以外のプラットフォームでネイティブを呼ばないためのガード。
  /// `simple_pip_mode` は Android 実装しか無く、他のOSで呼ぶと
  /// `MissingPluginException` になる (`SimplePip.isPipAvailable` も含めて)。
  bool get _supported => Platform.isAndroid;

  /// プレイヤー画面が PiP を使用中か。状態確認用。
  bool get enabled => _enabled;

  /// PiP ウィンドウに出ているボタンの構成。状態確認用。
  PipActionsLayout get actionsLayout => _actions;

  Future<bool>? _availableFuture;

  /// いま PiP を使用中の画面。`State` のインスタンスを渡す (同一性の判別だけに使う)。
  Object? _owner;

  /// プレイヤー画面が PiP を使用中か。
  bool _enabled = false;

  /// PiP ウィンドウに出すボタンの構成。
  PipActionsLayout _actions = PipActionsLayout.none;

  /// PiP ウィンドウの play/pause ボタンの状態。最新の通知を覚えておき、
  /// PiP に入る直前に適用する (通知から PiP 入までの間に再生状態が変わるため)。
  bool? _isPlaying;

  /// 解除を遅らせるタイマー ([disable] のコメントを参照)。
  Timer? _disableTimer;

  /// この端末が PiP に対応しているかどうか。非 Android・未対応端末は false。
  ///
  /// 問い合わせは1回だけ。ボタンごとに1度で済む。
  Future<bool> available() {
    if (!_supported) return Future<bool>.value(false);
    return _availableFuture ??= _queryAvailability();
  }

  /// ホームキーで自動的に PiP へ入る機能を使えるかどうか (Android 12 / API 31+)。
  /// 公開 API にはしない (自動 PiP は設定項目を持たないため、問い合わせるのは
  /// [_apply] の中だけ)。
  static Future<bool> get _autoEnterSupported async {
    try {
      return await SimplePip.isAutoPipAvailable;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// プレイヤー画面が mount したときの設定。
  ///
  /// [actions] は PiP ウィンドウに出すボタン (前/次チャンネル・再生/一時停止) の
  /// 構成。ホームキーで自動的に PiP へ入る機能 (API 31+) もここで有効にする。
  ///
  /// [owner] は「いま PiP を使うのはどの画面か」を判別するためのもので、普通は
  /// `this` (呼び出し元の `State`) を渡す。旧画面が後から `disable` しても
  /// 新しい画面の設定を壊さないために使う ([disable] を参照)。
  ///
  /// [onAction] は PiP ウィンドウのボタンが押されたときの処理。
  Future<void> enable({
    required Object owner,
    required PipActionsLayout actions,
    required ValueChanged<PipAction> onAction,
  }) {
    // 解除タイマーを取り消しておく。画面が破棄された直後に別の画面が mount した
    // ときは無効化を飛ばす必要がある (順序は [disable] を参照)。
    _disableTimer?.cancel();
    _disableTimer = null;
    _owner = owner;
    _onAction = onAction;
    // 構成も持ち主も変わらなければネイティブ呼び出しは重ねない。
    final unchanged = _enabled && _actions == actions;
    _enabled = true;
    _actions = actions;
    // Dart 側のアイソレートが PiP 中の状態で作り直された場合に備えて、通知が
    // 届かないうちに mount しても [active] が矛盾しないようにする (ホットリスタート時)。
    unawaited(_syncActive());
    if (unchanged) return Future<void>.value();
    return _apply(autoEnter: true);
  }

  /// プレイヤー画面を離れたときの復元。
  ///
  /// 自動 PiP と PiP ウィンドウのボタンを戻す。テレビ一覧などでホームキーを
  /// 押しても、再生中の画面が残っていない PiP へ入らないようにするため。
  ///
  /// **[owner] が現在の持ち主でなければ何もしない。** チャンネル切替などで
  /// 視聴画面が入れ替わるとき、**「新画面が mount 済みだが旧画面の `dispose` が
  /// 後から走る」ことがある** (キーの付け替えは「新 `initState` → 旧 `dispose`」
  /// だが、ルートの入れ替えは逆の順になりうる)。順序で結果が変わり、無効化が
  /// 後からなると **`setAutoPipMode` が空のボタン一覧で
  /// `PictureInPictureParams` を作り直して、PiP ウィンドウのボタンがすべて消える**
  /// ため、同一性で判別する。
  ///
  /// 順序が「旧 `dispose` → 新 `initState`」の場合も、**無効化は次のイベント
  /// ループに回す**。間に挟まれた [enable] がタイマーをキャンセルして打ち消す。
  Future<void> disable({required Object owner}) {
    if (!identical(_owner, owner)) return Future<void>.value();
    _owner = null;
    _onAction = null;
    _disableTimer?.cancel();
    _enabled = false;
    // Dart 側の状態は遅延させずに同期的に落とす (プラットフォームに関係なく
    // 「PiP を使っていない」状態を表す)。
    _actions = PipActionsLayout.none;
    if (!_supported) return Future<void>.value();
    _disableTimer = Timer(Duration.zero, () {
      _disableTimer = null;
      unawaited(_apply(autoEnter: false));
    });
    return Future<void>.value();
  }

  /// PiP ウィンドウの play/pause ボタンをプレイヤーの再生状態に合わせる。
  ///
  /// プレイヤー画面が再生状態の変化ごとに呼ぶ。[active] へは通知しない。
  /// 映像の再構築に巻き込まれないため ([danmakuPreferences] と同じ理屈)。
  void reportPlaying(bool playing) {
    _isPlaying = playing;
    if (!_supported || !_enabled) return;
    unawaited(_call(() => _pip.setIsPlaying(playing)));
  }

  /// PiP モードへ入る。
  ///
  /// ボタンの構成を適用してから入る。`enterPipMode` は引数に現在のボタン一覧を
  /// 焼き込むため、先に `setPipActionsLayout` を呼ぶ必要がある。
  Future<void> enter() {
    if (!_supported) return Future<void>.value();
    return _call(() async {
      await _pip.setPipActionsLayout(_actions);
      final playing = _isPlaying;
      if (playing != null) await _pip.setIsPlaying(playing);
      await _pip.enterPipMode(
        aspectRatio: aspectRatio,
        autoEnter: true,
        seamlessResize: true,
      );
    });
  }

  /// 自動 PiP と PiP ウィンドウのボタンを反映する。
  Future<void> _apply({required bool autoEnter}) {
    if (!_supported) return Future<void>.value();
    return _call(() async {
      await _pip.setPipActionsLayout(_actions);
      if (await _autoEnterSupported) {
        await _pip.setAutoPipMode(
          aspectRatio: aspectRatio,
          autoEnter: autoEnter,
          seamlessResize: true,
        );
      }
    });
  }

  /// いま PiP ウィンドウにいるかをネイティブに尋ねて [active] を合わせる。
  ///
  /// Dart 側のアイソレートが PiP 中の状態で作り直された場合に備えて、通知が
  /// 届かないうちに mount しても [active] が矛盾しないようにする。
  Future<void> _syncActive() async {
    if (!_supported) return;
    try {
      _setActive(await SimplePip.isPipActivated);
    } on MissingPluginException {
      // プラグインが無い環境。
    } on PlatformException {
      // 問い合わせできない環境。
    }
  }

  Future<bool> _queryAvailability() async {
    try {
      return await SimplePip.isPipAvailable;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// ネイティブ呼び出しを [body] に委譲し、失敗しても例外を逸らす。
  Future<void> _call(Future<void> Function() body) async {
    try {
      await body();
    } on MissingPluginException {
      // プラグインが無い・MethodChannel に応答が無い環境。
    } on PlatformException {
      // 端末が PiP を拒否した場合など。
    }
  }

  void _setActive(bool value) {
    if (active.value == value) return;
    active.value = value;
  }
}
