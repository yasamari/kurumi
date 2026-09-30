// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'channel.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Channel {

 String get id; String get name; ChannelType get channelType;/// MPEG-TS の network_id。Mirakurun の `networkId` /
/// KonomiTV の `network_id` をそのまま保持する。
///
/// バックエンドに依存しない ID で、ニコニコ実況チャンネル
/// (`jk1` 等) への変換キーとして使う。
 int get networkId;/// MPEG-TS の service_id。Mirakurun の `serviceId` /
/// KonomiTV の `service_id` をそのまま保持する。
 int get serviceId;/// ヘッダー表示用のチャンネル番号 (例: `011`)。なければ空文字。
 String get channelNumber;/// ロゴ画像のURL。なければ null。
 String? get logoUrl;
/// Create a copy of Channel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChannelCopyWith<Channel> get copyWith => _$ChannelCopyWithImpl<Channel>(this as Channel, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Channel;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Channel&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.channelType, _this.channelType) || other.channelType == _this.channelType)&&(identical(other.networkId, _this.networkId) || other.networkId == _this.networkId)&&(identical(other.serviceId, _this.serviceId) || other.serviceId == _this.serviceId)&&(identical(other.channelNumber, _this.channelNumber) || other.channelNumber == _this.channelNumber)&&(identical(other.logoUrl, _this.logoUrl) || other.logoUrl == _this.logoUrl));
}


@override
int get hashCode {
  final _this = this as Channel;
  return Object.hash(runtimeType,_this.id,_this.name,_this.channelType,_this.networkId,_this.serviceId,_this.channelNumber,_this.logoUrl);
}

@override
String toString() {
  final _this = this as Channel;
  return 'Channel(id: ${_this.id}, name: ${_this.name}, channelType: ${_this.channelType}, networkId: ${_this.networkId}, serviceId: ${_this.serviceId}, channelNumber: ${_this.channelNumber}, logoUrl: ${_this.logoUrl})';
}


}

