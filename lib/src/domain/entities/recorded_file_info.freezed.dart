// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recorded_file_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RecordedFileInfo {

/// 録画ファイルのサーバー上のパス。
 String get filePath;/// ファイルサイズ (バイト)。
 int get fileSize;/// 録画の開始・終了日時。録画中の番組では null になりうる。
 DateTime? get recordingStartTime; DateTime? get recordingEndTime;/// ファイルの最終更新日時。
 DateTime? get fileModifiedAt;/// 映像コーデック (例: `H.264`)。不明時は null。
 String? get videoCodec;/// 映像解像度 (幅・高さ)。不明時は null。
 int? get resolutionWidth; int? get resolutionHeight;/// フレームレート (例: `29.97`)。不明時は null。
 double? get frameRate;/// スキャン方式 (`Interlaced` / `Progressive`)。不明時は null。
 String? get scanType;/// 音声コーデック (例: `AAC-LC`)。不明時は null。
 String? get audioCodec;/// 音声チャンネル (`Monaural` / `Stereo` / `5.1ch`)。不明時は null。
 String? get audioChannel;/// 音声サンプリングレート (Hz)。不明時は null。
 int? get samplingRate;
/// Create a copy of RecordedFileInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RecordedFileInfoCopyWith<RecordedFileInfo> get copyWith => _$RecordedFileInfoCopyWithImpl<RecordedFileInfo>(this as RecordedFileInfo, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as RecordedFileInfo;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RecordedFileInfo&&(identical(other.filePath, _this.filePath) || other.filePath == _this.filePath)&&(identical(other.fileSize, _this.fileSize) || other.fileSize == _this.fileSize)&&(identical(other.recordingStartTime, _this.recordingStartTime) || other.recordingStartTime == _this.recordingStartTime)&&(identical(other.recordingEndTime, _this.recordingEndTime) || other.recordingEndTime == _this.recordingEndTime)&&(identical(other.fileModifiedAt, _this.fileModifiedAt) || other.fileModifiedAt == _this.fileModifiedAt)&&(identical(other.videoCodec, _this.videoCodec) || other.videoCodec == _this.videoCodec)&&(identical(other.resolutionWidth, _this.resolutionWidth) || other.resolutionWidth == _this.resolutionWidth)&&(identical(other.resolutionHeight, _this.resolutionHeight) || other.resolutionHeight == _this.resolutionHeight)&&(identical(other.frameRate, _this.frameRate) || other.frameRate == _this.frameRate)&&(identical(other.scanType, _this.scanType) || other.scanType == _this.scanType)&&(identical(other.audioCodec, _this.audioCodec) || other.audioCodec == _this.audioCodec)&&(identical(other.audioChannel, _this.audioChannel) || other.audioChannel == _this.audioChannel)&&(identical(other.samplingRate, _this.samplingRate) || other.samplingRate == _this.samplingRate));
}


@override
int get hashCode {
  final _this = this as RecordedFileInfo;
  return Object.hash(runtimeType,_this.filePath,_this.fileSize,_this.recordingStartTime,_this.recordingEndTime,_this.fileModifiedAt,_this.videoCodec,_this.resolutionWidth,_this.resolutionHeight,_this.frameRate,_this.scanType,_this.audioCodec,_this.audioChannel,_this.samplingRate);
}

@override
String toString() {
  final _this = this as RecordedFileInfo;
  return 'RecordedFileInfo(filePath: ${_this.filePath}, fileSize: ${_this.fileSize}, recordingStartTime: ${_this.recordingStartTime}, recordingEndTime: ${_this.recordingEndTime}, fileModifiedAt: ${_this.fileModifiedAt}, videoCodec: ${_this.videoCodec}, resolutionWidth: ${_this.resolutionWidth}, resolutionHeight: ${_this.resolutionHeight}, frameRate: ${_this.frameRate}, scanType: ${_this.scanType}, audioCodec: ${_this.audioCodec}, audioChannel: ${_this.audioChannel}, samplingRate: ${_this.samplingRate})';
}


}

