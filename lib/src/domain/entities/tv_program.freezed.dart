// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tv_program.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TvProgram {

 int get eventId; String get title; String get description; DateTime get startAt; DateTime get endAt;/// 表示用のジャンル名一覧 (例: `['ニュース／報道', 'スポーツ']`)。なければ空。
 List<String> get genres;/// 番組詳細 (例: `{'出演者': '...'}`)。KonomiTV の `detail`、
/// Mirakurun の `extended` を文字列化したもの。なければ空。
 Map<String, String> get detail;
/// Create a copy of TvProgram
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TvProgramCopyWith<TvProgram> get copyWith => _$TvProgramCopyWithImpl<TvProgram>(this as TvProgram, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as TvProgram;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TvProgram&&(identical(other.eventId, _this.eventId) || other.eventId == _this.eventId)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.startAt, _this.startAt) || other.startAt == _this.startAt)&&(identical(other.endAt, _this.endAt) || other.endAt == _this.endAt)&&const DeepCollectionEquality().equals(other.genres, _this.genres)&&const DeepCollectionEquality().equals(other.detail, _this.detail));
}


@override
int get hashCode {
  final _this = this as TvProgram;
  return Object.hash(runtimeType,_this.eventId,_this.title,_this.description,_this.startAt,_this.endAt,const DeepCollectionEquality().hash(_this.genres),const DeepCollectionEquality().hash(_this.detail));
}

@override
String toString() {
  final _this = this as TvProgram;
  return 'TvProgram(eventId: ${_this.eventId}, title: ${_this.title}, description: ${_this.description}, startAt: ${_this.startAt}, endAt: ${_this.endAt}, genres: ${_this.genres}, detail: ${_this.detail})';
}


}

/// @nodoc
abstract mixin class $TvProgramCopyWith<$Res>  {
  factory $TvProgramCopyWith(TvProgram value, $Res Function(TvProgram) _then) = _$TvProgramCopyWithImpl;
@useResult
$Res call({
 int eventId, String title, String description, DateTime startAt, DateTime endAt, List<String> genres, Map<String, String> detail
});




}
/// @nodoc
class _$TvProgramCopyWithImpl<$Res>
    implements $TvProgramCopyWith<$Res> {
  _$TvProgramCopyWithImpl(this._self, this._then);

  final TvProgram _self;
  final $Res Function(TvProgram) _then;

/// Create a copy of TvProgram
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? eventId = null,Object? title = null,Object? description = null,Object? startAt = null,Object? endAt = null,Object? genres = null,Object? detail = null,}) {
  return _then(TvProgram(
eventId: null == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,startAt: null == startAt ? _self.startAt : startAt // ignore: cast_nullable_to_non_nullable
as DateTime,endAt: null == endAt ? _self.endAt : endAt // ignore: cast_nullable_to_non_nullable
as DateTime,genres: null == genres ? _self.genres : genres // ignore: cast_nullable_to_non_nullable
as List<String>,detail: null == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}

}


/// Adds pattern-matching-related methods to [TvProgram].
extension TvProgramPatterns on TvProgram {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TvProgram value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TvProgram() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TvProgram value)  $default,){
final _that = this;
switch (_that) {
case _TvProgram():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TvProgram value)?  $default,){
final _that = this;
switch (_that) {
case _TvProgram() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int eventId,  String title,  String description,  DateTime startAt,  DateTime endAt,  List<String> genres,  Map<String, String> detail)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TvProgram() when $default != null:
return $default(_that.eventId,_that.title,_that.description,_that.startAt,_that.endAt,_that.genres,_that.detail);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int eventId,  String title,  String description,  DateTime startAt,  DateTime endAt,  List<String> genres,  Map<String, String> detail)  $default,) {final _that = this;
switch (_that) {
case _TvProgram():
return $default(_that.eventId,_that.title,_that.description,_that.startAt,_that.endAt,_that.genres,_that.detail);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int eventId,  String title,  String description,  DateTime startAt,  DateTime endAt,  List<String> genres,  Map<String, String> detail)?  $default,) {final _that = this;
switch (_that) {
case _TvProgram() when $default != null:
return $default(_that.eventId,_that.title,_that.description,_that.startAt,_that.endAt,_that.genres,_that.detail);case _:
  return null;

}
}

}

