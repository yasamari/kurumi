// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backend_settings_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 接続テストの実行状態。

@ProviderFor(ConnectionTest)
final connectionTestProvider = ConnectionTestProvider._();

/// 接続テストの実行状態。
final class ConnectionTestProvider
    extends $AsyncNotifierProvider<ConnectionTest, void> {
  /// 接続テストの実行状態。
  ConnectionTestProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectionTestProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectionTestHash();

  @$internal
  @override
  ConnectionTest create() => ConnectionTest();
}

String _$connectionTestHash() => r'486a19a9c04396ae1ed70bbd86912a2e4f5ffaf4';

/// 接続テストの実行状態。

abstract class _$ConnectionTest extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
