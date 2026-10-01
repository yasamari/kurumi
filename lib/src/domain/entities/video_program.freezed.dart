// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'video_program.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$VideoProgram {

/// 録画番組 ID (`/api/videos/{id}` の `video_id`)。
 int get id;/// 番組タイトル。
 String get title;/// シリーズ名。なければ null。
 String? get seriesTitle;/// 話数表記 (例: `第85話`)。なければ null。
 String? get episodeNumber;/// サブタイトル。なければ null。
 String? get subtitle;/// 番組概要。
 String get description;/// 番組詳細 (例: `{'出演者': '...'}`)。なければ空。
 Map<String, String> get detail;/// 放送開始・終了日時。
 DateTime get startAt; DateTime get endAt;/// 表示用のジャンル名一覧。なければ空。
 List<String> get genres;/// 放送チャンネル。チャンネル不明の録画では null。
 Channel? get channel;/// サムネイル画像のURL。
 String get thumbnailUrl;/// 録画ファイルの技術情報。取得できていない場合は null。
 RecordedFileInfo? get recordedFile;
/// Create a copy of VideoProgram
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VideoProgramCopyWith<VideoProgram> get copyWith => _$VideoProgramCopyWithImpl<VideoProgram>(this as VideoProgram, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as VideoProgram;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VideoProgram&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.seriesTitle, _this.seriesTitle) || other.seriesTitle == _this.seriesTitle)&&(identical(other.episodeNumber, _this.episodeNumber) || other.episodeNumber == _this.episodeNumber)&&(identical(other.subtitle, _this.subtitle) || other.subtitle == _this.subtitle)&&(identical(other.description, _this.description) || other.description == _this.description)&&const DeepCollectionEquality().equals(other.detail, _this.detail)&&(identical(other.startAt, _this.startAt) || other.startAt == _this.startAt)&&(identical(other.endAt, _this.endAt) || other.endAt == _this.endAt)&&const DeepCollectionEquality().equals(other.genres, _this.genres)&&(identical(other.channel, _this.channel) || other.channel == _this.channel)&&(identical(other.thumbnailUrl, _this.thumbnailUrl) || other.thumbnailUrl == _this.thumbnailUrl)&&(identical(other.recordedFile, _this.recordedFile) || other.recordedFile == _this.recordedFile));
}


@override
int get hashCode {
  final _this = this as VideoProgram;
  return Object.hash(runtimeType,_this.id,_this.title,_this.seriesTitle,_this.episodeNumber,_this.subtitle,_this.description,const DeepCollectionEquality().hash(_this.detail),_this.startAt,_this.endAt,const DeepCollectionEquality().hash(_this.genres),_this.channel,_this.thumbnailUrl,_this.recordedFile);
}

@override
String toString() {
  final _this = this as VideoProgram;
  return 'VideoProgram(id: ${_this.id}, title: ${_this.title}, seriesTitle: ${_this.seriesTitle}, episodeNumber: ${_this.episodeNumber}, subtitle: ${_this.subtitle}, description: ${_this.description}, detail: ${_this.detail}, startAt: ${_this.startAt}, endAt: ${_this.endAt}, genres: ${_this.genres}, channel: ${_this.channel}, thumbnailUrl: ${_this.thumbnailUrl}, recordedFile: ${_this.recordedFile})';
}


}

/// @nodoc
abstract mixin class $VideoProgramCopyWith<$Res>  {
  factory $VideoProgramCopyWith(VideoProgram value, $Res Function(VideoProgram) _then) = _$VideoProgramCopyWithImpl;
@useResult
$Res call({
 int id, String title, String? seriesTitle, String? episodeNumber, String? subtitle, String description, Map<String, String> detail, DateTime startAt, DateTime endAt, List<String> genres, Channel? channel, String thumbnailUrl, RecordedFileInfo? recordedFile
});


$ChannelCopyWith<$Res>? get channel;$RecordedFileInfoCopyWith<$Res>? get recordedFile;

}
/// @nodoc
class _$VideoProgramCopyWithImpl<$Res>
    implements $VideoProgramCopyWith<$Res> {
  _$VideoProgramCopyWithImpl(this._self, this._then);

  final VideoProgram _self;
  final $Res Function(VideoProgram) _then;

/// Create a copy of VideoProgram
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? seriesTitle = freezed,Object? episodeNumber = freezed,Object? subtitle = freezed,Object? description = null,Object? detail = null,Object? startAt = null,Object? endAt = null,Object? genres = null,Object? channel = freezed,Object? thumbnailUrl = null,Object? recordedFile = freezed,}) {
  return _then(VideoProgram(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,seriesTitle: freezed == seriesTitle ? _self.seriesTitle : seriesTitle // ignore: cast_nullable_to_non_nullable
as String?,episodeNumber: freezed == episodeNumber ? _self.episodeNumber : episodeNumber // ignore: cast_nullable_to_non_nullable
as String?,subtitle: freezed == subtitle ? _self.subtitle : subtitle // ignore: cast_nullable_to_non_nullable
as String?,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,detail: null == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as Map<String, String>,startAt: null == startAt ? _self.startAt : startAt // ignore: cast_nullable_to_non_nullable
as DateTime,endAt: null == endAt ? _self.endAt : endAt // ignore: cast_nullable_to_non_nullable
as DateTime,genres: null == genres ? _self.genres : genres // ignore: cast_nullable_to_non_nullable
as List<String>,channel: freezed == channel ? _self.channel : channel // ignore: cast_nullable_to_non_nullable
as Channel?,thumbnailUrl: null == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String,recordedFile: freezed == recordedFile ? _self.recordedFile : recordedFile // ignore: cast_nullable_to_non_nullable
as RecordedFileInfo?,
  ));
}
/// Create a copy of VideoProgram
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ChannelCopyWith<$Res>? get channel {
    if (_self.channel == null) {
    return null;
  }

  return $ChannelCopyWith<$Res>(_self.channel!, (value) {
    return _then(_self.copyWith(channel: value));
  });
}/// Create a copy of VideoProgram
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RecordedFileInfoCopyWith<$Res>? get recordedFile {
    if (_self.recordedFile == null) {
    return null;
  }

  return $RecordedFileInfoCopyWith<$Res>(_self.recordedFile!, (value) {
    return _then(_self.copyWith(recordedFile: value));
  });
}
}


