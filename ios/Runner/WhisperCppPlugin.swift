// ios/Runner/WhisperCppPlugin.swift (NEW FILE)
import Flutter
import UIKit

// Define a struct to match the C struct for passing results
struct CTranscriptionSegment {
    let text: UnsafePointer<CChar>
    let t0: Int64
    let t1: Int64
}

public class WhisperCppPlugin: NSObject, FlutterPlugin {
    // A singleton to manage the whisper context
    private static var whisperContext: OpaquePointer?
    private static var isModelLoaded = false

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.crispstrobe.crisperweaver.whisper_cpp", binaryMessenger: registrar.messenger())
        let instance = WhisperCppPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Dispatch to a background thread for long-running tasks
        DispatchQueue.global(qos: .userInitiated).async {
            switch call.method {
            case "initModel":
                self.initModel(call: call, result: result)
            case "transcribe":
                self.transcribe(call: call, result: result)
            case "freeModel":
                self.freeModel(result: result)
            case "isModelLoaded":
                result(WhisperCppPlugin.isModelLoaded)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private func initModel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let modelPath = args["modelPath"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "modelPath is required", details: nil))
            return
        }

        // Free previous model if it exists
        if WhisperCppPlugin.whisperContext != nil {
            whisper_ios_free(WhisperCppPlugin.whisperContext)
            WhisperCppPlugin.whisperContext = nil
            WhisperCppPlugin.isModelLoaded = false
        }

        let context = whisper_ios_init(modelPath)
        
        if let ctx = context {
            WhisperCppPlugin.whisperContext = ctx
            WhisperCppPlugin.isModelLoaded = true
            result(true)
        } else {
            WhisperCppPlugin.isModelLoaded = false
            result(FlutterError(code: "INIT_ERROR", message: "Failed to initialize whisper.cpp model from path: \(modelPath)", details: nil))
        }
    }

    private func transcribe(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let context = WhisperCppPlugin.whisperContext else {
            result(FlutterError(code: "NO_MODEL", message: "Model is not initialized", details: nil))
            return
        }
        
        guard let args = call.arguments as? [String: Any],
              let audioData = args["audioData"] as? FlutterStandardTypedData else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "audioData is required", details: nil))
            return
        }
        
        // Convert audio data from Flutter to a Swift Float array
        let samples = audioData.data.withUnsafeBytes {
            $0.bindMemory(to: Float.self)
        }
        let floatSamples = Array(samples)

        // The C++ function returns a pointer to an array of structs and the count
        var segmentCount: Int32 = 0
        let segmentsPtr = whisper_ios_transcribe(context, floatSamples, Int32(floatSamples.count), &segmentCount)

        guard let segmentsArray = segmentsPtr else {
            result([]) // Return empty list on failure
            return
        }

        var transcriptionResult: [[String: Any]] = []
        for i in 0..<Int(segmentCount) {
            let cSegment = segmentsArray[i]
            let text = String(cString: cSegment.text)
            
            // whisper.cpp timestamps are in 10ms units, convert to seconds
            let startTime = Double(cSegment.t0) * 0.01
            let endTime = Double(cSegment.t1) * 0.01

            let segmentMap: [String: Any] = [
                "text": text,
                "startTime": startTime,
                "endTime": endTime,
                "confidence": 0.9 // whisper.cpp does not provide segment-level confidence by default
            ]
            transcriptionResult.append(segmentMap)
        }

        // IMPORTANT: Free the memory allocated by the C++ function
        whisper_ios_free_segments(segmentsArray, segmentCount)

        result(transcriptionResult)
    }

    private func freeModel(result: @escaping FlutterResult) {
        if let context = WhisperCppPlugin.whisperContext {
            whisper_ios_free(context)
            WhisperCppPlugin.whisperContext = nil
            WhisperCppPlugin.isModelLoaded = false
        }
        result(nil)
    }
}