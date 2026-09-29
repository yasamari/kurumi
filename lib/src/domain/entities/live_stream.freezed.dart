// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_stream.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LiveStream {

/// media_kit で直接開けるストリームURL。
 Uri get url;/// UI表示用の画質ラベル (例: `original`)。Mirakurunでは空文字。
 String get qualityLabel;
/// Create a copy of LiveStream
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveStreamCopyWith<LiveStream> get copyWith => _$LiveStreamCopyWithImpl<LiveStream>(this as LiveStream, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as LiveStream;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveStream&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.qualityLabel, _this.qualityLabel) || other.qualityLabel == _this.qualityLabel));
}


@override
int get hashCode {
  final _this = this as LiveStream;
  return Object.hash(runtimeType,_this.url,_this.qualityLabel);
}

@override
String toString() {
  final _this = this as LiveStream;
  return 'LiveStream(url: ${_this.url}, qualityLabel: ${_this.qualityLabel})';
}


}

/// @nodoc
abstract mixin class $LiveStreamCopyWith<$Res>  {
  factory $LiveStreamCopyWith(LiveStream value, $Res Function(LiveStream) _then) = _$LiveStreamCopyWithImpl;
@useResult
$Res call({
 Uri url, String qualityLabel
});




}
/// @nodoc
class _$LiveStreamCopyWithImpl<$Res>
    implements $LiveStreamCopyWith<$Res> {
  _$LiveStreamCopyWithImpl(this._self, this._then);

  final LiveStream _self;
  final $Res Function(LiveStream) _then;

/// Create a copy of LiveStream
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? url = null,Object? qualityLabel = null,}) {
  return _then(LiveStream(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as Uri,qualityLabel: null == qualityLabel ? _self.qualityLabel : qualityLabel // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveStream].
extension LiveStreamPatterns on LiveStream {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveStream value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveStream() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveStream value)  $default,){
final _that = this;
switch (_that) {
case _LiveStream():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveStream value)?  $default,){
final _that = this;
switch (_that) {
case _LiveStream() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Uri url,  String qualityLabel)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveStream() when $default != null:
return $default(_that.url,_that.qualityLabel);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Uri url,  String qualityLabel)  $default,) {final _that = this;
switch (_that) {
case _LiveStream():
return $default(_that.url,_that.qualityLabel);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Uri url,  String qualityLabel)?  $default,) {final _that = this;
switch (_that) {
case _LiveStream() when $default != null:
return $default(_that.url,_that.qualityLabel);case _:
  return null;

}
}

}

/// @nodoc


class _LiveStream implements LiveStream {
  const _LiveStream({required this.url, this.qualityLabel = ''});
  

/// media_kit で直接開けるストリームURL。
@override final  Uri url;
/// UI表示用の画質ラベル (例: `original`)。Mirakurunでは空文字。
@override@JsonKey() final  String qualityLabel;

/// Create a copy of LiveStream
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveStreamCopyWith<_LiveStream> get copyWith => __$LiveStreamCopyWithImpl<_LiveStream>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveStream&&(identical(other.url, url) || other.url == url)&&(identical(other.qualityLabel, qualityLabel) || other.qualityLabel == qualityLabel));
}


@override
int get hashCode {
    return Object.hash(runtimeType,url,qualityLabel);
}

@override
String toString() {
    return 'LiveStream(url: $url, qualityLabel: $qualityLabel)';
}


}

/// @nodoc
abstract mixin class _$LiveStreamCopyWith<$Res> implements $LiveStreamCopyWith<$Res> {
  factory _$LiveStreamCopyWith(_LiveStream value, $Res Function(_LiveStream) _then) = __$LiveStreamCopyWithImpl;
@override @useResult
$Res call({
 Uri url, String qualityLabel
});




}
/// @nodoc
class __$LiveStreamCopyWithImpl<$Res>
    implements _$LiveStreamCopyWith<$Res> {
  __$LiveStreamCopyWithImpl(this._self, this._then);

  final _LiveStream _self;
  final $Res Function(_LiveStream) _then;

/// Create a copy of LiveStream
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? url = null,Object? qualityLabel = null,}) {
  return _then(_LiveStream(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as Uri,qualityLabel: null == qualityLabel ? _self.qualityLabel : qualityLabel // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