/// Adds pattern-matching-related methods to [VideoProgram].
extension VideoProgramPatterns on VideoProgram {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VideoProgram value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VideoProgram() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VideoProgram value)  $default,){
final _that = this;
switch (_that) {
case _VideoProgram():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VideoProgram value)?  $default,){
final _that = this;
switch (_that) {
case _VideoProgram() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String title,  String? seriesTitle,  String? episodeNumber,  String? subtitle,  String description,  Map<String, String> detail,  DateTime startAt,  DateTime endAt,  List<String> genres,  Channel? channel,  String thumbnailUrl,  RecordedFileInfo? recordedFile)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VideoProgram() when $default != null:
return $default(_that.id,_that.title,_that.seriesTitle,_that.episodeNumber,_that.subtitle,_that.description,_that.detail,_that.startAt,_that.endAt,_that.genres,_that.channel,_that.thumbnailUrl,_that.recordedFile);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String title,  String? seriesTitle,  String? episodeNumber,  String? subtitle,  String description,  Map<String, String> detail,  DateTime startAt,  DateTime endAt,  List<String> genres,  Channel? channel,  String thumbnailUrl,  RecordedFileInfo? recordedFile)  $default,) {final _that = this;
switch (_that) {
case _VideoProgram():
return $default(_that.id,_that.title,_that.seriesTitle,_that.episodeNumber,_that.subtitle,_that.description,_that.detail,_that.startAt,_that.endAt,_that.genres,_that.channel,_that.thumbnailUrl,_that.recordedFile);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String title,  String? seriesTitle,  String? episodeNumber,  String? subtitle,  String description,  Map<String, String> detail,  DateTime startAt,  DateTime endAt,  List<String> genres,  Channel? channel,  String thumbnailUrl,  RecordedFileInfo? recordedFile)?  $default,) {final _that = this;
switch (_that) {
case _VideoProgram() when $default != null:
return $default(_that.id,_that.title,_that.seriesTitle,_that.episodeNumber,_that.subtitle,_that.description,_that.detail,_that.startAt,_that.endAt,_that.genres,_that.channel,_that.thumbnailUrl,_that.recordedFile);case _:
  return null;

}
}

}

/// @nodoc


class _VideoProgram implements VideoProgram {
  const _VideoProgram({required this.id, required this.title, this.seriesTitle, this.episodeNumber, this.subtitle, this.description = '',  Map<String, String> detail = const {}, required this.startAt, required this.endAt,  List<String> genres = const [], this.channel, required this.thumbnailUrl, this.recordedFile}): _detail = detail,_genres = genres;
  

/// 録画番組 ID (`/api/videos/{id}` の `video_id`)。
@override final  int id;
/// 番組タイトル。
@override final  String title;
/// シリーズ名。なければ null。
@override final  String? seriesTitle;
/// 話数表記 (例: `第85話`)。なければ null。
@override final  String? episodeNumber;
/// サブタイトル。なければ null。
@override final  String? subtitle;
/// 番組概要。
@override@JsonKey() final  String description;
/// 番組詳細 (例: `{'出演者': '...'}`)。なければ空。
 final  Map<String, String> _detail;
/// 番組詳細 (例: `{'出演者': '...'}`)。なければ空。
@override@JsonKey() Map<String, String> get detail {
  if (_detail is EqualUnmodifiableMapView) return _detail;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_detail);
}

/// 放送開始・終了日時。
@override final  DateTime startAt;
@override final  DateTime endAt;
/// 表示用のジャンル名一覧。なければ空。
 final  List<String> _genres;
/// 表示用のジャンル名一覧。なければ空。
@override@JsonKey() List<String> get genres {
  if (_genres is EqualUnmodifiableListView) return _genres;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_genres);
}

