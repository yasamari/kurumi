// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'jikkyo_comment.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$JikkyoComment {

/// 対象のスレッド ID。NX-Jikkyo は文字列で送ってくる。
 String get threadId;/// コメ番。スレッド内で単調増加し、**欠番があり得る**。
///
/// NX-Jikkyo は接続ごとの送信キュー (上限200件) が溢れると古いコメントを
/// 黙って捨てるため、連続性は保証されない。dup 判定と並び順の鍵に使う。
 int get no;/// 番組開始からの経過ミリ秒。スレッド開始時刻を基準とした相対時刻。
 int get vpos;/// 投稿日時。サーバーの `date` (UNIX秒) と `date_usec` (マイクロ秒) を
/// 合成した絶対時刻。
 DateTime get postedAt;/// コメント本文。
 String get content;/// 投稿者 ID。NX-Jikkyo では視聴セッションのクライアント ID が入るため、
/// ニコニコのユーザー ID ではない。
 String get userId;/// コメントコマンド列 (空白区切り)。サーバーは一切解釈しない不透明文字列。
/// 表示属性への変換は `parseJikkyoCommentMail` で行う。
 String get mail;/// プレミアムコメントか。0 のときはキーごと欠落する。
 bool get premium;/// 匿名コメントか。0 のときはキーごと欠落する。
 bool get anonymity;/// 自分が投げたコメントか。0 のときはキーごと欠落する。
 bool get yourPost;
/// Create a copy of JikkyoComment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JikkyoCommentCopyWith<JikkyoComment> get copyWith => _$JikkyoCommentCopyWithImpl<JikkyoComment>(this as JikkyoComment, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as JikkyoComment;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JikkyoComment&&(identical(other.threadId, _this.threadId) || other.threadId == _this.threadId)&&(identical(other.no, _this.no) || other.no == _this.no)&&(identical(other.vpos, _this.vpos) || other.vpos == _this.vpos)&&(identical(other.postedAt, _this.postedAt) || other.postedAt == _this.postedAt)&&(identical(other.content, _this.content) || other.content == _this.content)&&(identical(other.userId, _this.userId) || other.userId == _this.userId)&&(identical(other.mail, _this.mail) || other.mail == _this.mail)&&(identical(other.premium, _this.premium) || other.premium == _this.premium)&&(identical(other.anonymity, _this.anonymity) || other.anonymity == _this.anonymity)&&(identical(other.yourPost, _this.yourPost) || other.yourPost == _this.yourPost));
}


@override
int get hashCode {
  final _this = this as JikkyoComment;
  return Object.hash(runtimeType,_this.threadId,_this.no,_this.vpos,_this.postedAt,_this.content,_this.userId,_this.mail,_this.premium,_this.anonymity,_this.yourPost);
}

@override
String toString() {
  final _this = this as JikkyoComment;
  return 'JikkyoComment(threadId: ${_this.threadId}, no: ${_this.no}, vpos: ${_this.vpos}, postedAt: ${_this.postedAt}, content: ${_this.content}, userId: ${_this.userId}, mail: ${_this.mail}, premium: ${_this.premium}, anonymity: ${_this.anonymity}, yourPost: ${_this.yourPost})';
}


}

/// @nodoc
abstract mixin class $JikkyoCommentCopyWith<$Res>  {
  factory $JikkyoCommentCopyWith(JikkyoComment value, $Res Function(JikkyoComment) _then) = _$JikkyoCommentCopyWithImpl;
@useResult
$Res call({
 String threadId, int no, int vpos, DateTime postedAt, String content, String userId, String mail, bool premium, bool anonymity, bool yourPost
});




}
/// @nodoc
class _$JikkyoCommentCopyWithImpl<$Res>
    implements $JikkyoCommentCopyWith<$Res> {
  _$JikkyoCommentCopyWithImpl(this._self, this._then);

  final JikkyoComment _self;
  final $Res Function(JikkyoComment) _then;

/// Create a copy of JikkyoComment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? threadId = null,Object? no = null,Object? vpos = null,Object? postedAt = null,Object? content = null,Object? userId = null,Object? mail = null,Object? premium = null,Object? anonymity = null,Object? yourPost = null,}) {
  return _then(JikkyoComment(
threadId: null == threadId ? _self.threadId : threadId // ignore: cast_nullable_to_non_nullable
as String,no: null == no ? _self.no : no // ignore: cast_nullable_to_non_nullable
as int,vpos: null == vpos ? _self.vpos : vpos // ignore: cast_nullable_to_non_nullable
as int,postedAt: null == postedAt ? _self.postedAt : postedAt // ignore: cast_nullable_to_non_nullable
as DateTime,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,mail: null == mail ? _self.mail : mail // ignore: cast_nullable_to_non_nullable
as String,premium: null == premium ? _self.premium : premium // ignore: cast_nullable_to_non_nullable
as bool,anonymity: null == anonymity ? _self.anonymity : anonymity // ignore: cast_nullable_to_non_nullable
as bool,yourPost: null == yourPost ? _self.yourPost : yourPost // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [JikkyoComment].
extension JikkyoCommentPatterns on JikkyoComment {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _JikkyoComment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _JikkyoComment() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _JikkyoComment value)  $default,){
final _that = this;
switch (_that) {
case _JikkyoComment():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _JikkyoComment value)?  $default,){
final _that = this;
switch (_that) {
case _JikkyoComment() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String threadId,  int no,  int vpos,  DateTime postedAt,  String content,  String userId,  String mail,  bool premium,  bool anonymity,  bool yourPost)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _JikkyoComment() when $default != null:
return $default(_that.threadId,_that.no,_that.vpos,_that.postedAt,_that.content,_that.userId,_that.mail,_that.premium,_that.anonymity,_that.yourPost);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String threadId,  int no,  int vpos,  DateTime postedAt,  String content,  String userId,  String mail,  bool premium,  bool anonymity,  bool yourPost)  $default,) {final _that = this;
switch (_that) {
case _JikkyoComment():
return $default(_that.threadId,_that.no,_that.vpos,_that.postedAt,_that.content,_that.userId,_that.mail,_that.premium,_that.anonymity,_that.yourPost);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String threadId,  int no,  int vpos,  DateTime postedAt,  String content,  String userId,  String mail,  bool premium,  bool anonymity,  bool yourPost)?  $default,) {final _that = this;
switch (_that) {
case _JikkyoComment() when $default != null:
return $default(_that.threadId,_that.no,_that.vpos,_that.postedAt,_that.content,_that.userId,_that.mail,_that.premium,_that.anonymity,_that.yourPost);case _:
  return null;

}
}

}

