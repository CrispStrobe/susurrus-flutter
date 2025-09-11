import Foundation
import Flutter
import CoreML
import AVFoundation
import Accelerate

@available(iOS 13.0, *)
public class CoreMLWhisperPlugin: NSObject, FlutterPlugin {
    private var whisperModel: MLModel?
    private var modelPath: String?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.susurrus.coreml_whisper", binaryMessenger: registrar.messenger())
        let instance = CoreMLWhisperPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isAvailable":
            result(true) // CoreML is available on iOS 13+
            
        case "loadModel":
            guard let args = call.arguments as? [String: Any],
                  let modelPath = args["modelPath"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing model path", details: nil))
                return
            }
            loadModel(modelPath: modelPath, result: result)
            
        case "transcribe":
            guard let args = call.arguments as? [String: Any],
                  let audioData = args["audioData"] as? FlutterStandardTypedData else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing audio data", details: nil))
                return
            }
            
            let language = args["language"] as? String
            let wordTimestamps = args["wordTimestamps"] as? Bool ?? false
            
            transcribe(audioData: audioData, language: language, wordTimestamps: wordTimestamps, result: result)
            
        case "getAvailableModels":
            getAvailableModels(result: result)
            
        case "downloadModel":
            guard let args = call.arguments as? [String: Any],
                  let modelName = args["modelName"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing model name", details: nil))
                return
            }
            downloadModel(modelName: modelName, result: result)
            
        case "unloadModel":
            unloadModel(result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func loadModel(modelPath: String, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let modelURL = URL(fileURLWithPath: modelPath)
                let model = try MLModel(contentsOf: modelURL)
                
                DispatchQueue.main.async {
                    self.whisperModel = model
                    self.modelPath = modelPath
                    result(true)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "MODEL_LOAD_ERROR", 
                                      message: "Failed to load model: \(error.localizedDescription)", 
                                      details: nil))
                }
            }
        }
    }
    
    private func transcribe(audioData: FlutterStandardTypedData, 
                           language: String?, 
                           wordTimestamps: Bool, 
                           result: @escaping FlutterResult) {
        guard let model = whisperModel else {
            result(FlutterError(code: "NO_MODEL", message: "No model loaded", details: nil))
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Convert audio data to the format expected by Whisper
                let audioBuffer = self.processAudioData(audioData.data)
                
                // Create input for the model
                let inputFeatures = try self.extractMelSpectrogram(from: audioBuffer)
                let modelInput = try MLDictionaryFeatureProvider(dictionary: [
                    "mel_spectrogram": MLMultiArray(inputFeatures)
                ])
                
                // Run prediction
                let prediction = try model.prediction(from: modelInput)
                
                // Extract results
                let segments = self.extractSegments(from: prediction, wordTimestamps: wordTimestamps)
                
                DispatchQueue.main.async {
                    result(segments)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "TRANSCRIPTION_ERROR", 
                                      message: "Transcription failed: \(error.localizedDescription)", 
                                      details: nil))
                }
            }
        }
    }
    
    private func processAudioData(_ data: Data) -> [Float] {
        // Convert audio data to Float array
        let audioBuffer = data.withUnsafeBytes { bytes in
            let floatBuffer = bytes.bindMemory(to: Float32.self)
            return Array(floatBuffer)
        }
        
        // Ensure audio is 16kHz mono
        return resampleAudio(audioBuffer, targetSampleRate: 16000)
    }
    
    private func resampleAudio(_ input: [Float], targetSampleRate: Int) -> [Float] {
        // Simple resampling - in production you'd want more sophisticated resampling
        // For now, assume input is already at correct sample rate
        return input
    }
    
    private func extractMelSpectrogram(from audioBuffer: [Float]) throws -> [[Float]] {
        // This is a simplified mel spectrogram extraction
        // In a real implementation, you'd want to use more sophisticated DSP
        
        let frameSize = 400 // 25ms at 16kHz
        let hopSize = 160   // 10ms at 16kHz
        let numMelBins = 80
        
        var melSpectrogram: [[Float]] = []
        
        // Process audio in frames
        for startIndex in stride(from: 0, to: audioBuffer.count - frameSize, by: hopSize) {
            let endIndex = min(startIndex + frameSize, audioBuffer.count)
            let frame = Array(audioBuffer[startIndex..<endIndex])
            
            // Apply window function
            let windowedFrame = applyHammingWindow(frame)
            
            // Compute FFT (simplified)
            let fftResult = computeFFT(windowedFrame)
            
            // Convert to mel scale
            let melFrame = convertToMelScale(fftResult, numMelBins: numMelBins)
            
            melSpectrogram.append(melFrame)
        }
        
        return melSpectrogram
    }
    
    private func applyHammingWindow(_ frame: [Float]) -> [Float] {
        return frame.enumerated().map { index, value in
            let hammingValue = 0.54 - 0.46 * cos(2.0 * Float.pi * Float(index) / Float(frame.count - 1))
            return value * hammingValue
        }
    }
    
    private func computeFFT(_ frame: [Float]) -> [Float] {
        // Simplified FFT computation
        // In production, use vDSP or similar optimized library
        let n = frame.count
        var magnitudes: [Float] = []
        
        for k in 0..<(n/2) {
            var real: Float = 0
            var imag: Float = 0
            
            for j in 0..<n {
                let angle = -2.0 * Float.pi * Float(k * j) / Float(n)
                real += frame[j] * cos(angle)
                imag += frame[j] * sin(angle)
            }
            
            let magnitude = sqrt(real * real + imag * imag)
            magnitudes.append(magnitude)
        }
        
        return magnitudes
    }
    
    private func convertToMelScale(_ fftMagnitudes: [Float], numMelBins: Int) -> [Float] {
        // Simplified mel scale conversion
        var melBins: [Float] = []
        let binSize = fftMagnitudes.count / numMelBins
        
        for i in 0..<numMelBins {
            let startBin = i * binSize
            let endBin = min((i + 1) * binSize, fftMagnitudes.count)
            
            let binSum = fftMagnitudes[startBin..<endBin].reduce(0, +)
            let binAverage = binSum / Float(endBin - startBin)
            
            // Apply log compression
            melBins.append(log(max(binAverage, 1e-8)))
        }
        
        return melBins
    }
    
    private func extractSegments(from prediction: MLFeatureProvider, wordTimestamps: Bool) -> [[String: Any]] {
        // Extract transcription segments from model output
        // This is a simplified implementation
        
        var segments: [[String: Any]] = []
        
        // In a real implementation, you'd parse the actual model output
        // For now, return a mock segment
        let mockSegment: [String: Any] = [
            "text": "Transcribed text would appear here",
            "startTime": 0.0,
            "endTime": 5.0,
            "confidence": 0.95
        ]
        
        segments.append(mockSegment)
        
        return segments
    }
    
    private func getAvailableModels(result: @escaping FlutterResult) {
        // Return list of available CoreML models
        let availableModels = [
            "whisper-tiny",
            "whisper-base", 
            "whisper-small"
        ]
        result(availableModels)
    }
    
    private func downloadModel(modelName: String, result: @escaping FlutterResult) {
        // Download model from Hugging Face or other source
        // This is a simplified implementation
        DispatchQueue.global(qos: .userInitiated).async {
            // Simulate download
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                result(true)
            }
        }
    }
    
    private func unloadModel(result: @escaping FlutterResult) {
        whisperModel = nil
        modelPath = nil
        result(nil)
    }
}

// MARK: - MLMultiArray Extension
extension MLMultiArray {
    convenience init(_ array: [[Float]]) throws {
        let shape = [NSNumber(value: array.count), NSNumber(value: array[0].count)]
        try self.init(shape: shape, dataType: .float32)
        
        for (i, row) in array.enumerated() {
            for (j, value) in row.enumerated() {
                let index = [NSNumber(value: i), NSNumber(value: j)]
                self[index] = NSNumber(value: value)
            }
        }
    }
}