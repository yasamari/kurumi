import 'dart:math' show max;

import 'package:flutter/material.dart';

import 'timetable_layout.dart';

/// ガター・各チャンネル列・ヘッダー行のスクロールを1本に束ねる。
///
/// 横スクロールはヘッダーと列の2本の `ListView.builder` (可視付近だけ作る
/// ため)、縦スクロールは列ごとの `ListView.builder` (番組境界が列で異なる
/// ため) を持つ。いずれかの列のスクロールを他列へ `jumpTo` で伝える。再入は
/// ガードする。
///
/// **斜めスクロールはここで実現する。** 列の `ListView` は
/// `NeverScrollableScrollPhysics` にしてドラッグのジェスチャー競合を外して
/// あり、入ってくるのは `TimetablePanScroll` の1本のパンだけ。縦横2本の
/// リンクが同じドラッグ量の dy・dx を同時に受けるので、斜めドラッグがその
/// まま両軸のスクロールになる。端のクランプは [dragBy] で、慣性・ホイールは
/// 各 `ScrollPosition` の物理 (`goBallistic` / `pointerScroll`) で処理する。
///
/// [offset] の変更は `notifyListeners` で配信し、罫線・nowラインの
/// 再配置 (`AnimatedBuilder`) に使う。列自体の再構築は起きない。
class TimetableScrollLink extends ChangeNotifier {
  final Map<ScrollController, VoidCallback> _members = {};

  bool _syncing = false;
  double _offset = 0;

  /// 現在の共有オフセット。
  double get offset => _offset;

  /// 連動に参加するコントローラーを作る。現在のオフセットを引き継ぐ。
  ///
  /// 呼び出し側で `dispose` 時に [detach] すること。
  ScrollController attach() {
    final controller = ScrollController(initialScrollOffset: _offset);
    void listener() => _onScrolled(controller);
    controller.addListener(listener);
    _members[controller] = listener;
    return controller;
  }

  /// 連動から外してコントローラーを破棄する。
  void detach(ScrollController controller) {
    final listener = _members.remove(controller);
    if (listener != null) {
      controller.removeListener(listener);
    }
    controller.dispose();
  }

  /// 全列を指定オフセットへ動かす (初回表示のnowジャンプ用)。
  void jumpTo(double offset) {
    if (offset == _offset) {
      // 変化なしでも描画側の初期配置のため通知する。
      notifyListeners();
      return;
    }
    _offset = offset;
    _syncing = true;
    try {
      for (final member in _members.keys) {
        if (member.hasClients && member.offset != offset) {
          member.jumpTo(offset);
        }
      }
    } finally {
      _syncing = false;
    }
    notifyListeners();
  }

  /// ドラッグ量 [delta] (画面上の移動方向。下・右が正) をそのまま反映する。
  ///
  /// 斜めドラッグでは縦横2本のリンクがそれぞれ dy と dx を受け取るので、
  /// 結果として両軸が同時に動く。両端でクランプする。
  void dragBy(double delta) {
    jumpTo(
      timetableDragOffset(offset: _offset, maxOffset: _maxOffset, delta: delta),
    );
  }

  /// ホイール量 [delta] (下・右が正) を慣性付きで反映する。
  ///
  /// 各 `ScrollPosition` のホイール処理 (`pointerScroll`) に委ねるため、
  /// ホイール・トラックパッドの2本指スクロール (dx・dy が同時に来る) が
  /// そのまま効く。
  void pointerScrollBy(double delta) {
    if (delta == 0) return;
    // 各メンバーが個別に `pointerScroll` すると、そのたびに通知が上がって
    // [_onScrolled] 経由で他メンバーが追従し、1回のホイールでメンバー数の
    // 分だけ加算されてしまう。ループ中は同期を止め、最後に共有オフセットを
    // 1回だけ更新する (全メンバーが同じ物理・同じ最大距離なので同じ量だけ
    // 動き、揃ったままになる)。
    _syncing = true;
    try {
      for (final member in _members.keys) {
        if (member.hasClients) {
          member.position.pointerScroll(delta);
        }
      }
    } finally {
      _syncing = false;
    }
    _adoptLeaderOffset();
  }

  /// メンバーの現在オフセットを共有値へ取り込み、描画側へ通知する。
  ///
  /// 同期を止めて動かした後 ([pointerScrollBy]) に使う。値が変わらなければ
  /// 通知しない。
  void _adoptLeaderOffset() {
    for (final member in _members.keys) {
      if (!member.hasClients) continue;
      final next = member.offset;
      if (next == _offset) return;
      _offset = next;
      notifyListeners();
      return;
    }
  }

  /// ドラッグ終了の速度 [velocity] (画面上の移動方向) で慣性スクロールする。
  ///
  /// 各 `ScrollPosition` の物理演算 (`goBallistic`) に委ねる。全列は同じ
  /// 物理・同じ最大距離を持つため同じ速度から同じ軌道になり、[offset] の
  /// 同期で揃う。
  void flingBy(double velocity) {
    // 指の速度と逆方向へ進む。`ListView` の position は常に
    // `ScrollPositionWithSingleContext` (入れ子の scroll view の position は
    // 別クラスなので慣性は任せない)。
    final target = -velocity;
    for (final member in _members.keys) {
      if (!member.hasClients) continue;
      final position = member.position;
      if (position is ScrollPositionWithSingleContext) {
        position.goBallistic(target);
      }
    }
  }

  /// 参加メンバーの最大スクロール量。未レイアウト (節点なし) では 0。
  ///
  /// 全列の高さは `timetableColumnSegments` の空白埋めで揃うため、先頭の
  /// 値を使えば全列共通になる。端ボタンの表示判定に使う。
  double get maxOffset => _maxOffset;

  double get _maxOffset {
    for (final member in _members.keys) {
      if (member.hasClients) {
        final position = member.position;
        // 初回レイアウト前は寸法が無く `maxScrollExtent` が throw する。
        // 端ボタンの表示判定は build でも走るため、ここで落とすと
        // 読み込み完了時に赤いエラー画面が一瞬出る。
        if (position.hasContentDimensions) {
          return max(0.0, position.maxScrollExtent);
        }
      }
    }
    return 0;
  }

  void _onScrolled(ScrollController leader) {
    if (_syncing || !leader.hasClients) return;
    final next = leader.offset;
    if (next == _offset) return;
    _offset = next;
    _syncing = true;
    try {
      for (final member in _members.keys) {
        if (identical(member, leader) || !member.hasClients) continue;
        if (member.offset != next) {
          member.jumpTo(next);
        }
      }
    } finally {
      _syncing = false;
    }
    notifyListeners();
  }
}
