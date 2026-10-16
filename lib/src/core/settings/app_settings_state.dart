import '../../domain/entities/backend_type.dart';
import '../network/network_type.dart';

/// 永続化されるアプリ設定のスナップショット。
class AppSettingsState {
  const AppSettingsState({
    this.backendType = BackendType.mirakurun,
    this.mirakurunBaseUrl = '',
    this.konomiBaseUrl = '',
    this.danmakuEnabled = defaultDanmakuEnabled,
    this.danmakuFontSize = defaultDanmakuFontSize,
    this.danmakuOpacity = defaultDanmakuOpacity,
    this.danmakuSpeed = defaultDanmakuSpeed,
    this.subtitlesEnabled = defaultSubtitlesEnabled,
    this.cmAutoSkipEnabled = defaultCmAutoSkipEnabled,
    this.mirakurunEpgRefreshIntervalHours =
        defaultMirakurunEpgRefreshIntervalHours,
    this.konomiLiveQualityWifi = defaultKonomiLiveQualityWifi,
    this.konomiLiveQualityMobile = defaultKonomiLiveQualityMobile,
    this.konomiVideoQualityWifi = defaultKonomiVideoQualityWifi,
    this.konomiVideoQualityMobile = defaultKonomiVideoQualityMobile,
  });

  /// 弾幕は既定で表示する。
  static const bool defaultDanmakuEnabled = true;

  /// 弾幕の文字サイズ (論理ピクセル)。エンジン既定の16では実況の高速コメント
  /// が読めない。
  static const double defaultDanmakuFontSize = 24;

  /// 弾幕の不透明度。1.0 が不透明。
  static const double defaultDanmakuOpacity = 1.0;

  /// 弾幕の速度倍率。1.0 が等速で、大きいほど速い (表示時間を割る)。
  static const double defaultDanmakuSpeed = 1.0;

  /// 字幕は既定で非表示にする。地上波の字幕はほぼ常に流しており、見るつもり
  /// で視聴しても意図せず描画されるのを避ける。字幕が見たい人は画面上の字幕
  /// ボタンで各自オンにする。
  static const bool defaultSubtitlesEnabled = false;

  /// CM自動スキップは既定で無効にする。意図せず本編を飛ばすのを避ける。
  static const bool defaultCmAutoSkipEnabled = false;

  /// Mirakurun のEPGキャッシュ更新間隔の既定値 (時間)。
  static const int defaultMirakurunEpgRefreshIntervalHours = 6;

  /// Mirakurun のEPGキャッシュ更新間隔の最小値 (時間)。
  static const int minMirakurunEpgRefreshIntervalHours = 1;

  /// Mirakurun のEPGキャッシュ更新間隔の最大値 (時間)。
  static const int maxMirakurunEpgRefreshIntervalHours = 24;

  /// KonomiTV のテレビ視聴で Wi-Fi 接続時に使う既定画質。生放送TS。
  static const String defaultKonomiLiveQualityWifi = 'original';

  /// KonomiTV のテレビ視聴でモバイル回線時に使う既定画質。通信量を抑える。
  static const String defaultKonomiLiveQualityMobile = '480p';

  /// KonomiTV のビデオ再生で Wi-Fi 接続時に使う既定画質。
  /// `original` はダウンロード再生。
  static const String defaultKonomiVideoQualityWifi = 'original';

  /// KonomiTV のビデオ再生でモバイル回線時に使う既定画質。
  static const String defaultKonomiVideoQualityMobile = '480p';

  final BackendType backendType;
  final String mirakurunBaseUrl;
  final String konomiBaseUrl;

  /// 弾幕を映像に重ねるかどうか。実況チャンネルが対応していない場合は
  /// 描画されない (対応かどうかは `TvRepository` の能力で決まる)。
  final bool danmakuEnabled;

  /// 弾幕の文字サイズ (論理ピクセル)。画面全体で1つだけなので、`mail` の
  /// サイズコマンドは表現できない。
  final double danmakuFontSize;

  /// 弾幕の不透明度。0.2〜1.0。
  final double danmakuOpacity;

  /// 弾幕の速度倍率。0.5〜2.0。
  final double danmakuSpeed;

