// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'channel_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ChannelItem {

 Channel get channel; TvProgram? get nowOnAir; TvProgram? get nextUp;
/// Create a copy of ChannelItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChannelItemCopyWith<ChannelItem> get copyWith => _$ChannelItemCopyWithImpl<ChannelItem>(this as ChannelItem, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ChannelItem;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChannelItem&&(identical(other.channel, _this.channel) || other.channel == _this.channel)&&(identical(other.nowOnAir, _this.nowOnAir) || other.nowOnAir == _this.nowOnAir)&&(identical(other.nextUp, _this.nextUp) || other.nextUp == _this.nextUp));
}


@override
int get hashCode {
  final _this = this as ChannelItem;
  return Object.hash(runtimeType,_this.channel,_this.nowOnAir,_this.nextUp);
}

@override
String toString() {
  final _this = this as ChannelItem;
  return 'ChannelItem(channel: ${_this.channel}, nowOnAir: ${_this.nowOnAir}, nextUp: ${_this.nextUp})';
}


}

/// @nodoc
abstract mixin class $ChannelItemCopyWith<$Res>  {
  factory $ChannelItemCopyWith(ChannelItem value, $Res Function(ChannelItem) _then) = _$ChannelItemCopyWithImpl;
@useResult
$Res call({
 Channel channel, TvProgram? nowOnAir, TvProgram? nextUp
});


$ChannelCopyWith<$Res> get channel;$TvProgramCopyWith<$Res>? get nowOnAir;$TvProgramCopyWith<$Res>? get nextUp;

}
/// @nodoc
class _$ChannelItemCopyWithImpl<$Res>
    implements $ChannelItemCopyWith<$Res> {
  _$ChannelItemCopyWithImpl(this._self, this._then);

  final ChannelItem _self;
  final $Res Function(ChannelItem) _then;

/// Create a copy of ChannelItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? channel = null,Object? nowOnAir = freezed,Object? nextUp = freezed,}) {
  return _then(ChannelItem(
channel: null == channel ? _self.channel : channel // ignore: cast_nullable_to_non_nullable
as Channel,nowOnAir: freezed == nowOnAir ? _self.nowOnAir : nowOnAir // ignore: cast_nullable_to_non_nullable
as TvProgram?,nextUp: freezed == nextUp ? _self.nextUp : nextUp // ignore: cast_nullable_to_non_nullable
as TvProgram?,
  ));
}
/// Create a copy of ChannelItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ChannelCopyWith<$Res> get channel {
  
  return $ChannelCopyWith<$Res>(_self.channel, (value) {
    return _then(_self.copyWith(channel: value));
  });
}/// Create a copy of ChannelItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TvProgramCopyWith<$Res>? get nowOnAir {
    if (_self.nowOnAir == null) {
    return null;
  }

  return $TvProgramCopyWith<$Res>(_self.nowOnAir!, (value) {
    return _then(_self.copyWith(nowOnAir: value));
  });
}/// Create a copy of ChannelItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TvProgramCopyWith<$Res>? get nextUp {
    if (_self.nextUp == null) {
    return null;
  }

  return $TvProgramCopyWith<$Res>(_self.nextUp!, (value) {
    return _then(_self.copyWith(nextUp: value));
  });
}
}


/// Adds pattern-matching-related methods to [ChannelItem].
extension ChannelItemPatterns on ChannelItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChannelItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChannelItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChannelItem value)  $default,){
final _that = this;
switch (_that) {
case _ChannelItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChannelItem value)?  $default,){
final _that = this;
switch (_that) {
case _ChannelItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Channel channel,  TvProgram? nowOnAir,  TvProgram? nextUp)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChannelItem() when $default != null:
return $default(_that.channel,_that.nowOnAir,_that.nextUp);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Channel channel,  TvProgram? nowOnAir,  TvProgram? nextUp)  $default,) {final _that = this;
switch (_that) {
case _ChannelItem():
return $default(_that.channel,_that.nowOnAir,_that.nextUp);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Channel channel,  TvProgram? nowOnAir,  TvProgram? nextUp)?  $default,) {final _that = this;
switch (_that) {
case _ChannelItem() when $default != null:
return $default(_that.channel,_that.nowOnAir,_that.nextUp);case _:
  return null;

}
}

}

/// @nodoc


class _ChannelItem implements ChannelItem {
  const _ChannelItem({required this.channel, required this.nowOnAir, required this.nextUp});
  

@override final  Channel channel;
@override final  TvProgram? nowOnAir;
@override final  TvProgram? nextUp;

/// Create a copy of ChannelItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChannelItemCopyWith<_ChannelItem> get copyWith => __$ChannelItemCopyWithImpl<_ChannelItem>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChannelItem&&(identical(other.channel, channel) || other.channel == channel)&&(identical(other.nowOnAir, nowOnAir) || other.nowOnAir == nowOnAir)&&(identical(other.nextUp, nextUp) || other.nextUp == nextUp));
}


@override
int get hashCode {
    return Object.hash(runtimeType,channel,nowOnAir,nextUp);
}

@override
String toString() {
    return 'ChannelItem(channel: $channel, nowOnAir: $nowOnAir, nextUp: $nextUp)';
}


}

/// @nodoc
abstract mixin class _$ChannelItemCopyWith<$Res> implements $ChannelItemCopyWith<$Res> {
  factory _$ChannelItemCopyWith(_ChannelItem value, $Res Function(_ChannelItem) _then) = __$ChannelItemCopyWithImpl;
@override @useResult
$Res call({
 Channel channel, TvProgram? nowOnAir, TvProgram? nextUp
});


@override $ChannelCopyWith<$Res> get channel;@override $TvProgramCopyWith<$Res>? get nowOnAir;@override $TvProgramCopyWith<$Res>? get nextUp;

}
/// @nodoc
class __$ChannelItemCopyWithImpl<$Res>
    implements _$ChannelItemCopyWith<$Res> {
  __$ChannelItemCopyWithImpl(this._self, this._then);

  final _ChannelItem _self;
  final $Res Function(_ChannelItem) _then;

/// Create a copy of ChannelItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? channel = null,Object? nowOnAir = freezed,Object? nextUp = freezed,}) {
  return _then(_ChannelItem(
channel: null == channel ? _self.channel : channel // ignore: cast_nullable_to_non_nullable
as Channel,nowOnAir: freezed == nowOnAir ? _self.nowOnAir : nowOnAir // ignore: cast_nullable_to_non_nullable
as TvProgram?,nextUp: freezed == nextUp ? _self.nextUp : nextUp // ignore: cast_nullable_to_non_nullable
as TvProgram?,
  ));
}

/// Create a copy of ChannelItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ChannelCopyWith<$Res> get channel {
  
  return $ChannelCopyWith<$Res>(_self.channel, (value) {
    return _then(_self.copyWith(channel: value));
  });
}/// Create a copy of ChannelItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TvProgramCopyWith<$Res>? get nowOnAir {
    if (_self.nowOnAir == null) {
    return null;
  }

  return $TvProgramCopyWith<$Res>(_self.nowOnAir!, (value) {
    return _then(_self.copyWith(nowOnAir: value));
  });
}/// Create a copy of ChannelItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TvProgramCopyWith<$Res>? get nextUp {
    if (_self.nextUp == null) {
    return null;
  }

  return $TvProgramCopyWith<$Res>(_self.nextUp!, (value) {
    return _then(_self.copyWith(nextUp: value));
  });
}
}

// dart format on
