# Keep whisper native methods
-keep class com.susurrus.flutter.WhisperCppPlugin { *; }
-keepclassmembers class com.susurrus.flutter.WhisperCppPlugin {
    native <methods>;
}