package com.susurrus.flutter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        
        // Register our custom plugins
        flutterEngine.plugins.add(AudioProcessingPlugin())
        flutterEngine.plugins.add(WhisperCppPlugin())
    }
}