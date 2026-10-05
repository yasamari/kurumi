package io.github.yasamari.kurumi

import android.content.Context
import cl.puntito.simple_pip_mode.PipCallbackHelperActivityWrapper
import com.ryanheise.audioservice.AudioServicePlugin
import io.flutter.embedding.engine.FlutterEngine

/**
 * PiP (ピクチャインピクチャ) のコールバックを受けるため、
 * simple_pip_mode のラッパー Activity を継承する。
 *
 * `configureFlutterEngine` はラッパーの実装 (PiP コールバックヘルパーの登録) を
 * super 経由で呼び、その後に Dynamic Color のブリッジを据付ける。
 *
 * audio_service とは `provideFlutterEngine` で共有 FlutterEngine を提供して
 * 連携する (カスタム Activity の手順。`AudioServiceActivity` への継承替えは
 * PiP ラッパーと両立しないため行わない)。
 */
class MainActivity : PipCallbackHelperActivityWrapper() {
    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        return AudioServicePlugin.getFlutterEngine(context)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        DynamicColorBridge.install(flutterEngine.dartExecutor.binaryMessenger, this)
    }
}
