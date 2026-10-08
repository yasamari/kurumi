// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timetable_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 番組表1日分。未設定時は [BackendUnconfiguredException] を送出する。
///
/// `[dayStartMs, dayStartMs + 24時間)` の期間を返す。KonomiTV は番組表API
/// から都度取得し、Mirakurun はEPGキャッシュから組み立てる (通信なし)。
/// 次の番組境界で自分を作り直す (未来の境界が無い過去日には張らない)。
///
/// **設定の有無と接続先だけを選ぶ。** [appSettingsProvider.future] をそのまま
/// 購読すると、接続先と無関係な設定 (弾幕・字幕の表示設定など) を変えるたびに
/// future のインスタンスが変わって取り直しが始まる。

@ProviderFor(timetableData)
final timetableDataProvider = TimetableDataFamily._();

/// 番組表1日分。未設定時は [BackendUnconfiguredException] を送出する。
///
/// `[dayStartMs, dayStartMs + 24時間)` の期間を返す。KonomiTV は番組表API
/// から都度取得し、Mirakurun はEPGキャッシュから組み立てる (通信なし)。
/// 次の番組境界で自分を作り直す (未来の境界が無い過去日には張らない)。
///
/// **設定の有無と接続先だけを選ぶ。** [appSettingsProvider.future] をそのまま
/// 購読すると、接続先と無関係な設定 (弾幕・字幕の表示設定など) を変えるたびに
/// future のインスタンスが変わって取り直しが始まる。

final class TimetableDataProvider
    extends
        $FunctionalProvider<
          AsyncValue<TimetableData>,
          TimetableData,
          FutureOr<TimetableData>
        >
    with $FutureModifier<TimetableData>, $FutureProvider<TimetableData> {
  /// 番組表1日分。未設定時は [BackendUnconfiguredException] を送出する。
  ///
  /// `[dayStartMs, dayStartMs + 24時間)` の期間を返す。KonomiTV は番組表API
  /// から都度取得し、Mirakurun はEPGキャッシュから組み立てる (通信なし)。
  /// 次の番組境界で自分を作り直す (未来の境界が無い過去日には張らない)。
  ///
  /// **設定の有無と接続先だけを選ぶ。** [appSettingsProvider.future] をそのまま
  /// 購読すると、接続先と無関係な設定 (弾幕・字幕の表示設定など) を変えるたびに
  /// future のインスタンスが変わって取り直しが始まる。
  TimetableDataProvider._({
    required TimetableDataFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'timetableDataProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$timetableDataHash();

  @override
  String toString() {
    return r'timetableDataProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<TimetableData> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TimetableData> create(Ref ref) {
    final argument = this.argument as int;
    return timetableData(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TimetableDataProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$timetableDataHash() => r'b06b4bc3d3b0784b9f80b811ea24f191f5e39723';

/// 番組表1日分。未設定時は [BackendUnconfiguredException] を送出する。
///
/// `[dayStartMs, dayStartMs + 24時間)` の期間を返す。KonomiTV は番組表API
/// から都度取得し、Mirakurun はEPGキャッシュから組み立てる (通信なし)。
/// 次の番組境界で自分を作り直す (未来の境界が無い過去日には張らない)。
///
/// **設定の有無と接続先だけを選ぶ。** [appSettingsProvider.future] をそのまま
/// 購読すると、接続先と無関係な設定 (弾幕・字幕の表示設定など) を変えるたびに
/// future のインスタンスが変わって取り直しが始まる。

final class TimetableDataFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<TimetableData>, int> {
  TimetableDataFamily._()
    : super(
        retry: null,
        name: r'timetableDataProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 番組表1日分。未設定時は [BackendUnconfiguredException] を送出する。
  ///
  /// `[dayStartMs, dayStartMs + 24時間)` の期間を返す。KonomiTV は番組表API
  /// から都度取得し、Mirakurun はEPGキャッシュから組み立てる (通信なし)。
  /// 次の番組境界で自分を作り直す (未来の境界が無い過去日には張らない)。
  ///
  /// **設定の有無と接続先だけを選ぶ。** [appSettingsProvider.future] をそのまま
  /// 購読すると、接続先と無関係な設定 (弾幕・字幕の表示設定など) を変えるたびに
  /// future のインスタンスが変わって取り直しが始まる。

  TimetableDataProvider call(int dayStartMs) =>
      TimetableDataProvider._(argument: dayStartMs, from: this);

  @override
  String toString() => r'timetableDataProvider';
}
