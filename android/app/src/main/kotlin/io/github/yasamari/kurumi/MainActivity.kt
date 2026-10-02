package io.github.yasamari.kurumi

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        DynamicColorBridge.install(flutterEngine.dartExecutor.binaryMessenger, this)
    }
}