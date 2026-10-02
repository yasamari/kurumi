package io.github.yasamari.kurumi

import android.content.Context
import android.os.Build
import androidx.annotation.RequiresApi
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.ui.graphics.toArgb
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Jetpack Compose Material 3 の Dynamic Color を Flutter 側へ渡す MethodChannel。
 *
 * `dynamic_color` パッケージは Android の system color resource
 * (`android.R.color.system_accent1_*` など) を受け取って Flutter 側で tonal palette を
 * 組み立て直しているため、Compose と role ごとの mapping がずれる。
 * ここでは Compose 本体の `dynamicLightColorScheme()` / `dynamicDarkColorScheme()` を
 * そのまま呼び、その返り値を 1 役ずつ整数 (ARGB) で送る。
 *
 * こうすると API ごとの差もライブラリ側に閉じたまま扱える。
 *
 *  - API 34+ : `@android:color/system_*_light` / `system_*_dark` の role resource を直接読む。
 *  - API 31-33 : `system_accent1/2/3_*` と `system_neutral1/2_*` から TonalPalette を作り、
 *                surface 系を neutralVariant 基準の tone にマップする。Compose が
 *                `system_*` に存在しない tone (light の 98/96/94/92/87、dark の
 *                24/22/17/12/6/4 など) だけは neutralVariant40 の色相・彩度を保ったまま
 *                L* だけを変更して合成する (CAM16 + HctSolver)。
 *
 * なお Compose の Dynamic Color は error 系を動的にしない。
 * `lightColorScheme()` の既定値 (light `#BA1A1A` / dark `#FFB4AB`) のまま残る。
 */
object DynamicColorBridge {
    private const val CHANNEL = "io.github.yasamari.kurumi/dynamic_color"
    private const val METHOD_GET_DYNAMIC_COLOR_SCHEMES = "getDynamicColorSchemes"

    /** MethodChannel を登録する。 [MainActivity] から呼ぶ。 */
    fun install(messenger: BinaryMessenger, context: Context) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                METHOD_GET_DYNAMIC_COLOR_SCHEMES -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val (light, dark) = dynamicColorSchemes(context)
                        result.success(
                            mapOf(
                                "light" to light.toRoleMap(),
                                "dark" to dark.toRoleMap(),
                            )
                        )
                    } else {
                        // Android 12 未満には system color resource が無い。
                        result.success(null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    @RequiresApi(Build.VERSION_CODES.S)
    private fun dynamicColorSchemes(context: Context): Pair<ColorScheme, ColorScheme> =
        dynamicLightColorScheme(context) to dynamicDarkColorScheme(context)

    /**
     * Compose の [ColorScheme] を Flutter 側へ送れる形 (ロール名 -> ARGB) にする。
     *
     * キーの名前と並び順は Dart 側の `composeDynamicColorRoles` と対応している。
     * Compose 1.3.1 の [ColorScheme] に無い role (`primaryFixed` など) は送らない。
     * `background` / `onBackground` / `surfaceVariant` は Compose にはあるが Flutter 側では
     * 非推奨 (`surface` / `onSurface` に移行済み) なので、意図的に送らない。
     */
    private fun ColorScheme.toRoleMap(): Map<String, Int> = linkedMapOf(
        "primary" to primary.toArgb(),
        "onPrimary" to onPrimary.toArgb(),
        "primaryContainer" to primaryContainer.toArgb(),
        "onPrimaryContainer" to onPrimaryContainer.toArgb(),
        "inversePrimary" to inversePrimary.toArgb(),
        "secondary" to secondary.toArgb(),
        "onSecondary" to onSecondary.toArgb(),
        "secondaryContainer" to secondaryContainer.toArgb(),
        "onSecondaryContainer" to onSecondaryContainer.toArgb(),
        "tertiary" to tertiary.toArgb(),
        "onTertiary" to onTertiary.toArgb(),
        "tertiaryContainer" to tertiaryContainer.toArgb(),
        "onTertiaryContainer" to onTertiaryContainer.toArgb(),
        "error" to error.toArgb(),
        "onError" to onError.toArgb(),
        "errorContainer" to errorContainer.toArgb(),
        "onErrorContainer" to onErrorContainer.toArgb(),
        "surface" to surface.toArgb(),
        "onSurface" to onSurface.toArgb(),
        "onSurfaceVariant" to onSurfaceVariant.toArgb(),
        "inverseSurface" to inverseSurface.toArgb(),
        "inverseOnSurface" to inverseOnSurface.toArgb(),
        "outline" to outline.toArgb(),
        "outlineVariant" to outlineVariant.toArgb(),
        "scrim" to scrim.toArgb(),
        "surfaceBright" to surfaceBright.toArgb(),
        "surfaceDim" to surfaceDim.toArgb(),
        "surfaceContainerLowest" to surfaceContainerLowest.toArgb(),
        "surfaceContainerLow" to surfaceContainerLow.toArgb(),
        "surfaceContainer" to surfaceContainer.toArgb(),
        "surfaceContainerHigh" to surfaceContainerHigh.toArgb(),
        "surfaceContainerHighest" to surfaceContainerHighest.toArgb(),
        "surfaceTint" to surfaceTint.toArgb(),
    )
}