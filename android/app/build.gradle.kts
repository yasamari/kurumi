plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "io.github.yasamari.kurumi"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "io.github.yasamari.kurumi"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // stream tap (mpv stream_cb の受け側) の ABI 別ビルド。
        // C ソースは native/stream_tap/ にあり Linux と共有。
        externalNativeBuild {
            cmake {
                // 16KB ページ対応端末向け。NDK r27 以降の既定だが明示する。
                arguments("-DANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON")
                // 小規模な C ファイルのため -O2 で十分。LTO 等はしない。
                cFlags("-O2", "-Wall", "-Wextra")
            }
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            // nix store の SDK 同梱版に固定。未指定だと AGP が別版を
            // 取得しようとして read-only な SDK への書き込みで落ちる。
            version = "4.1.2"
        }
    }

    buildTypes {
        release {
            // 当面は debug 鍵署名のまま GitHub Releases で配布する。
            // 正式鍵に切り替える場合は、更新時に同一鍵での継続が必須。
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Dynamic Color を Jetpack Compose Material 3 と完全に一致させるため、
    // Compose 本体の `dynamicLightColorScheme()` / `dynamicDarkColorScheme()` を
    // MainActivity から直接呼ぶ (DynamicColorBridge.kt)。
    //
    // dynamic_color パッケージ経由では Android の system color resource を
    // Flutter 側で tone 変換し直しているため、role ごとの mapping が Compose と
    // ずれる (特に surfaceContainer* 系)。
    //
    // Compose の UI 部品は一切参照しないので、R8 が unreachable なコードを落とし、
    // release APK への寄与は約 +110KB にとどまる。
    //
    // compileSdk 36 で動く最新の安定版は 1.3.1。1.5.0-alpha は compileSdk 37 を要求する。
    // 1.3.1 の ColorScheme には primaryFixed などの fixed role がないため、
    // それらは Flutter 側の既定値に委ねている (本アプリでは未使用)。
    implementation("androidx.compose.material3:material3:1.3.1")
}
