package io.github.yasamari.kurumi

import cl.puntito.simple_pip_mode.PipCallbackHelperActivityWrapper
import io.flutter.embedding.engine.FlutterEngine

/**
 * PiP (ピクチャインピクチャ) のコールバックを受けるため、
 * simple_pip_mode のラッパー Activity を継承する。
 *
 * `configureFlutterEngine` はラッパーの実装 (PiP コールバックヘルパーの登録) を
 * super 経由で呼び、その後に Dynamic Color のブリッジを据付ける。
 */
class MainActivity : PipCallbackHelperActivityWrapper() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        DynamicColorBridge.install(flutterEngine.dartExecutor.binaryMessenger, this)
    }
}
