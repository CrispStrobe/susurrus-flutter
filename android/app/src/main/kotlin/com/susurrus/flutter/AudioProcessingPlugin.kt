package com.susurrus.flutter

import android.content.Context
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.*

class AudioProcessingPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.susurrus.audio_processing")
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
                        val audioData = convertToWav(filePath, sampleRate, channels)
                        result.success(audioData)
                    } catch (e: Exception) {
                        result.error("CONVERSION_ERROR", "Failed to convert audio: ${e.message}", null)
                    }
                }
            }

            "extractFeatures" -> {
                val audioData = call.argument<ByteArray>("audioData")

                if (audioData == null) {
                    result.error("INVALID_ARGUMENTS", "Missing audio data", null)
                    return
                }

                scope.launch {
                    try {
                        val features = extractFeatures(audioData)
                        result.success(features)
                    } catch (e: Exception) {
                        result.error("FEATURE_ERROR", "Failed to extract features: ${e.message}", null)
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
                        val normalized = normalizeAudio(audioData)
                        result.success(normalized)
                    } catch (e: Exception) {
                        result.error("NORMALIZE_ERROR", "Failed to normalize audio: ${e.message}", null)
                    }
                }
            }

            else -> result.notImplemented()
        }
    }

    private suspend fun convertToWav(filePath: String, targetSampleRate: Int, targetChannels: Int): Map<String, Any> {
        return withContext(Dispatchers.IO) {
            val file = File(filePath)
            if (!file.exists()) {
                throw IllegalArgumentException("File does not exist: $filePath")
            }

            // Use MediaExtractor for audio processing
            val extractor = MediaExtractor()
            extractor.setDataSource(filePath)

            var audioTrackIndex = -1
            var format: MediaFormat? = null

            // Find audio track
            for (i in 0 until extractor.trackCount) {
                val trackFormat = extractor.getTrackFormat(i)
                val mime = trackFormat.getString(MediaFormat.KEY_MIME)
                if (mime?.startsWith("audio/") == true) {
                    audioTrackIndex = i
                    format = trackFormat
                    break
                }
            }

            if (audioTrackIndex == -1 || format == null) {
                throw IllegalArgumentException("No audio track found in file")
            }

            extractor.selectTrack(audioTrackIndex)

            // Extract basic audio info
            val sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            val channelCount = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)

            // For simplicity, read raw audio data and convert
            val samples = extractRawAudioSamples(filePath)
            
            // Resample if needed
            val resampledSamples = if (sampleRate != targetSampleRate) {
                resampleAudio(samples, sampleRate, targetSampleRate)
            } else {
                samples
            }

            // Mix down to mono if needed
            val finalSamples = if (channelCount > 1 && targetChannels == 1) {
                mixDownToMono(resampledSamples, channelCount)
            } else {
                resampledSamples
            }

            extractor.release()

            mapOf(
                "samples" to finalSamples.toList(),
                "sampleRate" to targetSampleRate,
                "channels" to targetChannels
            )
        }
    }

    private fun extractRawAudioSamples(filePath: String): FloatArray {
        // Simplified audio extraction - in production you'd want more robust handling
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(filePath)
            
            // This is a simplified approach - in reality you'd need more sophisticated
            // audio decoding for different formats
            val file = File(filePath)
            if (file.extension.lowercase() == "wav") {
                return extractWavSamples(filePath)
            } else {
                // For other formats, you'd need a proper audio decoder
                // For this example, return empty array
                return FloatArray(0)
            }
        } finally {
            retriever.release()
        }
    }

    private fun extractWavSamples(filePath: String): FloatArray {
        val inputStream = FileInputStream(filePath)
        val samples = mutableListOf<Float>()

        try {
            // Skip WAV header (44 bytes)
            inputStream.skip(44)

            val buffer = ByteArray(4096)
            var bytesRead: Int

            while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                val byteBuffer = ByteBuffer.wrap(buffer, 0, bytesRead)
                byteBuffer.order(ByteOrder.LITTLE_ENDIAN)

                while (byteBuffer.hasRemaining()) {
                    val sample = byteBuffer.short.toFloat() / 32768.0f
                    samples.add(sample)
                }
            }
        } finally {
            inputStream.close()
        }

        return samples.toFloatArray()
    }

    private fun resampleAudio(input: FloatArray, fromRate: Int, toRate: Int): FloatArray {
        if (fromRate == toRate) return input

        val ratio = fromRate.toDouble() / toRate.toDouble()
        val outputLength = (input.size / ratio).toInt()
        val output = FloatArray(outputLength)

        for (i in output.indices) {
            val srcIndex = (i * ratio).toInt()
            if (srcIndex < input.size) {
                output[i] = input[srcIndex]
            }
        }

        return output
    }

    private fun mixDownToMono(input: FloatArray, channels: Int): FloatArray {
        if (channels == 1) return input

        val outputLength = input.size / channels
        val output = FloatArray(outputLength)

        for (i in output.indices) {
            var sum = 0.0f
            for (c in 0 until channels) {
                val index = i * channels + c
                if (index < input.size) {
                    sum += input[index]
                }
            }
            output[i] = sum / channels
        }

        return output
    }

    private suspend fun extractFeatures(audioData: ByteArray): Map<String, Any> {
        return withContext(Dispatchers.Default) {
            val samples = bytesToFloatArray(audioData)

            // Extract MFCC features
            val mfccFeatures = extractMFCC(samples)

            // Extract spectral features
            val spectralFeatures = extractSpectralFeatures(samples)

            mapOf(
                "mfcc" to mfccFeatures,
                "spectral" to spectralFeatures
            )
        }
    }

    private suspend fun normalizeAudio(audioData: ByteArray): ByteArray {
        return withContext(Dispatchers.Default) {
            val samples = bytesToFloatArray(audioData)

            // Find maximum absolute value
            val maxValue = samples.maxOfOrNull { abs(it) } ?: 1.0f

            // Normalize to [-1, 1] range
            val normalized = if (maxValue > 0) {
                samples.map { it / maxValue }.toFloatArray()
            } else {
                samples
            }

            floatArrayToBytes(normalized)
        }
    }

    private fun extractMFCC(samples: FloatArray): List<List<Float>> {
        val frameSize = 512
        val hopSize = 256
        val numMFCC = 13
        val mfccFrames = mutableListOf<List<Float>>()

        // Process audio in frames
        for (startIndex in 0 until samples.size - frameSize step hopSize) {
            val endIndex = minOf(startIndex + frameSize, samples.size)
            val frame = samples.sliceArray(startIndex until endIndex)

            // Apply pre-emphasis
            val preEmphasized = applyPreEmphasis(frame)

            // Apply window
            val windowed = applyHammingWindow(preEmphasized)

            // Compute FFT
            val fftResult = computeFFT(windowed)

            // Apply mel filter bank
            val melFiltered = applyMelFilterBank(fftResult)

            // Apply DCT
            val mfcc = computeDCT(melFiltered, numMFCC)

            mfccFrames.add(mfcc.toList())
        }

        return mfccFrames
    }

    private fun extractSpectralFeatures(samples: FloatArray): Map<String, Float> {
        val fft = computeFFT(samples)

        return mapOf(
            "spectralCentroid" to computeSpectralCentroid(fft),
            "spectralRolloff" to computeSpectralRolloff(fft),
            "zeroCrossingRate" to computeZeroCrossingRate(samples)
        )
    }

    // DSP Helper Functions
    private fun applyPreEmphasis(samples: FloatArray, alpha: Float = 0.97f): FloatArray {
        if (samples.size <= 1) return samples

        val result = FloatArray(samples.size)
        result[0] = samples[0]

        for (i in 1 until samples.size) {
            result[i] = samples[i] - alpha * samples[i - 1]
        }

        return result
    }

    private fun applyHammingWindow(samples: FloatArray): FloatArray {
        val n = samples.size
        return FloatArray(n) { i ->
            val hamming = 0.54f - 0.46f * cos(2.0f * PI.toFloat() * i / (n - 1))
            samples[i] * hamming
        }
    }

    private fun computeFFT(samples: FloatArray): FloatArray {
        // Simplified FFT implementation
        val n = samples.size
        val magnitudes = FloatArray(n / 2)

        for (k in 0 until n / 2) {
            var real = 0.0f
            var imag = 0.0f

            for (j in 0 until n) {
                val angle = -2.0f * PI.toFloat() * k * j / n
                real += samples[j] * cos(angle)
                imag += samples[j] * sin(angle)
            }

            magnitudes[k] = sqrt(real * real + imag * imag)
        }

        return magnitudes
    }

    private fun applyMelFilterBank(fftMagnitudes: FloatArray, numFilters: Int = 26): FloatArray {
        val melFilters = FloatArray(numFilters)
        val filterSize = fftMagnitudes.size / numFilters

        for (i in 0 until numFilters) {
            val start = i * filterSize
            val end = minOf((i + 1) * filterSize, fftMagnitudes.size)

            var sum = 0.0f
            for (j in start until end) {
                sum += fftMagnitudes[j]
            }

            melFilters[i] = ln(maxOf(sum / (end - start), 1e-8f))
        }

        return melFilters
    }

    private fun computeDCT(input: FloatArray, numCoeffs: Int): FloatArray {
        val n = input.size
        val output = FloatArray(minOf(numCoeffs, n))

        for (k in output.indices) {
            var sum = 0.0f
            for (j in 0 until n) {
                sum += input[j] * cos(PI.toFloat() * k * (j + 0.5f) / n)
            }
            output[k] = sum
        }

        return output
    }

    private fun computeSpectralCentroid(fft: FloatArray): Float {
        var weightedSum = 0.0f
        var magnitudeSum = 0.0f

        for ((index, magnitude) in fft.withIndex()) {
            weightedSum += index * magnitude
            magnitudeSum += magnitude
        }

        return if (magnitudeSum > 0) weightedSum / magnitudeSum else 0.0f
    }

    private fun computeSpectralRolloff(fft: FloatArray, threshold: Float = 0.85f): Float {
        val totalEnergy = fft.sum()
        val targetEnergy = totalEnergy * threshold

        var cumulativeEnergy = 0.0f
        for ((index, magnitude) in fft.withIndex()) {
            cumulativeEnergy += magnitude
            if (cumulativeEnergy >= targetEnergy) {
                return index.toFloat()
            }
        }

        return (fft.size - 1).toFloat()
    }

    private fun computeZeroCrossingRate(samples: FloatArray): Float {
        if (samples.size <= 1) return 0.0f

        var crossings = 0
        for (i in 1 until samples.size) {
            if ((samples[i] >= 0) != (samples[i - 1] >= 0)) {
                crossings++
            }
        }

        return crossings.toFloat() / (samples.size - 1)
    }

    // Data conversion helpers
    private fun bytesToFloatArray(bytes: ByteArray): FloatArray {
        val buffer = ByteBuffer.wrap(bytes)
        buffer.order(ByteOrder.nativeOrder())
        val floatBuffer = buffer.asFloatBuffer()
        val floats = FloatArray(floatBuffer.remaining())
        floatBuffer.get(floats)
        return floats
    }

    private fun floatArrayToBytes(floats: FloatArray): ByteArray {
        val buffer = ByteBuffer.allocate(floats.size * 4)
        buffer.order(ByteOrder.nativeOrder())
        val floatBuffer = buffer.asFloatBuffer()
        floatBuffer.put(floats)
        return buffer.array()
    }
}
