// ios/Runner/AudioProcessor.swift (NEW FILE)
import Foundation
import Accelerate

@available(iOS 14.0, *)
class AudioProcessor {
    // Whisper audio processing constants
    private let sampleRate: Double = 16000.0
    private let nFFT: Int = 400
    private let hopLength: Int = 160
    private let nMels: Int = 80
    private let nSamples: Int = 480000 // 30 seconds of audio

    private let melFilters: [[Float]]

    init?() {
        // Generate Mel filter bank weights
        guard let filters = AudioProcessor.melFilterbank(
            sampleRate: self.sampleRate,
            nFFT: self.nFFT,
            nMels: self.nMels
        ) else {
            return nil
        }
        self.melFilters = filters
    }

    public func extractMelSpectrogram(from pcmSamples: [Float]) throws -> MLMultiArray {
        var paddedSamples = pcmSamples
        // Pad or truncate audio to the required 30-second length
        if paddedSamples.count < nSamples {
            paddedSamples.append(contentsOf: [Float](repeating: 0.0, count: nSamples - paddedSamples.count))
        } else if paddedSamples.count > nSamples {
            paddedSamples = Array(paddedSamples.prefix(nSamples))
        }

        // 1. Create frames (STFT)
        let frames = self.frame(data: paddedSamples, frameSize: nFFT, hopLength: hopLength)

        // 2. Compute power spectrogram
        let spectrogram = self.computePowerSpectrogram(frames: frames)

        // 3. Apply Mel filter bank
        var melSpectrogram = [[Float]](repeating: [Float](repeating: 0.0, count: frames.count), count: nMels)
        vDSP_mmul(melFilters, 1, spectrogram, 1, &melSpectrogram, 1, vDSP_Length(nMels), vDSP_Length(frames.count), vDSP_Length(spectrogram[0].count))

        // 4. Convert to log scale
        let logSpec = self.logScale(melSpectrogram: melSpectrogram)

        // 5. Shape into MLMultiArray
        let multiArray = try MLMultiArray(shape: [1, NSNumber(value: nMels), NSNumber(value: logSpec[0].count)], dataType: .float32)

        let ptr = UnsafeMutablePointer<Float32>(OpaquePointer(multiArray.dataPointer))
        for r in 0..<logSpec.count {
            for c in 0..<logSpec[0].count {
                ptr[r * logSpec[0].count + c] = logSpec[r][c]
            }
        }
        
        return multiArray
    }
    
    // MARK: - Private DSP Functions

    private func frame(data: [Float], frameSize: Int, hopLength: Int) -> [[Float]] {
        let frameCount = (data.count - frameSize) / hopLength + 1
        var frames: [[Float]] = []
        let window = vDSP.window(ofType: Float.self, usingSequence: .hamming, count: frameSize, isHalfWindow: false)
        
        for i in 0..<frameCount {
            let start = i * hopLength
            let frame = Array(data[start..<(start + frameSize)])
            let windowedFrame = vDSP.multiply(frame, window)
            frames.append(windowedFrame)
        }
        return frames
    }

    private func computePowerSpectrogram(frames: [[Float]]) -> [[Float]] {
        let nFFT = self.nFFT
        let fftSetUp = vDSP_create_fftsetup(vDSP_Length(log2(Float(nFFT))), FFTRadix(kFFTRadix2))!
        var magnitudes: [[Float]] = []

        var real = [Float](repeating: 0, count: nFFT / 2)
        var imag = [Float](repeating: 0, count: nFFT / 2)
        var complexBuffer = DSPSplitComplex(realp: &real, imagp: &imag)
        
        for frame in frames {
            var autoCorrelation = [Float](repeating: 0, count: nFFT)
            vDSP_vadd(frame, 0, [0], 0, &autoCorrelation, 1, vDSP_Length(frame.count))
            
            let frameFloats = UnsafePointer<Float>(frame)
            frameFloats.withMemoryRebound(to: DSPComplex.self, capacity: frame.count) {
                 vDSP_ctoz($0, 2, &complexBuffer, 1, vDSP_Length(nFFT / 2))
            }
            
            vDSP_fft_zrip(fftSetUp, &complexBuffer, 1, vDSP_Length(log2(Float(nFFT))), FFTDirection(FFT_FORWARD))
            
            var magnitude = [Float](repeating: 0, count: nFFT / 2)
            vDSP_zvmags(&complexBuffer, 1, &magnitude, 1, vDSP_Length(nFFT / 2))
            
            magnitudes.append(magnitude)
        }
        
        vDSP_destroy_fftsetup(fftSetUp)
        return magnitudes
    }

    private func logScale(melSpectrogram: [[Float]]) -> [[Float]] {
        var logSpectrogram = melSpectrogram
        for r in 0..<logSpectrogram.count {
            for c in 0..<logSpectrogram[0].count {
                let value = max(logSpectrogram[r][c], 1e-10)
                logSpectrogram[r][c] = log10(value)
            }
        }

        let maxValue = logSpectrogram.flatMap { $0 }.max() ?? 0.0
        let refValue = maxValue - 8.0
        
        for r in 0..<logSpectrogram.count {
            for c in 0..<logSpectrogram[0].count {
                logSpectrogram[r][c] = (logSpectrogram[r][c] - refValue) / 4.0
            }
        }
        return logSpectrogram
    }
    
    // MARK: - Mel Filterbank Generation
    
    private static func hertzToMels(_ hertz: Double) -> Double {
        return 2595.0 * log10(1.0 + hertz / 700.0)
    }

    private static func melsToHertz(_ mels: Double) -> Double {
        return 700.0 * (pow(10.0, mels / 2595.0) - 1.0)
    }

    private static func melFilterbank(sampleRate: Double, nFFT: Int, nMels: Int) -> [[Float]]? {
        let fMin = 0.0
        let fMax = sampleRate / 2.0
        let melMin = hertzToMels(fMin)
        let melMax = hertzToMels(fMax)
        
        let melPoints = stride(from: melMin, to: melMax, by: (melMax - melMin) / Double(nMels + 1)).map(Double.init)
        let hertzPoints = melPoints.map { melsToHertz($0) }
        let fftFreqs = (0...nFFT/2).map { Double($0) * sampleRate / Double(nFFT) }
        
        var filters = [[Float]](repeating: [Float](repeating: 0.0, count: nFFT/2 + 1), count: nMels)
        
        for m in 1...nMels {
            let f_m_minus_1 = hertzPoints[m-1]
            let f_m = hertzPoints[m]
            let f_m_plus_1 = hertzPoints[m+1]
            
            for k in 0..<fftFreqs.count {
                if fftFreqs[k] >= f_m_minus_1 && fftFreqs[k] <= f_m {
                    filters[m-1][k] = Float((fftFreqs[k] - f_m_minus_1) / (f_m - f_m_minus_1))
                } else if fftFreqs[k] >= f_m && fftFreqs[k] <= f_m_plus_1 {
                    filters[m-1][k] = Float((f_m_plus_1 - fftFreqs[k]) / (f_m_plus_1 - f_m))
                }
            }
        }
        return filters
    }
}