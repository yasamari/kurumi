// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'video_thumbnail_tiles.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$VideoThumbnailTiles {

/// 並べた画像のURL (`/api/videos/{id}/thumbnail/tiled`)。
 String get url;/// 1枚のタイルの幅 (px)。
 int get tileWidth;/// 1枚のタイルの高さ (px)。
 int get tileHeight;/// 1行のタイル枚数。
 int get columnCount;/// タイルの総枚数。
 int get totalTiles;/// 隣り合うタイルの時刻差 (秒)。
 double get intervalSec;
/// Create a copy of VideoThumbnailTiles
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VideoThumbnailTilesCopyWith<VideoThumbnailTiles> get copyWith => _$VideoThumbnailTilesCopyWithImpl<VideoThumbnailTiles>(this as VideoThumbnailTiles, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as VideoThumbnailTiles;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VideoThumbnailTiles&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.tileWidth, _this.tileWidth) || other.tileWidth == _this.tileWidth)&&(identical(other.tileHeight, _this.tileHeight) || other.tileHeight == _this.tileHeight)&&(identical(other.columnCount, _this.columnCount) || other.columnCount == _this.columnCount)&&(identical(other.totalTiles, _this.totalTiles) || other.totalTiles == _this.totalTiles)&&(identical(other.intervalSec, _this.intervalSec) || other.intervalSec == _this.intervalSec));
}


@override
int get hashCode {
  final _this = this as VideoThumbnailTiles;
  return Object.hash(runtimeType,_this.url,_this.tileWidth,_this.tileHeight,_this.columnCount,_this.totalTiles,_this.intervalSec);
}

@override
String toString() {
  final _this = this as VideoThumbnailTiles;
  return 'VideoThumbnailTiles(url: ${_this.url}, tileWidth: ${_this.tileWidth}, tileHeight: ${_this.tileHeight}, columnCount: ${_this.columnCount}, totalTiles: ${_this.totalTiles}, intervalSec: ${_this.intervalSec})';
}


}

/// @nodoc
abstract mixin class $VideoThumbnailTilesCopyWith<$Res>  {
  factory $VideoThumbnailTilesCopyWith(VideoThumbnailTiles value, $Res Function(VideoThumbnailTiles) _then) = _$VideoThumbnailTilesCopyWithImpl;
@useResult
$Res call({
 String url, int tileWidth, int tileHeight, int columnCount, int totalTiles, double intervalSec
});




}
/// @nodoc
class _$VideoThumbnailTilesCopyWithImpl<$Res>
    implements $VideoThumbnailTilesCopyWith<$Res> {
  _$VideoThumbnailTilesCopyWithImpl(this._self, this._then);

  final VideoThumbnailTiles _self;
  final $Res Function(VideoThumbnailTiles) _then;

/// Create a copy of VideoThumbnailTiles
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? url = null,Object? tileWidth = null,Object? tileHeight = null,Object? columnCount = null,Object? totalTiles = null,Object? intervalSec = null,}) {
  return _then(VideoThumbnailTiles(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,tileWidth: null == tileWidth ? _self.tileWidth : tileWidth // ignore: cast_nullable_to_non_nullable
as int,tileHeight: null == tileHeight ? _self.tileHeight : tileHeight // ignore: cast_nullable_to_non_nullable
as int,columnCount: null == columnCount ? _self.columnCount : columnCount // ignore: cast_nullable_to_non_nullable
as int,totalTiles: null == totalTiles ? _self.totalTiles : totalTiles // ignore: cast_nullable_to_non_nullable
as int,intervalSec: null == intervalSec ? _self.intervalSec : intervalSec // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [VideoThumbnailTiles].
extension VideoThumbnailTilesPatterns on VideoThumbnailTiles {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VideoThumbnailTiles value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VideoThumbnailTiles() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VideoThumbnailTiles value)  $default,){
final _that = this;
switch (_that) {
case _VideoThumbnailTiles():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VideoThumbnailTiles value)?  $default,){
final _that = this;
switch (_that) {
case _VideoThumbnailTiles() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String url,  int tileWidth,  int tileHeight,  int columnCount,  int totalTiles,  double intervalSec)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VideoThumbnailTiles() when $default != null:
return $default(_that.url,_that.tileWidth,_that.tileHeight,_that.columnCount,_that.totalTiles,_that.intervalSec);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String url,  int tileWidth,  int tileHeight,  int columnCount,  int totalTiles,  double intervalSec)  $default,) {final _that = this;
switch (_that) {
case _VideoThumbnailTiles():
return $default(_that.url,_that.tileWidth,_that.tileHeight,_that.columnCount,_that.totalTiles,_that.intervalSec);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String url,  int tileWidth,  int tileHeight,  int columnCount,  int totalTiles,  double intervalSec)?  $default,) {final _that = this;
switch (_that) {
case _VideoThumbnailTiles() when $default != null:
return $default(_that.url,_that.tileWidth,_that.tileHeight,_that.columnCount,_that.totalTiles,_that.intervalSec);case _:
  return null;

}
}

}

