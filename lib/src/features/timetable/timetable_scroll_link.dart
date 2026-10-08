import 'package:flutter/material.dart';

/// ガターと各チャンネル列の縦スクロールを連動させる。
///
/// 横スクロールは単一の `SingleChildScrollView` に載せるため連動不要だが、
/// 縦方向は列ごとに `ListView` (番組境界が列で異なるため) を持つ。いずれかの
/// 列のスクロールを他列へ `jumpTo` で伝える。再入はガードする。
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