/// @nodoc


class _JikkyoComment implements JikkyoComment {
  const _JikkyoComment({required this.threadId, required this.no, required this.vpos, required this.postedAt, required this.content, required this.userId, required this.mail, this.premium = false, this.anonymity = false, this.yourPost = false});
  

/// 対象のスレッド ID。NX-Jikkyo は文字列で送ってくる。
@override final  String threadId;
/// コメ番。スレッド内で単調増加し、**欠番があり得る**。
///
/// NX-Jikkyo は接続ごとの送信キュー (上限200件) が溢れると古いコメントを
/// 黙って捨てるため、連続性は保証されない。dup 判定と並び順の鍵に使う。
@override final  int no;
/// 番組開始からの経過ミリ秒。スレッド開始時刻を基準とした相対時刻。
@override final  int vpos;
/// 投稿日時。サーバーの `date` (UNIX秒) と `date_usec` (マイクロ秒) を
/// 合成した絶対時刻。
@override final  DateTime postedAt;
/// コメント本文。
@override final  String content;
/// 投稿者 ID。NX-Jikkyo では視聴セッションのクライアント ID が入るため、
/// ニコニコのユーザー ID ではない。
@override final  String userId;
/// コメントコマンド列 (空白区切り)。サーバーは一切解釈しない不透明文字列。
/// 表示属性への変換は `parseJikkyoCommentMail` で行う。
@override final  String mail;
/// プレミアムコメントか。0 のときはキーごと欠落する。
@override@JsonKey() final  bool premium;
/// 匿名コメントか。0 のときはキーごと欠落する。
@override@JsonKey() final  bool anonymity;
/// 自分が投げたコメントか。0 のときはキーごと欠落する。
@override@JsonKey() final  bool yourPost;

/// Create a copy of JikkyoComment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$JikkyoCommentCopyWith<_JikkyoComment> get copyWith => __$JikkyoCommentCopyWithImpl<_JikkyoComment>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _JikkyoComment&&(identical(other.threadId, threadId) || other.threadId == threadId)&&(identical(other.no, no) || other.no == no)&&(identical(other.vpos, vpos) || other.vpos == vpos)&&(identical(other.postedAt, postedAt) || other.postedAt == postedAt)&&(identical(other.content, content) || other.content == content)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.mail, mail) || other.mail == mail)&&(identical(other.premium, premium) || other.premium == premium)&&(identical(other.anonymity, anonymity) || other.anonymity == anonymity)&&(identical(other.yourPost, yourPost) || other.yourPost == yourPost));
}


@override
int get hashCode {
    return Object.hash(runtimeType,threadId,no,vpos,postedAt,content,userId,mail,premium,anonymity,yourPost);
}

@override
String toString() {
    return 'JikkyoComment(threadId: $threadId, no: $no, vpos: $vpos, postedAt: $postedAt, content: $content, userId: $userId, mail: $mail, premium: $premium, anonymity: $anonymity, yourPost: $yourPost)';
}


}

/// @nodoc
abstract mixin class _$JikkyoCommentCopyWith<$Res> implements $JikkyoCommentCopyWith<$Res> {
  factory _$JikkyoCommentCopyWith(_JikkyoComment value, $Res Function(_JikkyoComment) _then) = __$JikkyoCommentCopyWithImpl;
@override @useResult
$Res call({
 String threadId, int no, int vpos, DateTime postedAt, String content, String userId, String mail, bool premium, bool anonymity, bool yourPost
});




}
/// @nodoc
class __$JikkyoCommentCopyWithImpl<$Res>
    implements _$JikkyoCommentCopyWith<$Res> {
  __$JikkyoCommentCopyWithImpl(this._self, this._then);

  final _JikkyoComment _self;
  final $Res Function(_JikkyoComment) _then;

/// Create a copy of JikkyoComment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? threadId = null,Object? no = null,Object? vpos = null,Object? postedAt = null,Object? content = null,Object? userId = null,Object? mail = null,Object? premium = null,Object? anonymity = null,Object? yourPost = null,}) {
  return _then(_JikkyoComment(
threadId: null == threadId ? _self.threadId : threadId // ignore: cast_nullable_to_non_nullable
as String,no: null == no ? _self.no : no // ignore: cast_nullable_to_non_nullable
as int,vpos: null == vpos ? _self.vpos : vpos // ignore: cast_nullable_to_non_nullable
as int,postedAt: null == postedAt ? _self.postedAt : postedAt // ignore: cast_nullable_to_non_nullable
as DateTime,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,mail: null == mail ? _self.mail : mail // ignore: cast_nullable_to_non_nullable
as String,premium: null == premium ? _self.premium : premium // ignore: cast_nullable_to_non_nullable
as bool,anonymity: null == anonymity ? _self.anonymity : anonymity // ignore: cast_nullable_to_non_nullable
as bool,yourPost: null == yourPost ? _self.yourPost : yourPost // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
