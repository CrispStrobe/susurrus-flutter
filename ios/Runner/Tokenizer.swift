// ios/Runner/Tokenizer.swift

/*
This assumes
vocab.json: https://huggingface.co/openai/whisper-tiny/raw/main/vocab.json
merges.txt: https://huggingface.co/openai/whisper-tiny/raw/main/merges.txt
added as Assets to our Xcode Project
(Open project's ios folder in Xcode,
Drag the vocab.json and merges.txt files directly into the Runner folder within the Xcode project navigator.
When the options dialog appears, make sure "Copy items if needed" is checked and that Runner target is selected in the "Add to targets" list.
*/
import Foundation
import CoreML

class Tokenizer {
    // MARK: - Properties
    
    private let bpeRanks: [String: Int]
    private var vocab: [String: Int] = [:]
    private var decoders: [Int: String] = [:]

    // Special token IDs from the vocabulary
    private let eotToken: Int
    private let sotToken: Int
    private let transcribeToken: Int
    private let translateToken: Int
    private let noTimestampsToken: Int
    private let timestampBegin: Int
    private let timestampEnd: Int

    // MARK: - Initialization
    
    init?() {
        // Load vocab.json
        guard let vocabURL = Bundle.main.url(forResource: "vocab", withExtension: "json") else {
            print("Error: vocab.json not found in bundle.")
            return nil
        }
        guard let vocabData = try? Data(contentsOf: vocabURL) else {
            print("Error: Could not load data from vocab.json.")
            return nil
        }
        self.vocab = (try? JSONDecoder().decode([String: Int].self, from: vocabData)) ?? [:]
        
        // Create the reverse mapping for decoding
        for (key, value) in self.vocab {
            self.decoders[value] = key
        }

        // Load merges.txt
        guard let mergesURL = Bundle.main.url(forResource: "merges", withExtension: "txt") else {
            print("Error: merges.txt not found in bundle.")
            return nil
        }
        guard let mergesData = try? String(contentsOf: mergesURL, encoding: .utf8) else {
            print("Error: Could not load data from merges.txt.")
            return nil
        }
        
        let mergeLines = mergesData.split(separator: "\n").dropFirst() // Skip header
        var ranks: [String: Int] = [:]
        for (i, line) in mergeLines.enumerated() {
            ranks[String(line)] = i
        }
        self.bpeRanks = ranks

        // Assign special token IDs
        self.eotToken = vocab["<|endoftext|>"]!
        self.sotToken = vocab["<|startoftranscript|>"]!
        self.transcribeToken = vocab["<|transcribe|>"]!
        self.translateToken = vocab["<|translate|>"]!
        self.noTimestampsToken = vocab["<|notimestamps|>"]!
        self.timestampBegin = vocab["<|0.00|>"]!
        self.timestampEnd = vocab["<|30.00|>"]!
    }

    // MARK: - Decoding Logic
    
    func decode(prediction: MLFeatureProvider) throws -> [[String: Any]] {
        guard let tokensOutput = prediction.featureValue(for: "token_ids")?.multiArrayValue else {
            throw TokenizerError.missingPredictionOutput
        }

        let tokenIds = (0..<tokensOutput.count).map { tokensOutput[$0].intValue }
        return decode(tokens: tokenIds)
    }

    private func decode(tokens: [Int]) -> [[String: Any]] {
        var segments: [[String: Any]] = []
        var currentSegmentText = ""
        var startTime: Double = 0.0
        
        for tokenId in tokens {
            if isSpecial(tokenId) {
                continue // Skip special tokens like SOT, EOT, etc.
            }

            if isTimestamp(tokenId) {
                let timestamp = Double(tokenId - timestampBegin) * 0.02
                
                if !currentSegmentText.trimmingCharacters(in: .whitespaces).isEmpty {
                    // This timestamp marks the end of the previous segment.
                    let segment: [String: Any] = [
                        "text": currentSegmentText.trimmingCharacters(in: .whitespaces),
                        "startTime": startTime,
                        "endTime": timestamp,
                        "confidence": 0.9 // CoreML output doesn't provide this directly
                    ]
                    segments.append(segment)
                    currentSegmentText = ""
                }
                // The current timestamp is the start of the next segment.
                startTime = timestamp
            } else {
                // Append the decoded text token to the current segment.
                if let text = decoders[tokenId] {
                    currentSegmentText += decodeBPE(text)
                }
            }
        }
        
        // Add the final segment if any text remains
        if !currentSegmentText.trimmingCharacters(in: .whitespaces).isEmpty {
            let segment: [String: Any] = [
                "text": currentSegmentText.trimmingCharacters(in: .whitespaces),
                "startTime": startTime,
                "endTime": 30.0, // End at the 30-second mark of the audio chunk
                "confidence": 0.9
            ]
            segments.append(segment)
        }
        
        return segments
    }
    
    // MARK: - Token Type Checkers

    private func isTimestamp(_ tokenId: Int) -> Bool {
        return tokenId >= timestampBegin && tokenId <= timestampEnd
    }

    private func isSpecial(_ tokenId: Int) -> Bool {
        return tokenId >= eotToken
    }
    
    // MARK: - BPE Decoding Helper
    
    // This decodes the byte-level representation used by the GPT-2 tokenizer.
    private func decodeBPE(_ token: String) -> String {
        let byteEncoder = Tokenizer.bytesToUnicode()
        let unicodeEncoder = byteEncoder.values.map { $0 }
        let unicodeDecoder = Dictionary(uniqueKeysWithValues: byteEncoder.map { ($1, $0) })
        
        var text = ""
        for char in token {
            if let byte = unicodeDecoder[String(char)] {
                text += String(bytes: [byte], encoding: .utf8) ?? ""
            } else {
                text += String(char)
            }
        }
        return text.replacingOccurrences(of: " ", with: " ")
    }
    
    // Standard byte-to-unicode mapping for GPT-2 tokenizers
    private static func bytesToUnicode() -> [UInt8: String] {
        var mapping: [UInt8: String] = [:]
        var bs = [UInt8]()
        bs += 33...126
        bs += 161...172
        bs += 174...255
        
        var cs = bs
        var n: UInt8 = 0
        for b in 0...255 {
            if !bs.contains(b) {
                bs.append(b)
                cs.append(256 + n)
                n += 1
            }
        }
        
        for (b, c) in zip(bs, cs) {
            mapping[b] = String(UnicodeScalar(Int(c))!)
        }
        return mapping
    }
    
    enum TokenizerError: Error {
        case missingPredictionOutput
    }
}