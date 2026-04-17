# Keep whisper native methods
-keep class com.crispstrobe.crisperweaver.WhisperCppPlugin { *; }
-keepclassmembers class com.crispstrobe.crisperweaver.WhisperCppPlugin {
    native <methods>;
}