/// @nodoc


class _TvProgram implements TvProgram {
  const _TvProgram({required this.eventId, required this.title, this.description = '', required this.startAt, required this.endAt,  List<String> genres = const [],  Map<String, String> detail = const {}}): _genres = genres,_detail = detail;
  

@override final  int eventId;
@override final  String title;
@override@JsonKey() final  String description;
@override final  DateTime startAt;
@override final  DateTime endAt;
/// 表示用のジャンル名一覧 (例: `['ニュース／報道', 'スポーツ']`)。なければ空。
 final  List<String> _genres;
/// 表示用のジャンル名一覧 (例: `['ニュース／報道', 'スポーツ']`)。なければ空。
@override@JsonKey() List<String> get genres {
  if (_genres is EqualUnmodifiableListView) return _genres;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_genres);
}

/// 番組詳細 (例: `{'出演者': '...'}`)。KonomiTV の `detail`、
/// Mirakurun の `extended` を文字列化したもの。なければ空。
 final  Map<String, String> _detail;
/// 番組詳細 (例: `{'出演者': '...'}`)。KonomiTV の `detail`、
/// Mirakurun の `extended` を文字列化したもの。なければ空。
@override@JsonKey() Map<String, String> get detail {
  if (_detail is EqualUnmodifiableMapView) return _detail;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_detail);
}


/// Create a copy of TvProgram
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TvProgramCopyWith<_TvProgram> get copyWith => __$TvProgramCopyWithImpl<_TvProgram>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TvProgram&&(identical(other.eventId, eventId) || other.eventId == eventId)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.startAt, startAt) || other.startAt == startAt)&&(identical(other.endAt, endAt) || other.endAt == endAt)&&const DeepCollectionEquality().equals(other.genres, _genres)&&const DeepCollectionEquality().equals(other.detail, _detail));
}


@override
int get hashCode {
    return Object.hash(runtimeType,eventId,title,description,startAt,endAt,const DeepCollectionEquality().hash(_genres),const DeepCollectionEquality().hash(_detail));
}

@override
String toString() {
    return 'TvProgram(eventId: $eventId, title: $title, description: $description, startAt: $startAt, endAt: $endAt, genres: $genres, detail: $detail)';
}


}

/// @nodoc
abstract mixin class _$TvProgramCopyWith<$Res> implements $TvProgramCopyWith<$Res> {
  factory _$TvProgramCopyWith(_TvProgram value, $Res Function(_TvProgram) _then) = __$TvProgramCopyWithImpl;
@override @useResult
$Res call({
 int eventId, String title, String description, DateTime startAt, DateTime endAt, List<String> genres, Map<String, String> detail
});




}
/// @nodoc
class __$TvProgramCopyWithImpl<$Res>
    implements _$TvProgramCopyWith<$Res> {
  __$TvProgramCopyWithImpl(this._self, this._then);

  final _TvProgram _self;
  final $Res Function(_TvProgram) _then;

/// Create a copy of TvProgram
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? eventId = null,Object? title = null,Object? description = null,Object? startAt = null,Object? endAt = null,Object? genres = null,Object? detail = null,}) {
  return _then(_TvProgram(
eventId: null == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,startAt: null == startAt ? _self.startAt : startAt // ignore: cast_nullable_to_non_nullable
as DateTime,endAt: null == endAt ? _self.endAt : endAt // ignore: cast_nullable_to_non_nullable
as DateTime,genres: null == genres ? _self._genres : genres // ignore: cast_nullable_to_non_nullable
as List<String>,detail: null == detail ? _self._detail : detail // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}


}

// dart format on