/// @nodoc
abstract mixin class $RecordedFileInfoCopyWith<$Res>  {
  factory $RecordedFileInfoCopyWith(RecordedFileInfo value, $Res Function(RecordedFileInfo) _then) = _$RecordedFileInfoCopyWithImpl;
@useResult
$Res call({
 String filePath, int fileSize, DateTime? recordingStartTime, DateTime? recordingEndTime, DateTime? fileModifiedAt, String? videoCodec, int? resolutionWidth, int? resolutionHeight, double? frameRate, String? scanType, String? audioCodec, String? audioChannel, int? samplingRate
});




}
/// @nodoc
class _$RecordedFileInfoCopyWithImpl<$Res>
    implements $RecordedFileInfoCopyWith<$Res> {
  _$RecordedFileInfoCopyWithImpl(this._self, this._then);

  final RecordedFileInfo _self;
  final $Res Function(RecordedFileInfo) _then;

/// Create a copy of RecordedFileInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? filePath = null,Object? fileSize = null,Object? recordingStartTime = freezed,Object? recordingEndTime = freezed,Object? fileModifiedAt = freezed,Object? videoCodec = freezed,Object? resolutionWidth = freezed,Object? resolutionHeight = freezed,Object? frameRate = freezed,Object? scanType = freezed,Object? audioCodec = freezed,Object? audioChannel = freezed,Object? samplingRate = freezed,}) {
  return _then(RecordedFileInfo(
filePath: null == filePath ? _self.filePath : filePath // ignore: cast_nullable_to_non_nullable
as String,fileSize: null == fileSize ? _self.fileSize : fileSize // ignore: cast_nullable_to_non_nullable
as int,recordingStartTime: freezed == recordingStartTime ? _self.recordingStartTime : recordingStartTime // ignore: cast_nullable_to_non_nullable
as DateTime?,recordingEndTime: freezed == recordingEndTime ? _self.recordingEndTime : recordingEndTime // ignore: cast_nullable_to_non_nullable
as DateTime?,fileModifiedAt: freezed == fileModifiedAt ? _self.fileModifiedAt : fileModifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,videoCodec: freezed == videoCodec ? _self.videoCodec : videoCodec // ignore: cast_nullable_to_non_nullable
as String?,resolutionWidth: freezed == resolutionWidth ? _self.resolutionWidth : resolutionWidth // ignore: cast_nullable_to_non_nullable
as int?,resolutionHeight: freezed == resolutionHeight ? _self.resolutionHeight : resolutionHeight // ignore: cast_nullable_to_non_nullable
as int?,frameRate: freezed == frameRate ? _self.frameRate : frameRate // ignore: cast_nullable_to_non_nullable
as double?,scanType: freezed == scanType ? _self.scanType : scanType // ignore: cast_nullable_to_non_nullable
as String?,audioCodec: freezed == audioCodec ? _self.audioCodec : audioCodec // ignore: cast_nullable_to_non_nullable
as String?,audioChannel: freezed == audioChannel ? _self.audioChannel : audioChannel // ignore: cast_nullable_to_non_nullable
as String?,samplingRate: freezed == samplingRate ? _self.samplingRate : samplingRate // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [RecordedFileInfo].
extension RecordedFileInfoPatterns on RecordedFileInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RecordedFileInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RecordedFileInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RecordedFileInfo value)  $default,){
final _that = this;
switch (_that) {
case _RecordedFileInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RecordedFileInfo value)?  $default,){
final _that = this;
switch (_that) {
case _RecordedFileInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String filePath,  int fileSize,  DateTime? recordingStartTime,  DateTime? recordingEndTime,  DateTime? fileModifiedAt,  String? videoCodec,  int? resolutionWidth,  int? resolutionHeight,  double? frameRate,  String? scanType,  String? audioCodec,  String? audioChannel,  int? samplingRate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RecordedFileInfo() when $default != null:
return $default(_that.filePath,_that.fileSize,_that.recordingStartTime,_that.recordingEndTime,_that.fileModifiedAt,_that.videoCodec,_that.resolutionWidth,_that.resolutionHeight,_that.frameRate,_that.scanType,_that.audioCodec,_that.audioChannel,_that.samplingRate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String filePath,  int fileSize,  DateTime? recordingStartTime,  DateTime? recordingEndTime,  DateTime? fileModifiedAt,  String? videoCodec,  int? resolutionWidth,  int? resolutionHeight,  double? frameRate,  String? scanType,  String? audioCodec,  String? audioChannel,  int? samplingRate)  $default,) {final _that = this;
switch (_that) {
case _RecordedFileInfo():
return $default(_that.filePath,_that.fileSize,_that.recordingStartTime,_that.recordingEndTime,_that.fileModifiedAt,_that.videoCodec,_that.resolutionWidth,_that.resolutionHeight,_that.frameRate,_that.scanType,_that.audioCodec,_that.audioChannel,_that.samplingRate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String filePath,  int fileSize,  DateTime? recordingStartTime,  DateTime? recordingEndTime,  DateTime? fileModifiedAt,  String? videoCodec,  int? resolutionWidth,  int? resolutionHeight,  double? frameRate,  String? scanType,  String? audioCodec,  String? audioChannel,  int? samplingRate)?  $default,) {final _that = this;
switch (_that) {
case _RecordedFileInfo() when $default != null:
return $default(_that.filePath,_that.fileSize,_that.recordingStartTime,_that.recordingEndTime,_that.fileModifiedAt,_that.videoCodec,_that.resolutionWidth,_that.resolutionHeight,_that.frameRate,_that.scanType,_that.audioCodec,_that.audioChannel,_that.samplingRate);case _:
  return null;

}
}

}

/// @nodoc


class _RecordedFileInfo implements RecordedFileInfo {
  const _RecordedFileInfo({this.filePath = '', this.fileSize = 0, this.recordingStartTime, this.recordingEndTime, this.fileModifiedAt, this.videoCodec, this.resolutionWidth, this.resolutionHeight, this.frameRate, this.scanType, this.audioCodec, this.audioChannel, this.samplingRate});
  

/// 録画ファイルのサーバー上のパス。
@override@JsonKey() final  String filePath;
/// ファイルサイズ (バイト)。
@override@JsonKey() final  int fileSize;
/// 録画の開始・終了日時。録画中の番組では null になりうる。
@override final  DateTime? recordingStartTime;
@override final  DateTime? recordingEndTime;
/// ファイルの最終更新日時。
@override final  DateTime? fileModifiedAt;
/// 映像コーデック (例: `H.264`)。不明時は null。
@override final  String? videoCodec;
/// 映像解像度 (幅・高さ)。不明時は null。
@override final  int? resolutionWidth;
@override final  int? resolutionHeight;
/// フレームレート (例: `29.97`)。不明時は null。
@override final  double? frameRate;
/// スキャン方式 (`Interlaced` / `Progressive`)。不明時は null。
@override final  String? scanType;
/// 音声コーデック (例: `AAC-LC`)。不明時は null。
@override final  String? audioCodec;
/// 音声チャンネル (`Monaural` / `Stereo` / `5.1ch`)。不明時は null。
@override final  String? audioChannel;
/// 音声サンプリングレート (Hz)。不明時は null。
@override final  int? samplingRate;

/// Create a copy of RecordedFileInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RecordedFileInfoCopyWith<_RecordedFileInfo> get copyWith => __$RecordedFileInfoCopyWithImpl<_RecordedFileInfo>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RecordedFileInfo&&(identical(other.filePath, filePath) || other.filePath == filePath)&&(identical(other.fileSize, fileSize) || other.fileSize == fileSize)&&(identical(other.recordingStartTime, recordingStartTime) || other.recordingStartTime == recordingStartTime)&&(identical(other.recordingEndTime, recordingEndTime) || other.recordingEndTime == recordingEndTime)&&(identical(other.fileModifiedAt, fileModifiedAt) || other.fileModifiedAt == fileModifiedAt)&&(identical(other.videoCodec, videoCodec) || other.videoCodec == videoCodec)&&(identical(other.resolutionWidth, resolutionWidth) || other.resolutionWidth == resolutionWidth)&&(identical(other.resolutionHeight, resolutionHeight) || other.resolutionHeight == resolutionHeight)&&(identical(other.frameRate, frameRate) || other.frameRate == frameRate)&&(identical(other.scanType, scanType) || other.scanType == scanType)&&(identical(other.audioCodec, audioCodec) || other.audioCodec == audioCodec)&&(identical(other.audioChannel, audioChannel) || other.audioChannel == audioChannel)&&(identical(other.samplingRate, samplingRate) || other.samplingRate == samplingRate));
}


@override
int get hashCode {
    return Object.hash(runtimeType,filePath,fileSize,recordingStartTime,recordingEndTime,fileModifiedAt,videoCodec,resolutionWidth,resolutionHeight,frameRate,scanType,audioCodec,audioChannel,samplingRate);
}

@override
String toString() {
    return 'RecordedFileInfo(filePath: $filePath, fileSize: $fileSize, recordingStartTime: $recordingStartTime, recordingEndTime: $recordingEndTime, fileModifiedAt: $fileModifiedAt, videoCodec: $videoCodec, resolutionWidth: $resolutionWidth, resolutionHeight: $resolutionHeight, frameRate: $frameRate, scanType: $scanType, audioCodec: $audioCodec, audioChannel: $audioChannel, samplingRate: $samplingRate)';
}


}

/// @nodoc
abstract mixin class _$RecordedFileInfoCopyWith<$Res> implements $RecordedFileInfoCopyWith<$Res> {
  factory _$RecordedFileInfoCopyWith(_RecordedFileInfo value, $Res Function(_RecordedFileInfo) _then) = __$RecordedFileInfoCopyWithImpl;
@override @useResult
$Res call({
 String filePath, int fileSize, DateTime? recordingStartTime, DateTime? recordingEndTime, DateTime? fileModifiedAt, String? videoCodec, int? resolutionWidth, int? resolutionHeight, double? frameRate, String? scanType, String? audioCodec, String? audioChannel, int? samplingRate
});




}
/// @nodoc
class __$RecordedFileInfoCopyWithImpl<$Res>
    implements _$RecordedFileInfoCopyWith<$Res> {
  __$RecordedFileInfoCopyWithImpl(this._self, this._then);

  final _RecordedFileInfo _self;
  final $Res Function(_RecordedFileInfo) _then;

/// Create a copy of RecordedFileInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? filePath = null,Object? fileSize = null,Object? recordingStartTime = freezed,Object? recordingEndTime = freezed,Object? fileModifiedAt = freezed,Object? videoCodec = freezed,Object? resolutionWidth = freezed,Object? resolutionHeight = freezed,Object? frameRate = freezed,Object? scanType = freezed,Object? audioCodec = freezed,Object? audioChannel = freezed,Object? samplingRate = freezed,}) {
  return _then(_RecordedFileInfo(
filePath: null == filePath ? _self.filePath : filePath // ignore: cast_nullable_to_non_nullable
as String,fileSize: null == fileSize ? _self.fileSize : fileSize // ignore: cast_nullable_to_non_nullable
as int,recordingStartTime: freezed == recordingStartTime ? _self.recordingStartTime : recordingStartTime // ignore: cast_nullable_to_non_nullable
as DateTime?,recordingEndTime: freezed == recordingEndTime ? _self.recordingEndTime : recordingEndTime // ignore: cast_nullable_to_non_nullable
as DateTime?,fileModifiedAt: freezed == fileModifiedAt ? _self.fileModifiedAt : fileModifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,videoCodec: freezed == videoCodec ? _self.videoCodec : videoCodec // ignore: cast_nullable_to_non_nullable
as String?,resolutionWidth: freezed == resolutionWidth ? _self.resolutionWidth : resolutionWidth // ignore: cast_nullable_to_non_nullable
as int?,resolutionHeight: freezed == resolutionHeight ? _self.resolutionHeight : resolutionHeight // ignore: cast_nullable_to_non_nullable
as int?,frameRate: freezed == frameRate ? _self.frameRate : frameRate // ignore: cast_nullable_to_non_nullable
as double?,scanType: freezed == scanType ? _self.scanType : scanType // ignore: cast_nullable_to_non_nullable
as String?,audioCodec: freezed == audioCodec ? _self.audioCodec : audioCodec // ignore: cast_nullable_to_non_nullable
as String?,audioChannel: freezed == audioChannel ? _self.audioChannel : audioChannel // ignore: cast_nullable_to_non_nullable
as String?,samplingRate: freezed == samplingRate ? _self.samplingRate : samplingRate // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