  /// 字幕を表示するかどうか。false のときは mpv に `sid=no` を適用する。
  final bool subtitlesEnabled;

  /// CM区間を自動で飛ばすかどうか。録画再生だけで使う。既定は無効。
  final bool cmAutoSkipEnabled;

  /// Mirakurun のEPGキャッシュ更新間隔 (時間)。1〜24。
  /// 全量取得型の Mirakurun にのみ使う。
  final int mirakurunEpgRefreshIntervalHours;

  /// KonomiTV のテレビ視聴で Wi-Fi 接続時に使う画質。
  final String konomiLiveQualityWifi;

  /// KonomiTV のテレビ視聴でモバイル回線時に使う画質。
  final String konomiLiveQualityMobile;

  /// KonomiTV のビデオ再生で Wi-Fi 接続時に使う画質。
  final String konomiVideoQualityWifi;

  /// KonomiTV のビデオ再生でモバイル回線時に使う画質。
  final String konomiVideoQualityMobile;

  /// 現在選択中バックエンドのベースURL。
  String get activeBaseUrl => switch (backendType) {
    BackendType.mirakurun => mirakurunBaseUrl,
    BackendType.konomiTv => konomiBaseUrl,
  };

  /// テレビ画質の回線別設定を返す。
  String konomiLiveQualityFor(NetworkType networkType) =>
      networkType == NetworkType.mobile
      ? konomiLiveQualityMobile
      : konomiLiveQualityWifi;

  /// ビデオ画質の回線別設定を返す。
  String konomiVideoQualityFor(NetworkType networkType) =>
      networkType == NetworkType.mobile
      ? konomiVideoQualityMobile
      : konomiVideoQualityWifi;

  /// テレビ画面を表示できる状態かどうか。
  bool get isConfigured => activeBaseUrl.isNotEmpty;

  AppSettingsState copyWith({
    BackendType? backendType,
    String? mirakurunBaseUrl,
    String? konomiBaseUrl,
    bool? danmakuEnabled,
    double? danmakuFontSize,
    double? danmakuOpacity,
    double? danmakuSpeed,
    bool? subtitlesEnabled,
    bool? cmAutoSkipEnabled,
    int? mirakurunEpgRefreshIntervalHours,
    String? konomiLiveQualityWifi,
    String? konomiLiveQualityMobile,
    String? konomiVideoQualityWifi,
    String? konomiVideoQualityMobile,
  }) {
    return AppSettingsState(
      backendType: backendType ?? this.backendType,
      mirakurunBaseUrl: mirakurunBaseUrl ?? this.mirakurunBaseUrl,
      konomiBaseUrl: konomiBaseUrl ?? this.konomiBaseUrl,
      danmakuEnabled: danmakuEnabled ?? this.danmakuEnabled,
      danmakuFontSize: danmakuFontSize ?? this.danmakuFontSize,
      danmakuOpacity: danmakuOpacity ?? this.danmakuOpacity,
      danmakuSpeed: danmakuSpeed ?? this.danmakuSpeed,
      subtitlesEnabled: subtitlesEnabled ?? this.subtitlesEnabled,
      cmAutoSkipEnabled: cmAutoSkipEnabled ?? this.cmAutoSkipEnabled,
      mirakurunEpgRefreshIntervalHours:
          mirakurunEpgRefreshIntervalHours ??
          this.mirakurunEpgRefreshIntervalHours,
      konomiLiveQualityWifi:
          konomiLiveQualityWifi ?? this.konomiLiveQualityWifi,
      konomiLiveQualityMobile:
          konomiLiveQualityMobile ?? this.konomiLiveQualityMobile,
      konomiVideoQualityWifi:
          konomiVideoQualityWifi ?? this.konomiVideoQualityWifi,
      konomiVideoQualityMobile:
          konomiVideoQualityMobile ?? this.konomiVideoQualityMobile,
    );
  }
}

/// Mirakurun のEPGキャッシュ更新間隔を1〜24時間に丸める純粋関数。
int clampMirakurunEpgRefreshIntervalHours(int hours) {
  return hours.clamp(
    AppSettingsState.minMirakurunEpgRefreshIntervalHours,
    AppSettingsState.maxMirakurunEpgRefreshIntervalHours,
  );
}