/// 放送チャンネル。チャンネル不明の録画では null。
@override final  Channel? channel;
/// サムネイル画像のURL。
@override final  String thumbnailUrl;
/// 録画ファイルの技術情報。取得できていない場合は null。
@override final  RecordedFileInfo? recordedFile;

/// Create a copy of VideoProgram
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VideoProgramCopyWith<_VideoProgram> get copyWith => __$VideoProgramCopyWithImpl<_VideoProgram>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VideoProgram&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.seriesTitle, seriesTitle) || other.seriesTitle == seriesTitle)&&(identical(other.episodeNumber, episodeNumber) || other.episodeNumber == episodeNumber)&&(identical(other.subtitle, subtitle) || other.subtitle == subtitle)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.detail, _detail)&&(identical(other.startAt, startAt) || other.startAt == startAt)&&(identical(other.endAt, endAt) || other.endAt == endAt)&&const DeepCollectionEquality().equals(other.genres, _genres)&&(identical(other.channel, channel) || other.channel == channel)&&(identical(other.thumbnailUrl, thumbnailUrl) || other.thumbnailUrl == thumbnailUrl)&&(identical(other.recordedFile, recordedFile) || other.recordedFile == recordedFile));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,title,seriesTitle,episodeNumber,subtitle,description,const DeepCollectionEquality().hash(_detail),startAt,endAt,const DeepCollectionEquality().hash(_genres),channel,thumbnailUrl,recordedFile);
}

@override
String toString() {
    return 'VideoProgram(id: $id, title: $title, seriesTitle: $seriesTitle, episodeNumber: $episodeNumber, subtitle: $subtitle, description: $description, detail: $detail, startAt: $startAt, endAt: $endAt, genres: $genres, channel: $channel, thumbnailUrl: $thumbnailUrl, recordedFile: $recordedFile)';
}


}

/// @nodoc
abstract mixin class _$VideoProgramCopyWith<$Res> implements $VideoProgramCopyWith<$Res> {
  factory _$VideoProgramCopyWith(_VideoProgram value, $Res Function(_VideoProgram) _then) = __$VideoProgramCopyWithImpl;
@override @useResult
$Res call({
 int id, String title, String? seriesTitle, String? episodeNumber, String? subtitle, String description, Map<String, String> detail, DateTime startAt, DateTime endAt, List<String> genres, Channel? channel, String thumbnailUrl, RecordedFileInfo? recordedFile
});


@override $ChannelCopyWith<$Res>? get channel;@override $RecordedFileInfoCopyWith<$Res>? get recordedFile;

}
/// @nodoc
class __$VideoProgramCopyWithImpl<$Res>
    implements _$VideoProgramCopyWith<$Res> {
  __$VideoProgramCopyWithImpl(this._self, this._then);

  final _VideoProgram _self;
  final $Res Function(_VideoProgram) _then;

/// Create a copy of VideoProgram
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? seriesTitle = freezed,Object? episodeNumber = freezed,Object? subtitle = freezed,Object? description = null,Object? detail = null,Object? startAt = null,Object? endAt = null,Object? genres = null,Object? channel = freezed,Object? thumbnailUrl = null,Object? recordedFile = freezed,}) {
  return _then(_VideoProgram(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,seriesTitle: freezed == seriesTitle ? _self.seriesTitle : seriesTitle // ignore: cast_nullable_to_non_nullable
as String?,episodeNumber: freezed == episodeNumber ? _self.episodeNumber : episodeNumber // ignore: cast_nullable_to_non_nullable
as String?,subtitle: freezed == subtitle ? _self.subtitle : subtitle // ignore: cast_nullable_to_non_nullable
as String?,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,detail: null == detail ? _self._detail : detail // ignore: cast_nullable_to_non_nullable
as Map<String, String>,startAt: null == startAt ? _self.startAt : startAt // ignore: cast_nullable_to_non_nullable
as DateTime,endAt: null == endAt ? _self.endAt : endAt // ignore: cast_nullable_to_non_nullable
as DateTime,genres: null == genres ? _self._genres : genres // ignore: cast_nullable_to_non_nullable
as List<String>,channel: freezed == channel ? _self.channel : channel // ignore: cast_nullable_to_non_nullable
as Channel?,thumbnailUrl: null == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String,recordedFile: freezed == recordedFile ? _self.recordedFile : recordedFile // ignore: cast_nullable_to_non_nullable
as RecordedFileInfo?,
  ));
}

/// Create a copy of VideoProgram
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ChannelCopyWith<$Res>? get channel {
    if (_self.channel == null) {
    return null;
  }

  return $ChannelCopyWith<$Res>(_self.channel!, (value) {
    return _then(_self.copyWith(channel: value));
  });
}/// Create a copy of VideoProgram
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RecordedFileInfoCopyWith<$Res>? get recordedFile {
    if (_self.recordedFile == null) {
    return null;
  }

  return $RecordedFileInfoCopyWith<$Res>(_self.recordedFile!, (value) {
    return _then(_self.copyWith(recordedFile: value));
  });
}
}

// dart format on
