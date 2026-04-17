// ios/Runner/CoreMLWhisperPlugin.swift (COMPLETE & FUNCTIONAL)
import Foundation
import Flutter
import CoreML
import AVFoundation

@available(iOS 14.0, *) // Required for MLMultiArray(unsafeDataPointer:)
public class CoreMLWhisperPlugin: NSObject, FlutterPlugin {
    private var whisperModel: MLModel?
    private var modelPath: String?
    private var audioProcessor: AudioProcessor?
    private var tokenizer: Tokenizer?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.crispstrobe.crisperweaver.coreml_whisper", binaryMessenger: registrar.messenger())
        let instance = CoreMLWhisperPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Dispatch to a background thread for long-running tasks
        DispatchQueue.global(qos: .userInitiated).async {
            switch call.method {
            case "isAvailable":
                result(true)
            case "loadModel":
                self.loadModel(call: call, result: result)
            case "transcribe":
                self.transcribe(call: call, result: result)
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
            let compiledModelURL = try MLModel.compileModel(at: modelURL)
            let model = try MLModel(contentsOf: compiledModelURL)

            self.whisperModel = model
            self.modelPath = modelPath
            self.audioProcessor = AudioProcessor()
            self.tokenizer = Tokenizer() // Initialize the tokenizer
            
            result(true)
        } catch {
            result(FlutterError(code: "MODEL_LOAD_ERROR", message: "Failed to load CoreML model: \(error.localizedDescription)", details: nil))
        }
    }

    private func transcribe(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let model = whisperModel, let processor = audioProcessor, let tokenizer = self.tokenizer else {
            result(FlutterError(code: "NO_MODEL", message: "Model is not initialized", details: nil))
            return
        }

        guard let args = call.arguments as? [String: Any],
              let audioData = args["audioData"] as? FlutterStandardTypedData else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "audioData is required", details: nil))
            return
        }

        do {
            // 1. Convert audio data from Flutter to a Swift Float array
            let pcmSamples = audioData.data.withUnsafeBytes {
                $0.bindMemory(to: Float.self)
            }
            let floatSamples = Array(pcmSamples)
            
            // 2. Pre-process audio to get Mel Spectrogram using the Accelerate framework
            let melSpectrogram = try processor.extractMelSpectrogram(from: floatSamples)
            
            // 3. Create model input provider
            let modelInput = try MLDictionaryFeatureProvider(dictionary: ["audio_features": melSpectrogram])

            // 4. Run prediction
            let prediction = try model.prediction(from: modelInput)

            // 5. Decode the result from token IDs to text segments
            let segments = try tokenizer.decode(prediction: prediction)

            result(segments)

        } catch {
            result(FlutterError(code: "TRANSCRIPTION_ERROR", message: "Transcription failed: \(error.localizedDescription)", details: nil))
        }
    }

    private func unloadModel(result: @escaping FlutterResult) {
        whisperModel = nil
        modelPath = nil
        audioProcessor = nil
        tokenizer = nil
        result(nil)
    }
}