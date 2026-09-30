/// ニコ生コメントコマンド (`mail`) の解釈。
///
/// NX-Jikkyo は `mail` を生成するのみで一切解釈しない。生成されるのは視聴
/// セッションの `postComment` が受け取った `color` / `position` / `size` /
/// `font` / `isAnonymous` を空白区切りで連結したものなので、未知トークンが
/// 混ざりうる。したがって未知トークンは無視し、各カテゴリは既定値に
/// フォールバックする。
///
/// ref: https://github.com/xpadev-net/niconicomments
library;

import 'package:flutter/material.dart';

/// コメントの表示位置。
enum JikkyoCommentPosition {
  /// 画面中央 (`naka`)。既定。
  naka,

  /// 上部 (`ue`)。
  top,

  /// 下部 (`shita`)。
  bottom,
}

/// コメントのサイズ。
enum JikkyoCommentSize { small, medium, big }

const _positionNames = <String, JikkyoCommentPosition>{
  'naka': JikkyoCommentPosition.naka,
  'ue': JikkyoCommentPosition.top,
  'shita': JikkyoCommentPosition.bottom,
};

const _sizeNames = <String, JikkyoCommentSize>{
  'small': JikkyoCommentSize.small,
  'medium': JikkyoCommentSize.medium,
  'big': JikkyoCommentSize.big,
};

const _colorNames = <String>{
  'white',
  'red',
  'pink',
  'orange',
  'yellow',
  'green',
  'cyan',
  'blue',
  'purple',
  'black',
};

/// 色コマンドが無かった場合の既定色。
const defaultJikkyoCommentColor = 'white';

/// 匿名コメントを表すコマンド。
const _anonymousCommand = '184';

/// 派生色コマンド (`red2` の `2` 部分) の取りうる値。
final _derivedColorSuffix = RegExp(r'^([a-z]+)[2-8]$');

/// `mail` から読み取ったコメントの表示属性。
class JikkyoCommentStyle {
  const JikkyoCommentStyle({
    this.color = defaultJikkyoCommentColor,
    this.size = JikkyoCommentSize.medium,
    this.position = JikkyoCommentPosition.naka,
    this.anonymous = false,
  });

  /// 色コマンド。未指定なら [defaultJikkyoCommentColor]。
  ///
  /// 色名を Dart の `Color` に写すのは UI 層の責務。
  final String color;

  /// サイズコマンド。未指定なら medium。
  final JikkyoCommentSize size;

  /// 位置コマンド。未指定なら naka。
  final JikkyoCommentPosition position;

  /// 匿名コメントか (`184`)。
  final bool anonymous;
}

/// `mail` (空白区切りのコマンド列) を表示属性に変換する。
///
/// 色・サイズ・位置・匿名の各カテゴリで最後に現れたコマンドを採用する。
/// 未知トークンやフォントコマンド (`defont` / `gulim`) は無視する。
/// `mail` が空文字や未知トークンだけの場合も既定値が返る。
JikkyoCommentStyle parseJikkyoCommentMail(String mail) {
  var color = defaultJikkyoCommentColor;
  var size = JikkyoCommentSize.medium;
  var position = JikkyoCommentPosition.naka;
  var anonymous = false;

  for (final token in mail.split(' ')) {
    if (token.isEmpty) continue;
    if (token == _anonymousCommand) {
      anonymous = true;
      continue;
    }
    final resolvedPosition = _positionNames[token];
    if (resolvedPosition != null) {
      position = resolvedPosition;
      continue;
    }
    final resolvedSize = _sizeNames[token];
    if (resolvedSize != null) {
      size = resolvedSize;
      continue;
    }
    final resolvedColor = _colorName(token);
    if (resolvedColor != null) color = resolvedColor;
  }

  return JikkyoCommentStyle(
    color: color,
    size: size,
    position: position,
    anonymous: anonymous,
  );
}

/// 色コマンドなら色名を返す。派生色 (`red2` など) は先頭の既知色名に落とす。
String? _colorName(String token) {
  if (_colorNames.contains(token)) return token;
  final derived = _derivedColorSuffix.firstMatch(token);
  if (derived == null) return null;
  final base = derived.group(1)!;
  return _colorNames.contains(base) ? base : null;
}

/// ニコ生の色コマンド名を表示用の [Color] に変換する。
///
/// [parseJikkyoCommentMail] が返した `color` を渡す。未知の名前は
/// [defaultJikkyoCommentColor] として扱う。
///
/// 「白」「黒」はどちらもテーマの背景に対して読める必要があるため、明るさに
/// 応じて向きを反転する。
Color jikkyoCommentColorOf(String name, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return switch (name) {
    'white' => dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
    'black' => dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
    'red' => const Color(0xFFFF0000),
    'pink' => const Color(0xFFFF9999),
    'orange' => const Color(0xFFFFCC00),
    'yellow' => const Color(0xFFFFFF00),
    'green' => const Color(0xFF00CC00),
    'cyan' => const Color(0xFF00FFFF),
    'blue' => const Color(0xFF3399FF),
    'purple' => const Color(0xFFCC00FF),
    _ => dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
  };
}
