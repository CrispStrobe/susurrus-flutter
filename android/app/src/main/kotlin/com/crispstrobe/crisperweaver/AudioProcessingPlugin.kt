// android/app/src/main/kotlin/com/crisperweaver/flutter/AudioProcessingPlugin.kt (COMPLETE & FIXED)
package com.crispstrobe.crisperweaver

import android.content.Context
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.abs

class AudioProcessingPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.crispstrobe.crisperweaver.audio_processing")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        scope.cancel()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "convertToWav" -> {
                val filePath = call.argument<String>("filePath")
                val sampleRate = call.argument<Int>("sampleRate") ?: 16000
                val channels = call.argument<Int>("channels") ?: 1

                if (filePath == null) {
                    result.error("INVALID_ARGUMENTS", "Missing file path", null)
                    return
                }

                scope.launch {
                    try {
                        val audioData = decodeAudioFile(filePath, sampleRate, channels)
                        result.success(audioData)
                    } catch (e: Exception) {
                        result.error("CONVERSION_ERROR", "Failed to convert audio: ${e.message}", e.stackTraceToString())
                    }
                }
            }
            "normalizeAudio" -> {
                val audioData = call.argument<ByteArray>("audioData")
                if (audioData == null) {
                    result.error("INVALID_ARGUMENTS", "Missing audio data", null)
                    return
                }
                scope.launch {
                     try {
                        val normalized = normalizePcm(bytesToFloatArray(audioData))
                        result.success(floatArrayToBytes(normalized))
                    } catch (e: Exception) {
                        result.error("NORMALIZE_ERROR", "Failed to normalize audio: ${e.message}", null)
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    private suspend fun decodeAudioFile(filePath: String, targetSampleRate: Int, targetChannels: Int): Map<String, Any> {
        return withContext(Dispatchers.IO) {
            val file = File(filePath)
            if (!file.exists()) {
                throw IllegalArgumentException("File does not exist: $filePath")
            }

            val extractor = MediaExtractor()
            var codec: MediaCodec? = null
            
            try {
                extractor.setDataSource(filePath)
                val (audioTrackIndex, format) = findAudioTrack(extractor)

                if (audioTrackIndex == -1) {
                    throw IllegalArgumentException("No audio track found in file")
                }
                
                extractor.selectTrack(audioTrackIndex)

                val mime = format.getString(MediaFormat.KEY_MIME)!!
                codec = MediaCodec.createDecoderByType(mime)
                codec.configure(format, null, null, 0)
                codec.start()

                val rawPcmData = extractRawPcm(extractor, codec)
                
                // Convert raw 16-bit PCM bytes to float samples [-1.0, 1.0]
                var samples = pcmBytesToFloat(rawPcmData)

                // Resample if necessary
                val sourceSampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                if (sourceSampleRate != targetSampleRate) {
                    samples = resample(samples, sourceSampleRate, targetSampleRate)
                }

                // Mix down to mono if necessary
                val sourceChannels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                if (sourceChannels > 1 && targetChannels == 1) {
                    samples = mixToMono(samples, sourceChannels)
                }

                mapOf(
                    "samples" to samples.toList(),
                    "sampleRate" to targetSampleRate,
                    "channels" to targetChannels
                )
            } finally {
                codec?.stop()
                codec?.release()
                extractor.release()
            }
        }
    }

    private fun findAudioTrack(extractor: MediaExtractor): Pair<Int, MediaFormat> {
        for (i in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(i)
            val mime = format.getString(MediaFormat.KEY_MIME)
            if (mime?.startsWith("audio/") == true) {
                return Pair(i, format)
            }
        }
        return Pair(-1, MediaFormat())
    }

    private fun extractRawPcm(extractor: MediaExtractor, codec: MediaCodec): ByteArray {
        val bufferInfo = MediaCodec.BufferInfo()
        val outputStream = ByteArrayOutputStream()

        while (true) {
            val inputBufferIndex = codec.dequeueInputBuffer(10000L)
            if (inputBufferIndex >= 0) {
                val inputBuffer = codec.getInputBuffer(inputBufferIndex)!!
                val sampleSize = extractor.readSampleData(inputBuffer, 0)
                if (sampleSize < 0) {
                    codec.queueInputBuffer(inputBufferIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                } else {
                    codec.queueInputBuffer(inputBufferIndex, 0, sampleSize, extractor.sampleTime, 0)
                    extractor.advance()
                }
            }

            var outputBufferIndex = codec.dequeueOutputBuffer(bufferInfo, 10000L)
            while (outputBufferIndex >= 0) {
                val outputBuffer = codec.getOutputBuffer(outputBufferIndex)!!
                val chunk = ByteArray(bufferInfo.size)
                outputBuffer.get(chunk)
                outputStream.write(chunk)
                codec.releaseOutputBuffer(outputBufferIndex, false)
                outputBufferIndex = codec.dequeueOutputBuffer(bufferInfo, 0)
            }
            
            if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                break
            }
        }
        return outputStream.toByteArray()
    }

    private fun pcmBytesToFloat(pcmData: ByteArray): FloatArray {
        // Assuming 16-bit PCM (Short)
        val shortBuffer = ByteBuffer.wrap(pcmData).order(ByteOrder.LITTLE_ENDIAN).asShortBuffer()
        val floatArray = FloatArray(shortBuffer.remaining())
        for (i in 0 until floatArray.size) {
            floatArray[i] = shortBuffer.get(i).toFloat() / 32768.0f
        }
        return floatArray
    }
    
    private fun resample(input: FloatArray, fromRate: Int, toRate: Int): FloatArray {
        val ratio = fromRate.toDouble() / toRate.toDouble()
        val outputLength = (input.size / ratio).toInt()
        val output = FloatArray(outputLength)
        for (i in 0 until outputLength) {
            val srcIndex = i * ratio
            val index0 = srcIndex.toInt()
            val index1 = minOf(index0 + 1, input.size - 1)
            val fraction = (srcIndex - index0).toFloat()
            output[i] = input[index0] * (1.0f - fraction) + input[index1] * fraction // Linear interpolation
        }
        return output
    }

    private fun mixToMono(input: FloatArray, channels: Int): FloatArray {
        val outputLength = input.size / channels
        val output = FloatArray(outputLength)
        for (i in 0 until outputLength) {
            var sum = 0.0f
            for (c in 0 until channels) {
                sum += input[i * channels + c]
            }
            output[i] = sum / channels
        }
        return output
    }

    private fun normalizePcm(samples: FloatArray): FloatArray {
        val maxAbsValue = samples.maxOfOrNull { abs(it) } ?: 1.0f
        if (maxAbsValue > 0) {
            for (i in samples.indices) {
                samples[i] /= maxAbsValue
            }
        }
        return samples
    }
    
    // Data conversion helpers
    private fun bytesToFloatArray(bytes: ByteArray): FloatArray {
        val buffer = ByteBuffer.wrap(bytes).order(ByteOrder.nativeOrder())
        val floatBuffer = buffer.asFloatBuffer()
        val floats = FloatArray(floatBuffer.remaining())
        floatBuffer.get(floats)
        return floats
    }

    private fun floatArrayToBytes(floats: FloatArray): ByteArray {
        val buffer = ByteBuffer.allocate(floats.size * 4).order(ByteOrder.nativeOrder())
        buffer.asFloatBuffer().put(floats)
        return buffer.array()
    }
}