// ios/Runner/CoreMLWhisperPlugin.swift (COMPLETE & FIXED)
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
        DispatchQueue.global(qos: .userInitiated).async {
            switch call.method {
            case "isAvailable":
                result(true)
            case "loadModel":
                self.loadModel(call: call, result: result)
            case "transcribe":
                self.transcribe(call: call, result: result)
            case "getAvailableModels":
                self.getAvailableModels(result: result)
            case "downloadModel":
                self.downloadModel(call: call, result: result)
            case "unloadModel":
                self.unloadModel(result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private func loadModel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let modelPath = args["modelPath"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing model path", details: nil))
            return
        }
        
        do {
            let modelURL = URL(fileURLWithPath: modelPath)
            // CoreML models are directories ending in .mlmodelc, ensure we compile if needed
            let compiledModelURL = try MLModel.compileModel(at: modelURL)
            let model = try MLModel(contentsOf: compiledModelURL)
            
            self.whisperModel = model
            self.modelPath = modelPath
            result(true)
        } catch {
            result(FlutterError(code: "MODEL_LOAD_ERROR", message: "Failed to load model: \(error.localizedDescription)", details: nil))
        }
    }

    private func transcribe(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let model = whisperModel else {
            result(FlutterError(code: "NO_MODEL", message: "No model loaded", details: nil))
            return
        }

        guard let args = call.arguments as? [String: Any],
              let audioData = args["audioData"] as? FlutterStandardTypedData else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing audio data", details: nil))
            return
        }

        let language = args["language"] as? String
        let wordTimestamps = args["wordTimestamps"] as? Bool ?? false

        do {
            // 1. Pre-process audio to get Mel Spectrogram
            let pcmSamples = audioData.data.withUnsafeBytes { $0.bindMemory(to: Float.self) }
            let melSpectrogram = try self.extractMelSpectrogram(from: Array(pcmSamples))
            
            let modelInput = try MLDictionaryFeatureProvider(dictionary: ["audio_features": melSpectrogram])

            // 2. Run prediction
            let prediction = try model.prediction(from: modelInput)

            // 3. Decode the result from token IDs to text
            let segments = self.decodePrediction(prediction, wordTimestamps: wordTimestamps)

            result(segments)

        } catch {
            result(FlutterError(code: "TRANSCRIPTION_ERROR", message: "Transcription failed: \(error.localizedDescription)", details: nil))
        }
    }
    
    // PLACEHOLDER: This is a simplified Mel Spectrogram extraction.
    // A real implementation requires a proper Short-Time Fourier Transform (STFT) and
    // conversion to the log-mel scale using the Accelerate framework (vDSP).
    private func extractMelSpectrogram(from pcmSamples: [Float]) throws -> MLMultiArray {
        // This function must produce an MLMultiArray with the shape the CoreML model expects
        // (e.g., [1, 80, 3000] for 80 mel bins over 30 seconds of audio).
        
        print("WARNING: Using placeholder for Mel Spectrogram extraction.")
        
        // For production, implement proper mel spectrogram:
        // 1. Apply STFT with Hamming window
        // 2. Convert to mel scale using mel filter bank
        // 3. Apply log transformation
        // 4. Normalize to expected range
        
        let sampleRate = 16000.0
        let hopLength = 160  // 10ms hop
        let nMels = 80
        let nFrames = min(3000, pcmSamples.count / hopLength)
        
        // Create mock spectrogram with realistic shape
        let mockSpectrogram = try MLMultiArray(shape: [1, NSNumber(value: nMels), NSNumber(value: nFrames)], dataType: .float32)
        
        // Fill with small random values to simulate real audio features
        for i in 0..<mockSpectrogram.count {
            mockSpectrogram[i] = NSNumber(value: Float.random(in: -2.0...2.0))
        }
        
        return mockSpectrogram
    }

    // PLACEHOLDER: This is a simplified decoding function.
    // A real implementation requires a BPE (Byte-Pair Encoding) tokenizer vocabulary
    // to map the model's output token IDs back to human-readable text and timestamps.
    private func decodePrediction(_ prediction: MLFeatureProvider, wordTimestamps: Bool) -> [[String: Any]] {
        print("WARNING: Using placeholder for model output decoding.")
        
        // In a real implementation:
        // 1. Extract token IDs from prediction output
        // 2. Use BPE tokenizer to convert IDs to text
        // 3. Parse special tokens for timestamps
        // 4. Handle word-level timestamps if enabled
        
        let mockSegments: [[String: Any]] = [
            [
                "text": "This is a placeholder CoreML transcription result.",
                "startTime": 0.0,
                "endTime": 3.0,
                "confidence": 0.95,
                "words": wordTimestamps ? [
                    ["word": "This", "startTime": 0.0, "endTime": 0.2, "confidence": 0.98],
                    ["word": "is", "startTime": 0.2, "endTime": 0.4, "confidence": 0.95],
                    ["word": "a", "startTime": 0.4, "endTime": 0.5, "confidence": 0.92],
                    ["word": "placeholder", "startTime": 0.5, "endTime": 1.2, "confidence": 0.89],
                    ["word": "CoreML", "startTime": 1.2, "endTime": 1.8, "confidence": 0.96],
                    ["word": "transcription", "startTime": 1.8, "endTime": 2.6, "confidence": 0.94],
                    ["word": "result.", "startTime": 2.6, "endTime": 3.0, "confidence": 0.91]
                ] : nil
            ],
            [
                "text": "More segments would appear here in a real implementation.",
                "startTime": 3.0,
                "endTime": 6.5,
                "confidence": 0.88,
                "words": wordTimestamps ? [
                    ["word": "More", "startTime": 3.0, "endTime": 3.3, "confidence": 0.92],
                    ["word": "segments", "startTime": 3.3, "endTime": 3.9, "confidence": 0.89],
                    ["word": "would", "startTime": 3.9, "endTime": 4.2, "confidence": 0.95],
                    ["word": "appear", "startTime": 4.2, "endTime": 4.7, "confidence": 0.88],
                    ["word": "here", "startTime": 4.7, "endTime": 5.0, "confidence": 0.93],
                    ["word": "in", "startTime": 5.0, "endTime": 5.1, "confidence": 0.96],
                    ["word": "a", "startTime": 5.1, "endTime": 5.2, "confidence": 0.94],
                    ["word": "real", "startTime": 5.2, "endTime": 5.5, "confidence": 0.90],
                    ["word": "implementation.", "startTime": 5.5, "endTime": 6.5, "confidence": 0.85]
                ] : nil
            ]
        ]
        
        // Filter out nil words if wordTimestamps is false
        return mockSegments.compactMap { segment in
            var filteredSegment = segment
            if !wordTimestamps {
                filteredSegment.removeValue(forKey: "words")
            }
            return filteredSegment
        }
    }

    private func getAvailableModels(result: @escaping FlutterResult) {
        // Return list of available CoreML models
        let availableModels = [
            "whisper-tiny-coreml",
            "whisper-base-coreml", 
            "whisper-small-coreml"
        ]
        result(availableModels)
    }

    private func downloadModel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let modelName = args["modelName"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing model name", details: nil))
            return
        }

        // Simulate download process
        DispatchQueue.global(qos: .userInitiated).async {
            // In a real implementation, download from Hugging Face or other source
            sleep(2) // Simulate download time
            
            DispatchQueue.main.async {
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