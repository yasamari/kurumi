// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'timetable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TimetableChannel {

 Channel get channel; List<TvProgram> get programs;
/// Create a copy of TimetableChannel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TimetableChannelCopyWith<TimetableChannel> get copyWith => _$TimetableChannelCopyWithImpl<TimetableChannel>(this as TimetableChannel, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as TimetableChannel;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TimetableChannel&&(identical(other.channel, _this.channel) || other.channel == _this.channel)&&const DeepCollectionEquality().equals(other.programs, _this.programs));
}


@override
int get hashCode {
  final _this = this as TimetableChannel;
  return Object.hash(runtimeType,_this.channel,const DeepCollectionEquality().hash(_this.programs));
}

@override
String toString() {
  final _this = this as TimetableChannel;
  return 'TimetableChannel(channel: ${_this.channel}, programs: ${_this.programs})';
}


}

/// @nodoc
abstract mixin class $TimetableChannelCopyWith<$Res>  {
  factory $TimetableChannelCopyWith(TimetableChannel value, $Res Function(TimetableChannel) _then) = _$TimetableChannelCopyWithImpl;
@useResult
$Res call({
 Channel channel, List<TvProgram> programs
});


$ChannelCopyWith<$Res> get channel;

}
/// @nodoc
class _$TimetableChannelCopyWithImpl<$Res>
    implements $TimetableChannelCopyWith<$Res> {
  _$TimetableChannelCopyWithImpl(this._self, this._then);

  final TimetableChannel _self;
  final $Res Function(TimetableChannel) _then;

/// Create a copy of TimetableChannel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? channel = null,Object? programs = null,}) {
  return _then(TimetableChannel(
channel: null == channel ? _self.channel : channel // ignore: cast_nullable_to_non_nullable
as Channel,programs: null == programs ? _self.programs : programs // ignore: cast_nullable_to_non_nullable
as List<TvProgram>,
  ));
}
/// Create a copy of TimetableChannel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ChannelCopyWith<$Res> get channel {
  
  return $ChannelCopyWith<$Res>(_self.channel, (value) {
    return _then(_self.copyWith(channel: value));
  });
}
}


/// Adds pattern-matching-related methods to [TimetableChannel].
extension TimetableChannelPatterns on TimetableChannel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TimetableChannel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TimetableChannel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TimetableChannel value)  $default,){
final _that = this;
switch (_that) {
case _TimetableChannel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TimetableChannel value)?  $default,){
final _that = this;
switch (_that) {
case _TimetableChannel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Channel channel,  List<TvProgram> programs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TimetableChannel() when $default != null:
return $default(_that.channel,_that.programs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Channel channel,  List<TvProgram> programs)  $default,) {final _that = this;
switch (_that) {
case _TimetableChannel():
return $default(_that.channel,_that.programs);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Channel channel,  List<TvProgram> programs)?  $default,) {final _that = this;
switch (_that) {
case _TimetableChannel() when $default != null:
return $default(_that.channel,_that.programs);case _:
  return null;

}
}

}

/// @nodoc


class _TimetableChannel implements TimetableChannel {
  const _TimetableChannel({required this.channel,  List<TvProgram> programs = const []}): _programs = programs;
  

@override final  Channel channel;
 final  List<TvProgram> _programs;
@override@JsonKey() List<TvProgram> get programs {
  if (_programs is EqualUnmodifiableListView) return _programs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_programs);
}


/// Create a copy of TimetableChannel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TimetableChannelCopyWith<_TimetableChannel> get copyWith => __$TimetableChannelCopyWithImpl<_TimetableChannel>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TimetableChannel&&(identical(other.channel, channel) || other.channel == channel)&&const DeepCollectionEquality().equals(other.programs, _programs));
}


@override
int get hashCode {
    return Object.hash(runtimeType,channel,const DeepCollectionEquality().hash(_programs));
}

@override
String toString() {
    return 'TimetableChannel(channel: $channel, programs: $programs)';
}


}

/// @nodoc
abstract mixin class _$TimetableChannelCopyWith<$Res> implements $TimetableChannelCopyWith<$Res> {
  factory _$TimetableChannelCopyWith(_TimetableChannel value, $Res Function(_TimetableChannel) _then) = __$TimetableChannelCopyWithImpl;
@override @useResult
$Res call({
 Channel channel, List<TvProgram> programs
});


@override $ChannelCopyWith<$Res> get channel;

}
/// @nodoc
class __$TimetableChannelCopyWithImpl<$Res>
    implements _$TimetableChannelCopyWith<$Res> {
  __$TimetableChannelCopyWithImpl(this._self, this._then);

  final _TimetableChannel _self;
  final $Res Function(_TimetableChannel) _then;

/// Create a copy of TimetableChannel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? channel = null,Object? programs = null,}) {
  return _then(_TimetableChannel(
channel: null == channel ? _self.channel : channel // ignore: cast_nullable_to_non_nullable
as Channel,programs: null == programs ? _self._programs : programs // ignore: cast_nullable_to_non_nullable
as List<TvProgram>,
  ));
}

/// Create a copy of TimetableChannel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ChannelCopyWith<$Res> get channel {
  
  return $ChannelCopyWith<$Res>(_self.channel, (value) {
    return _then(_self.copyWith(channel: value));
  });
}
}

