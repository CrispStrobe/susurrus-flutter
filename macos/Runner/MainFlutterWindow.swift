import Cocoa
import FlutterMacOS
import AVFoundation
import Accelerate

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    // Start with a large enough window that the dual-pane transcription
    // screen doesn't clip. Users can still resize smaller; scroll views
    // inside the app handle that.
    let defaultSize = NSSize(width: 1200, height: 800)
    let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
    let origin = NSPoint(
      x: screen.midX - defaultSize.width / 2,
      y: screen.midY - defaultSize.height / 2
    )
    let windowFrame = NSRect(origin: origin, size: defaultSize)
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.minSize = NSSize(width: 600, height: 480)

    RegisterGeneratedPlugins(registry: flutterViewController)
    AudioProcessingPlugin.register(with: flutterViewController.registrar(forPlugin: "AudioProcessingPlugin"))

    super.awakeFromNib()
  }
}

public class AudioProcessingPlugin: NSObject, FlutterPlugin {
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.crispstrobe.crisperweaver.audio_processing", binaryMessenger: registrar.messenger)
        let instance = AudioProcessingPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "convertToWav":
            guard let args = call.arguments as? [String: Any],
                  let filePath = args["filePath"] as? String,
                  let sampleRate = args["sampleRate"] as? Int,
                  let channels = args["channels"] as? Int else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing required arguments", details: nil))
                return
            }
            convertToWav(filePath: filePath, sampleRate: sampleRate, channels: channels, result: result)
            
        case "extractFeatures":
            guard let args = call.arguments as? [String: Any],
                  let audioData = args["audioData"] as? FlutterStandardTypedData else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing audio data", details: nil))
                return
            }
            extractFeatures(audioData: audioData, result: result)
            
        case "normalizeAudio":
            guard let args = call.arguments as? [String: Any],
                  let audioData = args["audioData"] as? FlutterStandardTypedData else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing audio data", details: nil))
                return
            }
            normalizeAudio(audioData: audioData, result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func convertToWav(filePath: String, sampleRate: Int, channels: Int, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let url = URL(fileURLWithPath: filePath)
                
                // Load audio file
                let audioFile = try AVAudioFile(forReading: url)
                let format = audioFile.processingFormat
                
                // Create target format
                guard let targetFormat = AVAudioFormat(
                    commonFormat: .pcmFormatFloat32,
                    sampleRate: Double(sampleRate),
                    channels: AVAudioChannelCount(channels),
                    interleaved: false
                ) else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "FORMAT_ERROR", message: "Failed to create target format", details: nil))
                    }
                    return
                }
                
                // Create converter
                guard let converter = AVAudioConverter(from: format, to: targetFormat) else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "CONVERTER_ERROR", message: "Failed to create audio converter", details: nil))
                    }
                    return
                }
                
                // Prepare buffer
                let frameCapacity = AVAudioFrameCount(audioFile.length)
                guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity),
                      let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCapacity) else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "BUFFER_ERROR", message: "Failed to create audio buffers", details: nil))
                    }
                    return
                }
                
                // Read audio file
                try audioFile.read(into: inputBuffer)
                
                // Convert audio
                var error: NSError?
                let status = converter.convert(to: outputBuffer, error: &error) { _, _ in inputBuffer }
                
                if status == .error || error != nil {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "CONVERSION_ERROR", 
                                          message: "Audio conversion failed: \(error?.localizedDescription ?? "Unknown error")", 
                                          details: nil))
                    }
                    return
                }
                
                // Extract samples
                let samples = self.extractSamples(from: outputBuffer)
                
                DispatchQueue.main.async {
                    result([
                        "samples": samples,
                        "sampleRate": sampleRate,
                        "channels": channels
                    ])
                }
                
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "AUDIO_ERROR", 
                                      message: "Failed to process audio: \(error.localizedDescription)", 
                                      details: nil))
                }
            }
        }
    }
    
    private func extractSamples(from buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channelData = buffer.floatChannelData else { return [] }
        
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        
        var samples: [Float] = []
        samples.reserveCapacity(frameLength)
        
        if channelCount == 1 {
            // Mono audio
            let channel = channelData[0]
            for i in 0..<frameLength {
                samples.append(channel[i])
            }
        } else {
            // Multi-channel audio - mix down to mono
            for i in 0..<frameLength {
                var sample: Float = 0.0
                for channel in 0..<channelCount {
                    sample += channelData[channel][i]
                }
                samples.append(sample / Float(channelCount))
            }
        }
        
        return samples
    }
    
    private func extractFeatures(audioData: FlutterStandardTypedData, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            let samples = self.dataToFloatArray(audioData.data)
            
            // Extract MFCC features
            let mfccFeatures = self.extractMFCC(from: samples)
            
            // Extract spectral features
            let spectralFeatures = self.extractSpectralFeatures(from: samples)
            
            DispatchQueue.main.async {
                result([
                    "mfcc": mfccFeatures,
                    "spectral": spectralFeatures
                ])
            }
        }
    }
    
    private func normalizeAudio(audioData: FlutterStandardTypedData, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            var samples = self.dataToFloatArray(audioData.data)
            
            // Normalize audio to [-1, 1] range
            let maxValue = samples.map(abs).max() ?? 1.0
            if maxValue > 0 {
                for i in 0..<samples.count {
                    samples[i] /= maxValue
                }
            }
            
            let normalizedData = self.floatArrayToData(samples)
            
            DispatchQueue.main.async {
                result(FlutterStandardTypedData(bytes: normalizedData))
            }
        }
    }
    
    private func extractMFCC(from samples: [Float]) -> [[Float]] {
        let frameSize = 512
        let hopSize = 256
        let numMFCC = 13
        
        var mfccFrames: [[Float]] = []
        
        // Process audio in frames
        for startIndex in stride(from: 0, to: samples.count - frameSize, by: hopSize) {
            let endIndex = min(startIndex + frameSize, samples.count)
            let frame = Array(samples[startIndex..<endIndex])
            
            // Apply pre-emphasis
            let preEmphasized = applyPreEmphasis(frame)
            
            // Apply window
            let windowed = applyHammingWindow(preEmphasized)
            
            // Compute FFT
            let fftResult = computeFFT(windowed)
            
            // Apply mel filter bank
            let melFiltered = applyMelFilterBank(fftResult)
            
            // Apply DCT
            let mfcc = computeDCT(melFiltered, numCoeffs: numMFCC)
            
            mfccFrames.append(mfcc)
        }
        
        return mfccFrames
    }
    
    private func extractSpectralFeatures(from samples: [Float]) -> [String: Float] {
        // Compute spectral centroid, rolloff, etc.
        let fft = computeFFT(samples)
        
        // Spectral centroid
        let spectralCentroid = computeSpectralCentroid(fft)
        
        // Spectral rolloff
        let spectralRolloff = computeSpectralRolloff(fft)
        
        // Zero crossing rate
        let zeroCrossingRate = computeZeroCrossingRate(samples)
        
        return [
            "spectralCentroid": spectralCentroid,
            "spectralRolloff": spectralRolloff,
            "zeroCrossingRate": zeroCrossingRate
        ]
    }
    
    // MARK: - DSP Helper Functions
    
    private func applyPreEmphasis(_ samples: [Float], alpha: Float = 0.97) -> [Float] {
        guard samples.count > 1 else { return samples }
        
        var result = [Float](repeating: 0, count: samples.count)
        result[0] = samples[0]
        
        for i in 1..<samples.count {
            result[i] = samples[i] - alpha * samples[i - 1]
        }
        
        return result
    }
    
    private func applyHammingWindow(_ samples: [Float]) -> [Float] {
        let n = samples.count
        return samples.enumerated().map { index, value in
            let hamming = 0.54 - 0.46 * cos(2.0 * Float.pi * Float(index) / Float(n - 1))
            return value * hamming
        }
    }
    
    private func computeFFT(_ samples: [Float]) -> [Float] {
        let n = samples.count
        let log2n = vDSP_Length(log2(Double(n)))
        
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return []
        }
        
        var realParts = samples
        var imagParts = [Float](repeating: 0, count: n)
        
        var splitComplex = DSPSplitComplex(realp: &realParts, imagp: &imagParts)
        
        vDSP_fft_zip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
        
        var magnitudes = [Float](repeating: 0, count: n / 2)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(n / 2))
        
        vDSP_destroy_fftsetup(fftSetup)
        
        return magnitudes.map { sqrt($0) }
    }
    
    private func applyMelFilterBank(_ fftMagnitudes: [Float], numFilters: Int = 26) -> [Float] {
        // Simplified mel filter bank implementation
        var melFilters = [Float](repeating: 0, count: numFilters)
        let filterSize = fftMagnitudes.count / numFilters
        
        for i in 0..<numFilters {
            let start = i * filterSize
            let end = min((i + 1) * filterSize, fftMagnitudes.count)
            
            var sum: Float = 0
            for j in start..<end {
                sum += fftMagnitudes[j]
            }
            
            melFilters[i] = log(max(sum / Float(end - start), 1e-8))
        }
        
        return melFilters
    }
    
    private func computeDCT(_ input: [Float], numCoeffs: Int) -> [Float] {
        let n = input.count
        var output = [Float](repeating: 0, count: min(numCoeffs, n))
        
        for k in 0..<output.count {
            var sum: Float = 0
            for j in 0..<n {
                sum += input[j] * cos(Float.pi * Float(k) * (Float(j) + 0.5) / Float(n))
            }
            output[k] = sum
        }
        
        return output
    }
    
    private func computeSpectralCentroid(_ fft: [Float]) -> Float {
        var weightedSum: Float = 0
        var magnitudeSum: Float = 0
        
        for (index, magnitude) in fft.enumerated() {
            weightedSum += Float(index) * magnitude
            magnitudeSum += magnitude
        }
        
        return magnitudeSum > 0 ? weightedSum / magnitudeSum : 0
    }
    
    private func computeSpectralRolloff(_ fft: [Float], threshold: Float = 0.85) -> Float {
        let totalEnergy = fft.reduce(0, +)
        let targetEnergy = totalEnergy * threshold
        
        var cumulativeEnergy: Float = 0
        for (index, magnitude) in fft.enumerated() {
            cumulativeEnergy += magnitude
            if cumulativeEnergy >= targetEnergy {
                return Float(index)
            }
        }
        
        return Float(fft.count - 1)
    }
    
    private func computeZeroCrossingRate(_ samples: [Float]) -> Float {
        guard samples.count > 1 else { return 0 }
        
        var crossings = 0
        for i in 1..<samples.count {
            if (samples[i] >= 0) != (samples[i - 1] >= 0) {
                crossings += 1
            }
        }
        
        return Float(crossings) / Float(samples.count - 1)
    }
    
    // MARK: - Data Conversion Helpers
    
    private func dataToFloatArray(_ data: Data) -> [Float] {
        return data.withUnsafeBytes { bytes in
            let floatBuffer = bytes.bindMemory(to: Float32.self)
            return Array(floatBuffer)
        }
    }
    
    private func floatArrayToData(_ array: [Float]) -> Data {
        return array.withUnsafeBytes { bytes in
            Data(bytes)
        }
    }
}