/// @nodoc
abstract mixin class $ChannelCopyWith<$Res>  {
  factory $ChannelCopyWith(Channel value, $Res Function(Channel) _then) = _$ChannelCopyWithImpl;
@useResult
$Res call({
 String id, String name, ChannelType channelType, int networkId, int serviceId, String channelNumber, String? logoUrl
});


$ChannelTypeCopyWith<$Res> get channelType;

}
/// @nodoc
class _$ChannelCopyWithImpl<$Res>
    implements $ChannelCopyWith<$Res> {
  _$ChannelCopyWithImpl(this._self, this._then);

  final Channel _self;
  final $Res Function(Channel) _then;

/// Create a copy of Channel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? channelType = null,Object? networkId = null,Object? serviceId = null,Object? channelNumber = null,Object? logoUrl = freezed,}) {
  return _then(Channel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,channelType: null == channelType ? _self.channelType : channelType // ignore: cast_nullable_to_non_nullable
as ChannelType,networkId: null == networkId ? _self.networkId : networkId // ignore: cast_nullable_to_non_nullable
as int,serviceId: null == serviceId ? _self.serviceId : serviceId // ignore: cast_nullable_to_non_nullable
as int,channelNumber: null == channelNumber ? _self.channelNumber : channelNumber // ignore: cast_nullable_to_non_nullable
as String,logoUrl: freezed == logoUrl ? _self.logoUrl : logoUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of Channel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ChannelTypeCopyWith<$Res> get channelType {
  
  return $ChannelTypeCopyWith<$Res>(_self.channelType, (value) {
    return _then(_self.copyWith(channelType: value));
  });
}
}


/// Adds pattern-matching-related methods to [Channel].
extension ChannelPatterns on Channel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Channel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Channel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Channel value)  $default,){
final _that = this;
switch (_that) {
case _Channel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Channel value)?  $default,){
final _that = this;
switch (_that) {
case _Channel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  ChannelType channelType,  int networkId,  int serviceId,  String channelNumber,  String? logoUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Channel() when $default != null:
return $default(_that.id,_that.name,_that.channelType,_that.networkId,_that.serviceId,_that.channelNumber,_that.logoUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  ChannelType channelType,  int networkId,  int serviceId,  String channelNumber,  String? logoUrl)  $default,) {final _that = this;
switch (_that) {
case _Channel():
return $default(_that.id,_that.name,_that.channelType,_that.networkId,_that.serviceId,_that.channelNumber,_that.logoUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  ChannelType channelType,  int networkId,  int serviceId,  String channelNumber,  String? logoUrl)?  $default,) {final _that = this;
switch (_that) {
case _Channel() when $default != null:
return $default(_that.id,_that.name,_that.channelType,_that.networkId,_that.serviceId,_that.channelNumber,_that.logoUrl);case _:
  return null;

}
}

}

/// @nodoc


class _Channel implements Channel {
  const _Channel({required this.id, required this.name, required this.channelType, required this.networkId, required this.serviceId, this.channelNumber = '', this.logoUrl});
  

@override final  String id;
@override final  String name;
@override final  ChannelType channelType;
/// MPEG-TS の network_id。Mirakurun の `networkId` /
/// KonomiTV の `network_id` をそのまま保持する。
///
/// バックエンドに依存しない ID で、ニコニコ実況チャンネル
/// (`jk1` 等) への変換キーとして使う。
@override final  int networkId;
/// MPEG-TS の service_id。Mirakurun の `serviceId` /
/// KonomiTV の `service_id` をそのまま保持する。
@override final  int serviceId;
/// ヘッダー表示用のチャンネル番号 (例: `011`)。なければ空文字。
@override@JsonKey() final  String channelNumber;
/// ロゴ画像のURL。なければ null。
@override final  String? logoUrl;

/// Create a copy of Channel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChannelCopyWith<_Channel> get copyWith => __$ChannelCopyWithImpl<_Channel>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Channel&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.channelType, channelType) || other.channelType == channelType)&&(identical(other.networkId, networkId) || other.networkId == networkId)&&(identical(other.serviceId, serviceId) || other.serviceId == serviceId)&&(identical(other.channelNumber, channelNumber) || other.channelNumber == channelNumber)&&(identical(other.logoUrl, logoUrl) || other.logoUrl == logoUrl));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,name,channelType,networkId,serviceId,channelNumber,logoUrl);
}

@override
String toString() {
    return 'Channel(id: $id, name: $name, channelType: $channelType, networkId: $networkId, serviceId: $serviceId, channelNumber: $channelNumber, logoUrl: $logoUrl)';
}


}

/// @nodoc
abstract mixin class _$ChannelCopyWith<$Res> implements $ChannelCopyWith<$Res> {
  factory _$ChannelCopyWith(_Channel value, $Res Function(_Channel) _then) = __$ChannelCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, ChannelType channelType, int networkId, int serviceId, String channelNumber, String? logoUrl
});


@override $ChannelTypeCopyWith<$Res> get channelType;

}
/// @nodoc
class __$ChannelCopyWithImpl<$Res>
    implements _$ChannelCopyWith<$Res> {
  __$ChannelCopyWithImpl(this._self, this._then);

  final _Channel _self;
  final $Res Function(_Channel) _then;

/// Create a copy of Channel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? channelType = null,Object? networkId = null,Object? serviceId = null,Object? channelNumber = null,Object? logoUrl = freezed,}) {
  return _then(_Channel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,channelType: null == channelType ? _self.channelType : channelType // ignore: cast_nullable_to_non_nullable
as ChannelType,networkId: null == networkId ? _self.networkId : networkId // ignore: cast_nullable_to_non_nullable
as int,serviceId: null == serviceId ? _self.serviceId : serviceId // ignore: cast_nullable_to_non_nullable
as int,channelNumber: null == channelNumber ? _self.channelNumber : channelNumber // ignore: cast_nullable_to_non_nullable
as String,logoUrl: freezed == logoUrl ? _self.logoUrl : logoUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of Channel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ChannelTypeCopyWith<$Res> get channelType {
  
  return $ChannelTypeCopyWith<$Res>(_self.channelType, (value) {
    return _then(_self.copyWith(channelType: value));
  });
}
}

// dart format on