/// @nodoc
mixin _$TimetableData {

 int get startMs; int get endMs; List<TimetableChannel> get channels;
/// Create a copy of TimetableData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TimetableDataCopyWith<TimetableData> get copyWith => _$TimetableDataCopyWithImpl<TimetableData>(this as TimetableData, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as TimetableData;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TimetableData&&(identical(other.startMs, _this.startMs) || other.startMs == _this.startMs)&&(identical(other.endMs, _this.endMs) || other.endMs == _this.endMs)&&const DeepCollectionEquality().equals(other.channels, _this.channels));
}


@override
int get hashCode {
  final _this = this as TimetableData;
  return Object.hash(runtimeType,_this.startMs,_this.endMs,const DeepCollectionEquality().hash(_this.channels));
}

@override
String toString() {
  final _this = this as TimetableData;
  return 'TimetableData(startMs: ${_this.startMs}, endMs: ${_this.endMs}, channels: ${_this.channels})';
}


}

/// @nodoc
abstract mixin class $TimetableDataCopyWith<$Res>  {
  factory $TimetableDataCopyWith(TimetableData value, $Res Function(TimetableData) _then) = _$TimetableDataCopyWithImpl;
@useResult
$Res call({
 int startMs, int endMs, List<TimetableChannel> channels
});




}
/// @nodoc
class _$TimetableDataCopyWithImpl<$Res>
    implements $TimetableDataCopyWith<$Res> {
  _$TimetableDataCopyWithImpl(this._self, this._then);

  final TimetableData _self;
  final $Res Function(TimetableData) _then;

/// Create a copy of TimetableData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? startMs = null,Object? endMs = null,Object? channels = null,}) {
  return _then(TimetableData(
startMs: null == startMs ? _self.startMs : startMs // ignore: cast_nullable_to_non_nullable
as int,endMs: null == endMs ? _self.endMs : endMs // ignore: cast_nullable_to_non_nullable
as int,channels: null == channels ? _self.channels : channels // ignore: cast_nullable_to_non_nullable
as List<TimetableChannel>,
  ));
}

}


/// Adds pattern-matching-related methods to [TimetableData].
extension TimetableDataPatterns on TimetableData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TimetableData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TimetableData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TimetableData value)  $default,){
final _that = this;
switch (_that) {
case _TimetableData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TimetableData value)?  $default,){
final _that = this;
switch (_that) {
case _TimetableData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int startMs,  int endMs,  List<TimetableChannel> channels)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TimetableData() when $default != null:
return $default(_that.startMs,_that.endMs,_that.channels);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int startMs,  int endMs,  List<TimetableChannel> channels)  $default,) {final _that = this;
switch (_that) {
case _TimetableData():
return $default(_that.startMs,_that.endMs,_that.channels);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int startMs,  int endMs,  List<TimetableChannel> channels)?  $default,) {final _that = this;
switch (_that) {
case _TimetableData() when $default != null:
return $default(_that.startMs,_that.endMs,_that.channels);case _:
  return null;

}
}

}

/// @nodoc


class _TimetableData implements TimetableData {
  const _TimetableData({required this.startMs, required this.endMs,  List<TimetableChannel> channels = const []}): _channels = channels;
  

@override final  int startMs;
@override final  int endMs;
 final  List<TimetableChannel> _channels;
@override@JsonKey() List<TimetableChannel> get channels {
  if (_channels is EqualUnmodifiableListView) return _channels;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_channels);
}


/// Create a copy of TimetableData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TimetableDataCopyWith<_TimetableData> get copyWith => __$TimetableDataCopyWithImpl<_TimetableData>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TimetableData&&(identical(other.startMs, startMs) || other.startMs == startMs)&&(identical(other.endMs, endMs) || other.endMs == endMs)&&const DeepCollectionEquality().equals(other.channels, _channels));
}


@override
int get hashCode {
    return Object.hash(runtimeType,startMs,endMs,const DeepCollectionEquality().hash(_channels));
}

@override
String toString() {
    return 'TimetableData(startMs: $startMs, endMs: $endMs, channels: $channels)';
}


}

/// @nodoc
abstract mixin class _$TimetableDataCopyWith<$Res> implements $TimetableDataCopyWith<$Res> {
  factory _$TimetableDataCopyWith(_TimetableData value, $Res Function(_TimetableData) _then) = __$TimetableDataCopyWithImpl;
@override @useResult
$Res call({
 int startMs, int endMs, List<TimetableChannel> channels
});




}
/// @nodoc
class __$TimetableDataCopyWithImpl<$Res>
    implements _$TimetableDataCopyWith<$Res> {
  __$TimetableDataCopyWithImpl(this._self, this._then);

  final _TimetableData _self;
  final $Res Function(_TimetableData) _then;

/// Create a copy of TimetableData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? startMs = null,Object? endMs = null,Object? channels = null,}) {
  return _then(_TimetableData(
startMs: null == startMs ? _self.startMs : startMs // ignore: cast_nullable_to_non_nullable
as int,endMs: null == endMs ? _self.endMs : endMs // ignore: cast_nullable_to_non_nullable
as int,channels: null == channels ? _self._channels : channels // ignore: cast_nullable_to_non_nullable
as List<TimetableChannel>,
  ));
}


}

// dart format on
