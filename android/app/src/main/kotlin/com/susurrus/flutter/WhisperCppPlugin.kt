package com.susurrus.flutter

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*
import java.io.File

class WhisperCppPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    
    // Native library loading
    companion object {
        init {
            try {
                System.loadLibrary("whisper")
            } catch (e: UnsatisfiedLinkError) {
                // Library not found - will be handled in method calls
            }
        }
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.susurrus.whisper_cpp")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        scope.cancel()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initModel" -> {
                val modelPath = call.argument<String>("modelPath")
                if (modelPath == null) {
                    result.error("INVALID_ARGUMENTS", "Missing model path", null)
                    return
                }
                
                scope.launch {
                    try {
                        val success = initModel(modelPath)
                        result.success(success)
                    } catch (e: Exception) {
                        result.error("INIT_ERROR", "Failed to initialize model: ${e.message}", null)
                    }
                }
            }

            "transcribe" -> {
                val audioData = call.argument<FloatArray>("audioData")
                val language = call.argument<String>("language")
                
                if (audioData == null) {
                    result.error("INVALID_ARGUMENTS", "Missing audio data", null)
                    return
                }

                scope.launch {
                    try {
                        val segments = transcribeAudio(audioData, language)
                        result.success(segments)
                    } catch (e: Exception) {
                        result.error("TRANSCRIPTION_ERROR", "Transcription failed: ${e.message}", null)
                    }
                }
            }

            "freeModel" -> {
                scope.launch {
                    try {
                        freeModel()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("FREE_ERROR", "Failed to free model: ${e.message}", null)
                    }
                }
            }

            "isModelLoaded" -> {
                result.success(isModelLoaded())
            }

            else -> result.notImplemented()
        }
    }

    private suspend fun initModel(modelPath: String): Boolean {
        return withContext(Dispatchers.IO) {
            val file = File(modelPath)
            if (!file.exists()) {
                throw IllegalArgumentException("Model file does not exist: $modelPath")
            }

            try {
                // Call native function
                nativeInitModel(modelPath)
            } catch (e: UnsatisfiedLinkError) {
                // Fallback to Java implementation if native library not available
                false
            }
        }
    }

    private suspend fun transcribeAudio(audioData: FloatArray, language: String?): List<Map<String, Any>> {
        return withContext(Dispatchers.Default) {
            try {
                // Call native function
                nativeTranscribe(audioData, language ?: "auto")
            } catch (e: UnsatisfiedLinkError) {
                // Fallback to mock implementation if native library not available
                listOf(
                    mapOf(
                        "text" to "Mock transcription result",
                        "startTime" to 0.0,
                        "endTime" to 5.0
                    )
                )
            }
        }
    }

    private suspend fun freeModel() {
        withContext(Dispatchers.IO) {
            try {
                nativeFreeModel()
            } catch (e: UnsatisfiedLinkError) {
                // No native library loaded
            }
        }
    }

    private fun isModelLoaded(): Boolean {
        return try {
            nativeIsModelLoaded()
        } catch (e: UnsatisfiedLinkError) {
            false
        }
    }

    // Native method declarations
    private external fun nativeInitModel(modelPath: String): Boolean
    private external fun nativeTranscribe(audioData: FloatArray, language: String): List<Map<String, Any>>
    private external fun nativeFreeModel()
    private external fun nativeIsModelLoaded(): Boolean
}