/// @nodoc


class _VideoThumbnailTiles implements VideoThumbnailTiles {
  const _VideoThumbnailTiles({required this.url, required this.tileWidth, required this.tileHeight, required this.columnCount, required this.totalTiles, required this.intervalSec});
  

/// 並べた画像のURL (`/api/videos/{id}/thumbnail/tiled`)。
@override final  String url;
/// 1枚のタイルの幅 (px)。
@override final  int tileWidth;
/// 1枚のタイルの高さ (px)。
@override final  int tileHeight;
/// 1行のタイル枚数。
@override final  int columnCount;
/// タイルの総枚数。
@override final  int totalTiles;
/// 隣り合うタイルの時刻差 (秒)。
@override final  double intervalSec;

/// Create a copy of VideoThumbnailTiles
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VideoThumbnailTilesCopyWith<_VideoThumbnailTiles> get copyWith => __$VideoThumbnailTilesCopyWithImpl<_VideoThumbnailTiles>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VideoThumbnailTiles&&(identical(other.url, url) || other.url == url)&&(identical(other.tileWidth, tileWidth) || other.tileWidth == tileWidth)&&(identical(other.tileHeight, tileHeight) || other.tileHeight == tileHeight)&&(identical(other.columnCount, columnCount) || other.columnCount == columnCount)&&(identical(other.totalTiles, totalTiles) || other.totalTiles == totalTiles)&&(identical(other.intervalSec, intervalSec) || other.intervalSec == intervalSec));
}


@override
int get hashCode {
    return Object.hash(runtimeType,url,tileWidth,tileHeight,columnCount,totalTiles,intervalSec);
}

@override
String toString() {
    return 'VideoThumbnailTiles(url: $url, tileWidth: $tileWidth, tileHeight: $tileHeight, columnCount: $columnCount, totalTiles: $totalTiles, intervalSec: $intervalSec)';
}


}

/// @nodoc
abstract mixin class _$VideoThumbnailTilesCopyWith<$Res> implements $VideoThumbnailTilesCopyWith<$Res> {
  factory _$VideoThumbnailTilesCopyWith(_VideoThumbnailTiles value, $Res Function(_VideoThumbnailTiles) _then) = __$VideoThumbnailTilesCopyWithImpl;
@override @useResult
$Res call({
 String url, int tileWidth, int tileHeight, int columnCount, int totalTiles, double intervalSec
});




}
/// @nodoc
class __$VideoThumbnailTilesCopyWithImpl<$Res>
    implements _$VideoThumbnailTilesCopyWith<$Res> {
  __$VideoThumbnailTilesCopyWithImpl(this._self, this._then);

  final _VideoThumbnailTiles _self;
  final $Res Function(_VideoThumbnailTiles) _then;

/// Create a copy of VideoThumbnailTiles
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? url = null,Object? tileWidth = null,Object? tileHeight = null,Object? columnCount = null,Object? totalTiles = null,Object? intervalSec = null,}) {
  return _then(_VideoThumbnailTiles(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,tileWidth: null == tileWidth ? _self.tileWidth : tileWidth // ignore: cast_nullable_to_non_nullable
as int,tileHeight: null == tileHeight ? _self.tileHeight : tileHeight // ignore: cast_nullable_to_non_nullable
as int,columnCount: null == columnCount ? _self.columnCount : columnCount // ignore: cast_nullable_to_non_nullable
as int,totalTiles: null == totalTiles ? _self.totalTiles : totalTiles // ignore: cast_nullable_to_non_nullable
as int,intervalSec: null == intervalSec ? _self.intervalSec : intervalSec // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
