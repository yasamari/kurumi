// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cm_section.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CmSection {

/// CM開始位置 (秒)。0以上。
 double get startTime;/// CM終了位置 (秒)。[startTime] より大きい。
 double get endTime;
/// Create a copy of CmSection
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CmSectionCopyWith<CmSection> get copyWith => _$CmSectionCopyWithImpl<CmSection>(this as CmSection, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CmSection;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CmSection&&(identical(other.startTime, _this.startTime) || other.startTime == _this.startTime)&&(identical(other.endTime, _this.endTime) || other.endTime == _this.endTime));
}


@override
int get hashCode {
  final _this = this as CmSection;
  return Object.hash(runtimeType,_this.startTime,_this.endTime);
}

@override
String toString() {
  final _this = this as CmSection;
  return 'CmSection(startTime: ${_this.startTime}, endTime: ${_this.endTime})';
}


}

/// @nodoc
abstract mixin class $CmSectionCopyWith<$Res>  {
  factory $CmSectionCopyWith(CmSection value, $Res Function(CmSection) _then) = _$CmSectionCopyWithImpl;
@useResult
$Res call({
 double startTime, double endTime
});




}
/// @nodoc
class _$CmSectionCopyWithImpl<$Res>
    implements $CmSectionCopyWith<$Res> {
  _$CmSectionCopyWithImpl(this._self, this._then);

  final CmSection _self;
  final $Res Function(CmSection) _then;

/// Create a copy of CmSection
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? startTime = null,Object? endTime = null,}) {
  return _then(CmSection(
startTime: null == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as double,endTime: null == endTime ? _self.endTime : endTime // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [CmSection].
extension CmSectionPatterns on CmSection {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CmSection value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CmSection() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CmSection value)  $default,){
final _that = this;
switch (_that) {
case _CmSection():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CmSection value)?  $default,){
final _that = this;
switch (_that) {
case _CmSection() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double startTime,  double endTime)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CmSection() when $default != null:
return $default(_that.startTime,_that.endTime);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double startTime,  double endTime)  $default,) {final _that = this;
switch (_that) {
case _CmSection():
return $default(_that.startTime,_that.endTime);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double startTime,  double endTime)?  $default,) {final _that = this;
switch (_that) {
case _CmSection() when $default != null:
return $default(_that.startTime,_that.endTime);case _:
  return null;

}
}

}

/// @nodoc


class _CmSection implements CmSection {
  const _CmSection({required this.startTime, required this.endTime});
  

/// CM開始位置 (秒)。0以上。
@override final  double startTime;
/// CM終了位置 (秒)。[startTime] より大きい。
@override final  double endTime;

/// Create a copy of CmSection
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CmSectionCopyWith<_CmSection> get copyWith => __$CmSectionCopyWithImpl<_CmSection>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CmSection&&(identical(other.startTime, startTime) || other.startTime == startTime)&&(identical(other.endTime, endTime) || other.endTime == endTime));
}


@override
int get hashCode {
    return Object.hash(runtimeType,startTime,endTime);
}

@override
String toString() {
    return 'CmSection(startTime: $startTime, endTime: $endTime)';
}


}

/// @nodoc
abstract mixin class _$CmSectionCopyWith<$Res> implements $CmSectionCopyWith<$Res> {
  factory _$CmSectionCopyWith(_CmSection value, $Res Function(_CmSection) _then) = __$CmSectionCopyWithImpl;
@override @useResult
$Res call({
 double startTime, double endTime
});




}
/// @nodoc
class __$CmSectionCopyWithImpl<$Res>
    implements _$CmSectionCopyWith<$Res> {
  __$CmSectionCopyWithImpl(this._self, this._then);

  final _CmSection _self;
  final $Res Function(_CmSection) _then;

/// Create a copy of CmSection
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? startTime = null,Object? endTime = null,}) {
  return _then(_CmSection(
startTime: null == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as double,endTime: null == endTime ? _self.endTime : endTime // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
