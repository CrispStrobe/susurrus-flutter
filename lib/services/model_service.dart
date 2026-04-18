// lib/services/model_service.dart (COMPLETE IMPLEMENTATION)
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';
import 'package:archive/archive.dart';

import 'log_service.dart';
import 'settings_service.dart';

class ModelService {
  /// Upstream ggerganov repo — the canonical source for F16 GGML Whisper models.
  static const String whisperCppBaseUrl =
      'https://huggingface.co/ggerganov/whisper.cpp/resolve/main';

  /// Secondary repo under the cstr namespace — used for quantized Whisper
  /// variants (q4_0 / q5_0 / q8_0) and mirrors.
  static const String cstrWhisperCppBaseUrl =
      'https://huggingface.co/cstr/whisper-ggml-quants/resolve/main';

  /// A general-purpose cstr GGUF repo (CrispASR-compatible backends:
  /// Parakeet, Canary, Cohere, Voxtral, Qwen3-ASR, Granite, FastConformer-CTC,
  /// Wav2Vec2). Each backend has its own filename convention — see
  /// `crispasrBackendModels` below.
  static const String cstrCrispBaseUrl =
      'https://huggingface.co/cstr/crispasr-gguf/resolve/main';

  final Dio _dio = Dio();
  late String _modelsDir;
  final SettingsService _settingsService;
  final Map<String, CancelToken> _activeDowloads = {};

  // Enhanced model definitions with proper URLs and checksums
  static const Map<String, ModelDefinition> whisperCppModels = {
    'tiny': ModelDefinition(
      name: 'tiny',
      displayName: 'Whisper Tiny',
      fileName: 'ggml-tiny.bin',
      url: '$whisperCppBaseUrl/ggml-tiny.bin',
      sizeBytes: 74 * 1024 * 1024,
      checksum: 'bd577a113a864445d4c299885e0cb97d4ba92b5f',
      description: 'Fastest model, lower accuracy (~74 MB)',
    ),
    'tiny.en': ModelDefinition(
      name: 'tiny.en',
      displayName: 'Whisper Tiny English',
      fileName: 'ggml-tiny.en.bin',
      url: '$whisperCppBaseUrl/ggml-tiny.en.bin',
      sizeBytes: 74 * 1024 * 1024,
      checksum: 'c78c86eb1a8faa21b369bcd33207cc90d64ae9df',
      description: 'Fastest model for English only (~74 MB)',
    ),
    'base': ModelDefinition(
      name: 'base',
      displayName: 'Whisper Base',
      fileName: 'ggml-base.bin',
      url: '$whisperCppBaseUrl/ggml-base.bin',
      sizeBytes: 142 * 1024 * 1024,
      checksum: '465707469ff3a37a2b9b8d8f89f2f99de7299dac',
      description: 'Balanced speed and accuracy (~142 MB)',
    ),
    'base.en': ModelDefinition(
      name: 'base.en',
      displayName: 'Whisper Base English',
      fileName: 'ggml-base.en.bin',
      url: '$whisperCppBaseUrl/ggml-base.en.bin',
      sizeBytes: 142 * 1024 * 1024,
      checksum: '137c40403d78fd54d454da0f9bd998f78703390c',
      description: 'Balanced model for English only (~142 MB)',
    ),
    'small': ModelDefinition(
      name: 'small',
      displayName: 'Whisper Small',
      fileName: 'ggml-small.bin',
      url: '$whisperCppBaseUrl/ggml-small.bin',
      sizeBytes: 466 * 1024 * 1024,
      checksum: '55356645c2b361a969dfd0ef2c5a50d530afd8d5',
      description: 'Good accuracy with moderate speed (~466 MB)',
    ),
    'small.en': ModelDefinition(
      name: 'small.en',
      displayName: 'Whisper Small English',
      fileName: 'ggml-small.en.bin',
      url: '$whisperCppBaseUrl/ggml-small.en.bin',
      sizeBytes: 466 * 1024 * 1024,
      checksum: 'db8a495a91d927739e50b3fc1cc4c6b8f6c2d022',
      description: 'Good accuracy for English only (~466 MB)',
    ),
    'medium': ModelDefinition(
      name: 'medium',
      displayName: 'Whisper Medium',
      fileName: 'ggml-medium.bin',
      url: '$whisperCppBaseUrl/ggml-medium.bin',
      sizeBytes: 1500 * 1024 * 1024,
      checksum: 'fd9727b6e1217c2f614f9b698455c4ffd82463b4',
      description: 'High accuracy with slower processing (~1.5 GB)',
    ),
    'medium.en': ModelDefinition(
      name: 'medium.en',
      displayName: 'Whisper Medium English',
      fileName: 'ggml-medium.en.bin',
      url: '$whisperCppBaseUrl/ggml-medium.en.bin',
      sizeBytes: 1500 * 1024 * 1024,
      checksum: 'd7440d1dc186f76616787fcdd0b295ef60e88766',
      description: 'High accuracy for English only (~1.5 GB)',
    ),
    'large': ModelDefinition(
      name: 'large',
      displayName: 'Whisper Large',
      fileName: 'ggml-large.bin',
      url: '$whisperCppBaseUrl/ggml-large.bin',
      sizeBytes: 3000 * 1024 * 1024,
      checksum: 'b1caaf735c4cc1429223d5a74f0f4d0b9b59a299',
      description: 'Best accuracy with slowest processing (~3 GB)',
    ),
    'large-v2': ModelDefinition(
      name: 'large-v2',
      displayName: 'Whisper Large v2',
      fileName: 'ggml-large-v2.bin',
      url: '$whisperCppBaseUrl/ggml-large-v2.bin',
      sizeBytes: 3000 * 1024 * 1024,
      checksum: '0f4c8e34f21cf1a914c59d8b3ce882345ad349d6',
      description: 'Improved large model (~3 GB)',
    ),
    'large-v3': ModelDefinition(
      name: 'large-v3',
      displayName: 'Whisper Large v3',
      fileName: 'ggml-large-v3.bin',
      url: '$whisperCppBaseUrl/ggml-large-v3.bin',
      sizeBytes: 3000 * 1024 * 1024,
      checksum: 'ad82bf6a9043ceed055076d0fd39f5f186ff8062',
      description: 'Latest large model with enhanced performance (~3 GB)',
    ),
    'large-v3-turbo': ModelDefinition(
      name: 'large-v3-turbo',
      displayName: 'Whisper Large v3 Turbo',
      fileName: 'ggml-large-v3-turbo.bin',
      url: 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin',
      sizeBytes: 1550 * 1024 * 1024,
      checksum: '',
      description: 'Faster large-v3 variant — ~1.5 GB',
    ),

    // ----- Quantized variants (cstr mirrors) -----
    // These are rough size estimates. Checksums are intentionally empty —
    // size-only validation is used until we have authoritative SHAs.
    'tiny-q5_0': ModelDefinition(
      name: 'tiny-q5_0',
      displayName: 'Whisper Tiny (q5_0)',
      fileName: 'ggml-tiny-q5_0.bin',
      url: '$cstrWhisperCppBaseUrl/ggml-tiny-q5_0.bin',
      sizeBytes: 33 * 1024 * 1024,
      checksum: '',
      description: '5-bit quantized tiny — smaller, ~same accuracy',
      quantization: 'q5_0',
    ),
    'base-q5_0': ModelDefinition(
      name: 'base-q5_0',
      displayName: 'Whisper Base (q5_0)',
      fileName: 'ggml-base-q5_0.bin',
      url: '$cstrWhisperCppBaseUrl/ggml-base-q5_0.bin',
      sizeBytes: 60 * 1024 * 1024,
      checksum: '',
      description: '5-bit quantized base — ~60 MB',
      quantization: 'q5_0',
    ),
    'small-q5_0': ModelDefinition(
      name: 'small-q5_0',
      displayName: 'Whisper Small (q5_0)',
      fileName: 'ggml-small-q5_0.bin',
      url: '$cstrWhisperCppBaseUrl/ggml-small-q5_0.bin',
      sizeBytes: 190 * 1024 * 1024,
      checksum: '',
      description: '5-bit quantized small — ~190 MB',
      quantization: 'q5_0',
    ),
    'medium-q5_0': ModelDefinition(
      name: 'medium-q5_0',
      displayName: 'Whisper Medium (q5_0)',
      fileName: 'ggml-medium-q5_0.bin',
      url: '$cstrWhisperCppBaseUrl/ggml-medium-q5_0.bin',
      sizeBytes: 540 * 1024 * 1024,
      checksum: '',
      description: '5-bit quantized medium — ~540 MB',
      quantization: 'q5_0',
    ),
    'large-v3-q5_0': ModelDefinition(
      name: 'large-v3-q5_0',
      displayName: 'Whisper Large v3 (q5_0)',
      fileName: 'ggml-large-v3-q5_0.bin',
      url: '$cstrWhisperCppBaseUrl/ggml-large-v3-q5_0.bin',
      sizeBytes: 1100 * 1024 * 1024,
      checksum: '',
      description: '5-bit quantized large-v3 — ~1.1 GB',
      quantization: 'q5_0',
    ),
    'large-v3-q4_0': ModelDefinition(
      name: 'large-v3-q4_0',
      displayName: 'Whisper Large v3 (q4_0)',
      fileName: 'ggml-large-v3-q4_0.bin',
      url: '$cstrWhisperCppBaseUrl/ggml-large-v3-q4_0.bin',
      sizeBytes: 880 * 1024 * 1024,
      checksum: '',
      description: '4-bit quantized large-v3 — ~880 MB',
      quantization: 'q4_0',
    ),
    'large-v3-q2_k': ModelDefinition(
      name: 'large-v3-q2_k',
      displayName: 'Whisper Large v3 (q2_k)',
      fileName: 'ggml-large-v3-q2_k.bin',
      url: '$cstrWhisperCppBaseUrl/ggml-large-v3-q2_k.bin',
      sizeBytes: 500 * 1024 * 1024,
      checksum: '',
      description: '2-bit quantized large-v3 — ~500 MB',
      quantization: 'q2_k',
    ),
    'base-q4_0': ModelDefinition(
      name: 'base-q4_0',
      displayName: 'Whisper Base (q4_0)',
      fileName: 'ggml-base-q4_0.bin',
      url: '$cstrWhisperCppBaseUrl/ggml-base-q4_0.bin',
      sizeBytes: 46 * 1024 * 1024,
      checksum: '',
      description: '4-bit quantized base — ~46 MB',
      quantization: 'q4_0',
    ),
    'small-q4_0': ModelDefinition(
      name: 'small-q4_0',
      displayName: 'Whisper Small (q4_0)',
      fileName: 'ggml-small-q4_0.bin',
      url: '$cstrWhisperCppBaseUrl/ggml-small-q4_0.bin',
      sizeBytes: 150 * 1024 * 1024,
      checksum: '',
      description: '4-bit quantized small — ~150 MB',
      quantization: 'q4_0',
    ),
    'base-q8_0': ModelDefinition(
      name: 'base-q8_0',
      displayName: 'Whisper Base (q8_0)',
      fileName: 'ggml-base-q8_0.bin',
      url: '$cstrWhisperCppBaseUrl/ggml-base-q8_0.bin',
      sizeBytes: 78 * 1024 * 1024,
      checksum: '',
      description: '8-bit quantized base — ~78 MB',
      quantization: 'q8_0',
    ),
    'large-v3-q8_0': ModelDefinition(
      name: 'large-v3-q8_0',
      displayName: 'Whisper Large v3 (q8_0)',
      fileName: 'ggml-large-v3-q8_0.bin',
      url: '$cstrWhisperCppBaseUrl/ggml-large-v3-q8_0.bin',
      sizeBytes: 1650 * 1024 * 1024,
      checksum: '',
      description: '8-bit quantized large-v3 — ~1.65 GB',
      quantization: 'q8_0',
    ),
    'large-v3-turbo-german': ModelDefinition(
      name: 'large-v3-turbo-german',
      displayName: 'Whisper Large v3 Turbo (German)',
      fileName: 'ggml-large-v3-turbo-german.bin',
      url: 'https://huggingface.co/cstr/whisper-large-v3-turbo-german-ggml/resolve/main/ggml-model.bin',
      sizeBytes: 1550 * 1024 * 1024,
      checksum: '',
      description: 'Fine-tuned German turbo model — ~1.5 GB',
    ),
  };

  /// Non-Whisper ASR backends CrispASR supports. These download + show up in
  /// the model manager today; full FFI runtime for every one of them is
  /// still being rolled out (tracked in `docs/crispasr-dart-gaps.md`).
  /// The `backend` field names the CrispASR backend id — matches
  /// `crispasr --list-backends`.
  static const Map<String, ModelDefinition> crispasrBackendModels = {
    // Parakeet — NVIDIA TDT, very fast English ASR with word timestamps.
    'parakeet-tdt-0.6b-v3-q4_k': ModelDefinition(
      name: 'parakeet-tdt-0.6b-v3-q4_k',
      displayName: 'Parakeet TDT 0.6B v3 (q4_k)',
      fileName: 'parakeet-tdt-0.6b-v3-q4_k.gguf',
      url: 'https://huggingface.co/cstr/parakeet-tdt-0.6b-v3-GGUF/resolve/main/parakeet-tdt-0.6b-v3-q4_k.gguf',
      sizeBytes: 467 * 1024 * 1024,
      checksum: '',
      description: 'Fast English ASR (NVIDIA Parakeet) — ~467 MB',
      quantization: 'q4_k',
      backend: 'parakeet',
    ),
    // Canary — NVIDIA, translation-capable (X→en, en→X).
    'canary-1b-v2-q5_0': ModelDefinition(
      name: 'canary-1b-v2-q5_0',
      displayName: 'Canary 1B v2 (q5_0)',
      fileName: 'canary-1b-v2-q5_0.gguf',
      url: 'https://huggingface.co/cstr/canary-1b-v2-GGUF/resolve/main/canary-1b-v2-q5_0.gguf',
      sizeBytes: 600 * 1024 * 1024,
      checksum: '',
      description: 'Multilingual ASR with speech-translation — ~600 MB',
      quantization: 'q5_0',
      backend: 'canary',
    ),
    // Cohere — Conformer encoder + transformer decoder.
    'cohere-transcribe-03-2026-q5_0': ModelDefinition(
      name: 'cohere-transcribe-03-2026-q5_0',
      displayName: 'Cohere Transcribe 03-2026 (q5_0)',
      fileName: 'cohere-transcribe-03-2026-q5_0.gguf',
      url: 'https://huggingface.co/cstr/cohere-transcribe-03-2026-GGUF/resolve/main/cohere-transcribe-03-2026-q5_0.gguf',
      sizeBytes: 1200 * 1024 * 1024,
      checksum: '',
      description: 'Cohere high-accuracy ASR — ~1.2 GB',
      quantization: 'q5_0',
      backend: 'cohere',
    ),
    // Voxtral — speech translation (Mistral family).
    'voxtral-mini-3b-2507-q4_k': ModelDefinition(
      name: 'voxtral-mini-3b-2507-q4_k',
      displayName: 'Voxtral Mini 3B 2507 (q4_k)',
      fileName: 'voxtral-mini-3b-2507-q4_k.gguf',
      url: 'https://huggingface.co/cstr/voxtral-mini-3b-2507-GGUF/resolve/main/voxtral-mini-3b-2507-q4_k.gguf',
      sizeBytes: 2500 * 1024 * 1024,
      checksum: '',
      description: 'Speech translation + ASR — ~2.5 GB',
      quantization: 'q4_k',
      backend: 'voxtral',
    ),
    // Voxtral 4B — realtime variant.
    'voxtral-mini-4b-realtime-q4_k': ModelDefinition(
      name: 'voxtral-mini-4b-realtime-q4_k',
      displayName: 'Voxtral Mini 4B realtime (q4_k)',
      fileName: 'voxtral-mini-4b-realtime-q4_k.gguf',
      url: 'https://huggingface.co/cstr/voxtral-mini-4b-realtime-GGUF/resolve/main/voxtral-mini-4b-realtime-q4_k.gguf',
      sizeBytes: 3300 * 1024 * 1024,
      checksum: '',
      description: 'Voxtral realtime tuning — ~3.3 GB',
      quantization: 'q4_k',
      backend: 'voxtral4b',
    ),
    // Qwen3-ASR — 30+ languages incl. Chinese dialects.
    'qwen3-asr-0.6b-q4_k': ModelDefinition(
      name: 'qwen3-asr-0.6b-q4_k',
      displayName: 'Qwen3-ASR 0.6B (q4_k)',
      fileName: 'qwen3-asr-0.6b-q4_k.gguf',
      url: 'https://huggingface.co/cstr/qwen3-asr-0.6b-GGUF/resolve/main/qwen3-asr-0.6b-q4_k.gguf',
      sizeBytes: 380 * 1024 * 1024,
      checksum: '',
      description: 'Multilingual (30+ langs, incl. Chinese dialects) — ~380 MB',
      quantization: 'q4_k',
      backend: 'qwen3',
    ),
    // Granite — IBM's speech model.
    'granite-4.0-1b-speech-q4_k': ModelDefinition(
      name: 'granite-4.0-1b-speech-q4_k',
      displayName: 'Granite 4.0 1B Speech (q4_k)',
      fileName: 'granite-4.0-1b-speech-q4_k.gguf',
      url: 'https://huggingface.co/cstr/granite-speech-4.0-1b-GGUF/resolve/main/granite-4.0-1b-speech-q4_k.gguf',
      sizeBytes: 900 * 1024 * 1024,
      checksum: '',
      description: 'IBM Granite speech — ~900 MB',
      quantization: 'q4_k',
      backend: 'granite',
    ),
    // FastConformer-CTC — low-latency CTC backbone.
    'fastconformer-ctc-en-q4_k': ModelDefinition(
      name: 'fastconformer-ctc-en-q4_k',
      displayName: 'FastConformer CTC (en, q4_k)',
      fileName: 'fastconformer-ctc-en-q4_k.gguf',
      url: 'https://huggingface.co/cstr/stt-en-fastconformer-ctc-large-GGUF/resolve/main/fastconformer-ctc-en-q4_k.gguf',
      sizeBytes: 400 * 1024 * 1024,
      checksum: '',
      description: 'Low-latency CTC ASR (English) — ~400 MB',
      quantization: 'q4_k',
      backend: 'fastconformer-ctc',
    ),
    // Wav2Vec2 — self-supervised speech model.
    'wav2vec2-base-en-q4_k': ModelDefinition(
      name: 'wav2vec2-base-en-q4_k',
      displayName: 'Wav2Vec2 base (en, q4_k)',
      fileName: 'wav2vec2-base-en-q4_k.gguf',
      url: 'https://huggingface.co/cstr/wav2vec2-large-xlsr-53-english-GGUF/resolve/main/wav2vec2-base-en-q4_k.gguf',
      sizeBytes: 100 * 1024 * 1024,
      checksum: '',
      description: 'Self-supervised (facebook/wav2vec2) — ~100 MB',
      quantization: 'q4_k',
      backend: 'wav2vec2',
    ),
    'qwen2-audio-7b-q4_k': ModelDefinition(
      name: 'qwen2-audio-7b-q4_k',
      displayName: 'Qwen2-Audio 7B (q4_k)',
      fileName: 'qwen2-audio-7b-q4_k.gguf',
      url: 'https://huggingface.co/cstr/qwen2-audio-7b-GGUF/resolve/main/qwen2-audio-7b-q4_k.gguf',
      sizeBytes: 4500 * 1024 * 1024,
      checksum: '',
      description: 'Large multilingual audio-LLM — ~4.5 GB',
      quantization: 'q4_k',
      backend: 'qwen2-audio',
    ),
    'canary-1b-v2-f16': ModelDefinition(
      name: 'canary-1b-v2-f16',
      displayName: 'Canary 1B v2 (f16)',
      fileName: 'canary-1b-v2-f16.gguf',
      url: 'https://huggingface.co/cstr/canary-1b-v2-GGUF/resolve/main/canary-1b-v2-f16.gguf',
      sizeBytes: 2000 * 1024 * 1024,
      checksum: '',
      description: 'High-precision Canary 1B — ~2.0 GB',
      quantization: 'f16',
      backend: 'canary',
    ),
  };

  /// HuggingFace repos we probe dynamically to discover every available
  /// quantisation (q4_0, q4_k, q5_0, q5_k, q8_0, f16, …). The static
  /// catalogs above are the offline default; on first open of the model
  /// manager the app calls `refreshAvailableQuants()` and merges new
  /// entries discovered via the HF API.
  static const Map<String, BackendRepo> backendRepos = {
    'whisper': BackendRepo(
      backend: 'whisper',
      repoId: 'cstr/whisper-ggml-quants',
      baseName: 'ggml-',
      displayPrefix: 'Whisper',
      description: 'Whisper (quantised GGML)',
      extension: '.bin',
    ),
    'parakeet': BackendRepo(
      backend: 'parakeet',
      repoId: 'cstr/parakeet-tdt-0.6b-v3-GGUF',
      baseName: 'parakeet-tdt-0.6b-v3',
      displayPrefix: 'Parakeet TDT 0.6B v3',
      description: 'Fast English ASR (NVIDIA Parakeet)',
    ),
    'canary': BackendRepo(
      backend: 'canary',
      repoId: 'cstr/canary-1b-v2-GGUF',
      baseName: 'canary-1b-v2',
      displayPrefix: 'Canary 1B v2',
      description: 'NVIDIA Canary — speech translation',
    ),
    'cohere': BackendRepo(
      backend: 'cohere',
      repoId: 'cstr/cohere-transcribe-03-2026-GGUF',
      baseName: 'cohere-transcribe-03-2026',
      displayPrefix: 'Cohere Transcribe',
      description: 'Cohere high-accuracy ASR',
    ),
    'voxtral': BackendRepo(
      backend: 'voxtral',
      repoId: 'cstr/voxtral-mini-3b-2507-GGUF',
      baseName: 'voxtral-mini-3b-2507',
      displayPrefix: 'Voxtral Mini 3B 2507',
      description: 'Mistral Voxtral — speech translation + ASR',
    ),
    'voxtral4b': BackendRepo(
      backend: 'voxtral4b',
      repoId: 'cstr/voxtral-mini-4b-realtime-GGUF',
      baseName: 'voxtral-mini-4b-realtime',
      displayPrefix: 'Voxtral Mini 4B realtime',
      description: 'Voxtral realtime variant',
    ),
    'qwen3': BackendRepo(
      backend: 'qwen3',
      repoId: 'cstr/qwen3-asr-0.6b-GGUF',
      baseName: 'qwen3-asr-0.6b',
      displayPrefix: 'Qwen3-ASR 0.6B',
      description: 'Multilingual (30+ langs incl. Chinese dialects)',
    ),
    'granite': BackendRepo(
      backend: 'granite',
      repoId: 'cstr/granite-speech-4.0-1b-GGUF',
      baseName: 'granite-4.0-1b-speech',
      displayPrefix: 'Granite 4.0 1B Speech',
      description: 'IBM Granite speech (instruction-tuned)',
    ),
    'fastconformer-ctc': BackendRepo(
      backend: 'fastconformer-ctc',
      repoId: 'cstr/stt-en-fastconformer-ctc-large-GGUF',
      baseName: 'fastconformer-ctc-en',
      displayPrefix: 'FastConformer CTC (en)',
      description: 'Low-latency CTC ASR (English)',
    ),
    'wav2vec2': BackendRepo(
      backend: 'wav2vec2',
      repoId: 'cstr/wav2vec2-large-xlsr-53-english-GGUF',
      baseName: 'wav2vec2-base-en',
      displayPrefix: 'Wav2Vec2 base (en)',
      description: 'Self-supervised (facebook/wav2vec2)',
    ),
  };

  // Live-probed quants, keyed by model name (same as the hardcoded maps).
  // Merged with the static catalog in getWhisperCppModels().
  final Map<String, ModelDefinition> _discoveredModels = {};
  DateTime? _lastProbeAt;

  ModelService(this._settingsService) {
    _configureDio();
  }

  void _configureDio() {
    _dio.options = BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 30),
      sendTimeout: const Duration(minutes: 30),
      headers: {
        'User-Agent': 'CrisperWeaver-Flutter/1.0.0',
      },
    );

    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestHeader: true,
        requestBody: false,
        responseHeader: true,
        responseBody: true,
        error: true,
        logPrint: (obj) => Log.instance.d('dio', obj.toString()),
      ));
    }

    // Add interceptors for debugging and retry logic
    _dio.interceptors.add(
      RetryInterceptor(
        dio: _dio,
        options: const RetryOptions(
          retries: 3,
          retryInterval: Duration(seconds: 2),
        ),
      ),
    );
  }

  Future<void> initialize() async {
    final appDir = await getApplicationDocumentsDirectory();
    _modelsDir = path.join(appDir.path, 'models');
    await Directory(_modelsDir).create(recursive: true);

    // Create subdirectories
    await Directory(path.join(_modelsDir, 'whisper_cpp')).create(recursive: true);
  }

  /// Get available Whisper.cpp models with download status
  Future<List<ModelInfo>> getWhisperCppModels() async {
    await initialize();

    final modelInfos = <ModelInfo>[];

    for (final entry in whisperCppModels.entries) {
      final modelDef = entry.value;
      final localPath = path.join(_modelsDir, 'whisper_cpp', modelDef.fileName);
      final isDownloaded = await _isModelDownloaded(localPath, modelDef);

      modelInfos.add(ModelInfo(
        name: modelDef.name,
        displayName: modelDef.displayName,
        size: _formatSize(modelDef.sizeBytes),
        sizeBytes: modelDef.sizeBytes,
        isDownloaded: isDownloaded,
        localPath: isDownloaded ? localPath : null,
        description: modelDef.description,
        modelType: ModelType.whisperCpp,
        quantization: modelDef.quantization,
        backend: modelDef.backend,
      ));
    }

    // Non-Whisper CrispASR backends. They share the same on-disk directory
    // since each file is just a GGUF blob, but their `backend` field tells
    // the engine which runtime path to dispatch to. We merge discovered
    // quants on top of the hardcoded defaults, keyed by model name.
    final merged = <String, ModelDefinition>{
      ...crispasrBackendModels,
      ..._discoveredModels,
    };
    for (final entry in merged.entries) {
      final modelDef = entry.value;
      final localPath = path.join(_modelsDir, 'whisper_cpp', modelDef.fileName);
      final isDownloaded = await _isModelDownloaded(localPath, modelDef);

      modelInfos.add(ModelInfo(
        name: modelDef.name,
        displayName: modelDef.displayName,
        size: _formatSize(modelDef.sizeBytes),
        sizeBytes: modelDef.sizeBytes,
        isDownloaded: isDownloaded,
        localPath: isDownloaded ? localPath : null,
        description: modelDef.description,
        modelType: ModelType.whisperCpp,
        quantization: modelDef.quantization,
        backend: modelDef.backend,
      ));
    }

    return modelInfos;
  }

  /// Unified lookup — finds a model by name across every catalog including
  /// quants probed from HuggingFace. Live-probed entries take precedence
  /// so their exact byte-sizes overwrite the rounded catalog estimates.
  ModelDefinition? lookupDefinition(String name) {
    return _discoveredModels[name] ??
        whisperCppModels[name] ??
        crispasrBackendModels[name];
  }

  /// Whether a probe has succeeded at least once in this session.
  bool get hasProbedQuants => _lastProbeAt != null;
  DateTime? get lastQuantProbeAt => _lastProbeAt;

  /// Enumerate every available quant variant in each CrispASR backend's
  /// HuggingFace repo via `GET /api/models/<repo>`. Results are merged
  /// into the model picker on success; on error we fall back to the
  /// hardcoded catalog and log.
  ///
  /// Returns the total number of freshly-discovered ModelDefinitions
  /// (can be 0 if every file was already in the hardcoded catalog).
  Future<int> refreshAvailableQuants() async {
    int added = 0;
    for (final repo in backendRepos.values) {
      try {
        final models = await _probeRepo(repo);
        for (final m in models) {
          final existed = _discoveredModels.containsKey(m.name) ||
              crispasrBackendModels.containsKey(m.name) ||
              whisperCppModels.containsKey(m.name);
          _discoveredModels[m.name] = m;
          if (!existed) added++;
        }
        Log.instance.i('model',
            'Probed ${repo.repoId}: ${models.length} variants');
      } catch (e, st) {
        Log.instance.w('model', 'Quant probe failed for ${repo.repoId}',
            error: e, stack: st);
      }
    }
    _lastProbeAt = DateTime.now();
    return added;
  }

  Future<List<ModelDefinition>> _probeRepo(BackendRepo repo) async {
    final headers = <String, dynamic>{};
    final token = hfToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    // `?blobs=true` surfaces per-file sizes in a stable shape.
    final url = 'https://huggingface.co/api/models/${repo.repoId}?blobs=true';
    final resp = await _dio.get(url, options: Options(headers: headers));
    if (resp.data is! Map) return const [];
    final siblings = ((resp.data as Map)['siblings'] as List?) ?? const [];

    final out = <ModelDefinition>[];
    for (final raw in siblings) {
      if (raw is! Map) continue;
      final fname = raw['rfilename'] as String? ?? '';
      if (!fname.endsWith(repo.extension)) continue;
      // Expect "<baseName>-<quant><extension>" or plain "<baseName><extension>".
      final stem = fname.substring(0, fname.length - repo.extension.length);
      String? quant;
      String modelNameKey;
      if (stem == repo.baseName) {
        quant = 'f16';
        modelNameKey = '${repo.baseName}-f16';
      } else if (stem.startsWith('${repo.baseName}-')) {
        quant = stem.substring(repo.baseName.length + 1);
        modelNameKey = '${repo.baseName}-$quant';
      } else {
        // Skip files that don't follow the expected naming convention.
        continue;
      }
      final sizeBytes = (raw['size'] as num?)?.toInt() ?? 0;
      out.add(ModelDefinition(
        name: modelNameKey,
        displayName: '${repo.displayPrefix} ($quant)',
        fileName: fname,
        url: 'https://huggingface.co/${repo.repoId}/resolve/main/$fname',
        sizeBytes: sizeBytes,
        checksum: '',
        description: '${repo.description} — ${_formatSize(sizeBytes)}',
        quantization: quant,
        backend: repo.backend,
      ));
    }
    return out;
  }

  /// Whether the user has disabled SHA-1 checksum validation for downloads.
  bool get skipChecksum => _settingsService.skipChecksum;

  /// Hugging Face API token for gated/private repositories.
  String? get hfToken => _settingsService.hfToken;
  set hfToken(String? value) {
    _settingsService.hfToken = value ?? '';
  }

  /// Download a Whisper.cpp model with comprehensive error handling
  Future<bool> downloadWhisperCppModel(
    String modelName, {
    void Function(double progress)? onProgress,
    void Function(String status)? onStatusChange,
  }) async {
    await initialize();

    final modelDef = lookupDefinition(modelName);
    if (modelDef == null) {
      throw ModelException('Unknown Whisper.cpp model: $modelName');
    }

    final modelDir = path.join(_modelsDir, 'whisper_cpp');
    final localPath = path.join(modelDir, modelDef.fileName);
    final tempPath = '$localPath.tmp';

    // Check if already downloaded and valid
    if (await _isModelDownloaded(localPath, modelDef)) {
      onProgress?.call(1.0);
      onStatusChange?.call('Model already downloaded');
      return true;
    }

    // Check if download is already in progress
    if (_activeDowloads.containsKey(modelName)) {
      throw ModelException('Download already in progress for $modelName');
    }

    final cancelToken = CancelToken();
    _activeDowloads[modelName] = cancelToken;

    try {
      onStatusChange?.call('Checking available space...');

      // Check available space
      final freeSpace = await _getAvailableSpace();
      if (freeSpace < modelDef.sizeBytes * 1.2) {
        throw ModelException(
          'Insufficient storage space. Need ${_formatSize(modelDef.sizeBytes)}, '
          'have ${_formatSize(freeSpace)}'
        );
      }

      onStatusChange?.call('Starting download...');
      onProgress?.call(0.0);

      final dlDone = Log.instance.stopwatch('model',
          msg: 'download done',
          fields: {
            'name': modelName,
            'url': modelDef.url,
            'expected_bytes': modelDef.sizeBytes,
            'backend': modelDef.backend,
            'quant': modelDef.quantization,
            'target': tempPath,
          });
      Log.instance.i('model', 'download start', fields: {
        'name': modelName,
        'url': modelDef.url,
        'expected_bytes': modelDef.sizeBytes,
        'backend': modelDef.backend,
        'quant': modelDef.quantization,
      });

      // Download with resume capability
      try {
        await _downloadWithResume(
          modelDef.url,
          tempPath,
          expectedSize: modelDef.sizeBytes,
          onProgress: onProgress,
          onStatusChange: onStatusChange,
          cancelToken: cancelToken,
        );
        int realBytes = 0;
        try { realBytes = await File(tempPath).length(); } catch (_) {}
        dlDone(extra: {'actual_bytes': realBytes});
      } catch (e) {
        dlDone(error: e);
        rethrow;
      }

      onStatusChange?.call('Verifying download...');
      onProgress?.call(0.95);

      // Verify download
      if (modelDef.checksum.isNotEmpty && !skipChecksum) {
        final isValid = await _verifyChecksum(tempPath, modelDef.checksum);
        if (!isValid) {
          await File(tempPath).delete();
          Log.instance.w('model', 'Checksum mismatch for $modelName');
          throw ModelException(
              'Download verification failed. File may be corrupted. '
              'Enable "Skip checksum verification" in Settings → Debugging to bypass.');
        }
      } else if (skipChecksum) {
        Log.instance.i('model', 'Skipping checksum for $modelName (user override)');
      }

      // Move temp file to final location
      await File(tempPath).rename(localPath);

      onProgress?.call(1.0);
      onStatusChange?.call('Download complete');
      return true;

    } catch (e) {
      // Cleanup on failure
      await _cleanupTempFile(tempPath);

      if (e is DioException) {
        final resp = e.response;
        Log.instance.e('model', 'DioException during download: ${e.type}');
        if (resp != null) {
          Log.instance.e('model', 'HTTP ${resp.statusCode} for ${e.requestOptions.uri}');
          Log.instance.e('model', 'Headers: ${resp.headers}');
          Log.instance.e('model', 'Body: ${resp.data}');
        } else {
          Log.instance.e('model', 'No response for ${e.requestOptions.uri}');
        }

        if (e.type == DioExceptionType.cancel) {
          throw ModelException('Download cancelled');
        } else if (e.type == DioExceptionType.connectionTimeout) {
          throw ModelException('Download timeout. Please check your internet connection.');
        } else if (e.response?.statusCode == 404) {
          throw ModelException('Model not found on server');
        } else if (e.response?.statusCode == 401) {
          throw ModelException('Authentication required (401). This model repository is private or gated.');
        } else {
          throw ModelException('Download failed: ${e.message}');
        }
      }

      throw ModelException('Failed to download model: $e');
    } finally {
      _activeDowloads.remove(modelName);
    }
  }

  /// Cancel an ongoing download
  Future<void> cancelDownload(String modelName, {ModelType? modelType}) async {
    final cancelToken = _activeDowloads[modelName];
    if (cancelToken != null) {
      cancelToken.cancel('Download cancelled by user');
      _activeDowloads.remove(modelName);
    }
  }

  /// Download with resume capability and comprehensive error handling
  Future<void> _downloadWithResume(
    String url,
    String savePath, {
    required int expectedSize,
    void Function(double progress)? onProgress,
    void Function(String status)? onStatusChange,
    CancelToken? cancelToken,
  }) async {
    final file = File(savePath);
    int downloadedBytes = 0;

    // Check if partial download exists
    if (await file.exists()) {
      downloadedBytes = await file.length();
      onStatusChange?.call('Resuming download...');
    }

    // Set range header for resume
    final headers = <String, dynamic>{
      'Accept': '*/*',
      'Accept-Encoding': 'identity', // Disable compression for resume
    };

    if (downloadedBytes > 0 && downloadedBytes < expectedSize) {
      headers['Range'] = 'bytes=$downloadedBytes-';
    }

    final token = hfToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    Log.instance.d('model', 'Request headers: $headers');

    int lastProgressUpdate = DateTime.now().millisecondsSinceEpoch;

    await _dio.download(
      url,
      savePath,
      options: Options(headers: headers),
      cancelToken: cancelToken,
      onReceiveProgress: (received, total) {
        final now = DateTime.now().millisecondsSinceEpoch;
        
        // Throttle progress updates to avoid UI spam
        if (now - lastProgressUpdate < 100) return;
        lastProgressUpdate = now;

        final totalBytes = downloadedBytes + received;
        final progress = total > 0 ? totalBytes / expectedSize : totalBytes / expectedSize;

        onProgress?.call(progress.clamp(0.0, 1.0));

        // Update status periodically
        if (totalBytes % (1024 * 1024) < 100 * 1024) { // Every MB
          final downloadedMB = totalBytes / (1024 * 1024);
          final totalMB = expectedSize / (1024 * 1024);
          final speed = _calculateDownloadSpeed(totalBytes, DateTime.now());
          onStatusChange?.call(
            'Downloaded ${downloadedMB.toStringAsFixed(1)} MB of ${totalMB.toStringAsFixed(1)} MB ($speed)'
          );
        }
      },
    );

    // Verify final file size. Hardcoded catalog entries rounded to the
    // nearest MB so we tolerate up to 5% (or 2 MB, whichever larger)
    // undershoot before declaring the download incomplete — Dio already
    // bubbles up real HTTP errors, so at this point a non-zero length
    // file is almost always a complete download that just disagrees
    // with our estimate.
    final finalSize = await file.length();
    if (expectedSize > 0 && finalSize < expectedSize) {
      final diff = expectedSize - finalSize;
      final tolerance = (expectedSize * 0.05).ceil();
      final absTolerance = tolerance > 2 * 1024 * 1024 ? tolerance : 2 * 1024 * 1024;
      if (diff > absTolerance) {
        await file.delete();
        throw ModelException(
          'Download incomplete. Expected at least $expectedSize bytes, got $finalSize bytes',
        );
      }
      Log.instance.w(
        'model',
        'Download finished at $finalSize bytes, expected $expectedSize '
        '(diff ${_formatSize(diff)}); accepting within tolerance.',
      );
    }
  }

  DateTime? _speedStart;
  int _speedStartBytes = 0;

  String _calculateDownloadSpeed(int bytesDownloaded, DateTime currentTime) {
    _speedStart ??= currentTime;

    final elapsed = currentTime.difference(_speedStart!).inSeconds;
    if (elapsed <= 0) return '';

    final speed = (bytesDownloaded - _speedStartBytes) / elapsed;
    if (speed < 1024) {
      return '${speed.toStringAsFixed(0)} B/s';
    } else if (speed < 1024 * 1024) {
      return '${(speed / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
  }

  /// Verify file checksum using SHA-1
  Future<bool> _verifyChecksum(String filePath, String expectedChecksum) async {
    if (expectedChecksum.isEmpty) return true;

    final file = File(filePath);
    if (!await file.exists()) return false;

    // Use isolate for CPU-intensive checksum calculation
    final result = await Isolate.run(() async {
      final bytes = await File(filePath).readAsBytes();
      final digest = sha1.convert(bytes);
      return digest.toString();
    });

    return result.toLowerCase() == expectedChecksum.toLowerCase();
  }

  /// Get model path if downloaded and valid
  Future<String?> getWhisperCppModelPath(String modelName) async {
    await initialize();

    final modelDef = lookupDefinition(modelName);
    if (modelDef == null) return null;

    final localPath = path.join(_modelsDir, 'whisper_cpp', modelDef.fileName);

    if (await _isModelDownloaded(localPath, modelDef)) {
      return localPath;
    }

    return null;
  }

  /// Delete a model with proper cleanup
  Future<bool> deleteModel(String modelName, {ModelType? modelType}) async {
    await initialize();

    // Cancel any ongoing downloads first.
    await cancelDownload(modelName, modelType: modelType);

    final whisperPath = await getWhisperCppModelPath(modelName);
    if (whisperPath != null) {
      await File(whisperPath).delete();
      return true;
    }

    return false;
  }

  /// Get total storage used by models
  Future<StorageInfo> getStorageInfo() async {
    await initialize();

    int whisperCppSize = 0;
    final whisperDir = Directory(path.join(_modelsDir, 'whisper_cpp'));
    if (await whisperDir.exists()) {
      whisperCppSize = await _getDirectorySize(whisperDir.path);
    }

    return StorageInfo(
      whisperCppBytes: whisperCppSize,
      totalBytes: whisperCppSize,
    );
  }

  /// Clear all model cache
  Future<void> clearAllModels() async {
    await initialize();

    // Cancel all downloads first
    for (final entry in _activeDowloads.entries) {
      entry.value.cancel('Clearing all models');
    }
    _activeDowloads.clear();

    final modelsDir = Directory(_modelsDir);
    if (await modelsDir.exists()) {
      await modelsDir.delete(recursive: true);
      await modelsDir.create(recursive: true);

      // Recreate subdirectories
      await Directory(path.join(_modelsDir, 'whisper_cpp')).create();
    }
  }

  // Private helper methods

  Future<bool> _isModelDownloaded(String localPath, ModelDefinition modelDef) async {
    final file = File(localPath);
    if (!await file.exists()) return false;

    final size = await file.length();

    // Check size matches (within 1% tolerance)
    final sizeDiff = (size - modelDef.sizeBytes).abs();
    final tolerance = modelDef.sizeBytes * 0.01;

    if (sizeDiff > tolerance) return false;

    // For critical models, verify checksum — unless the user has explicitly
    // opted into skipping verification.
    if (!skipChecksum &&
        modelDef.checksum.isNotEmpty &&
        modelDef.sizeBytes > 100 * 1024 * 1024) {
      return await _verifyChecksum(localPath, modelDef.checksum);
    }

    return true;
  }


  Future<void> _cleanupTempFile(String tempPath) async {
    try {
      final file = File(tempPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  Future<void> _cleanupDirectory(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  Future<int> _getAvailableSpace() async {
    // On mobile platforms, this is an approximation
    // You might want to use a plugin like device_info_plus for more accurate info
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final stat = await appDir.stat();
      // This is a rough estimate - in production use platform-specific APIs
      return 5 * 1024 * 1024 * 1024; // Assume 5GB available
    } catch (e) {
      return 5 * 1024 * 1024 * 1024; // Default to 5GB
    }
  }

  Future<int> _getDirectorySize(String directoryPath) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) return 0;

    int totalSize = 0;
    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) {
        try {
          final stat = await entity.stat();
          totalSize += stat.size;
        } catch (e) {
          // Skip files that can't be accessed
        }
      }
    }

    return totalSize;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

// Enhanced data classes and exceptions

class ModelDefinition {
  final String name;
  final String displayName;
  final String fileName;
  final String url;
  final int sizeBytes;
  final String checksum;
  final String description;
  final String quantization; // 'f16', 'q4_0', 'q5_0', 'q8_0', ''
  /// The CrispASR backend id that owns this model — see
  /// `crispasr --list-backends`. Default 'whisper' for the vanilla GGML
  /// Whisper models we ship.
  final String backend;

  const ModelDefinition({
    required this.name,
    required this.displayName,
    required this.fileName,
    required this.url,
    required this.sizeBytes,
    required this.checksum,
    required this.description,
    this.quantization = 'f16',
    this.backend = 'whisper',
  });
}

/// Points at a HuggingFace repo that the model service can enumerate to
/// discover every available quantisation variant.
class BackendRepo {
  final String backend;       // CrispASR backend id
  final String repoId;        // e.g. "cstr/parakeet-tdt-0.6b-v3-GGUF"
  final String baseName;      // filename stem without -quant; e.g. "parakeet-tdt-0.6b-v3"
  final String displayPrefix; // UI-friendly name; e.g. "Parakeet TDT 0.6B v3"
  final String description;
  final String extension;     // typically ".gguf", Whisper uses ".bin"

  const BackendRepo({
    required this.backend,
    required this.repoId,
    required this.baseName,
    required this.displayPrefix,
    required this.description,
    this.extension = '.gguf',
  });
}

class ModelInfo {
  final String name;
  final String displayName;
  final String size;
  final int sizeBytes;
  final bool isDownloaded;
  final String? localPath;
  final String description;
  final ModelType modelType;
  final String quantization;
  final String backend;
  /// Human-readable runtime status — "Ready" when the bundled libwhisper
  /// can execute this model today, or an explanation of what's missing.
  /// Filled in by the UI based on engine capability probing.
  final String? runtimeStatus;

  const ModelInfo({
    required this.name,
    required this.displayName,
    required this.size,
    required this.sizeBytes,
    required this.isDownloaded,
    this.localPath,
    required this.description,
    required this.modelType,
    this.quantization = 'f16',
    this.backend = 'whisper',
    this.runtimeStatus,
  });
}

enum ModelType {
  whisperCpp,
}

class StorageInfo {
  final int whisperCppBytes;
  final int totalBytes;

  const StorageInfo({
    required this.whisperCppBytes,
    required this.totalBytes,
  });

  String get formattedWhisperCpp => _formatSize(whisperCppBytes);
  String get formattedTotal => _formatSize(totalBytes);

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class ModelException implements Exception {
  final String message;
  const ModelException(this.message);

  @override
  String toString() => 'ModelException: $message';
}

// Retry interceptor for Dio
class RetryInterceptor extends Interceptor {
  final Dio dio;
  final RetryOptions options;

  RetryInterceptor({required this.dio, required this.options});

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final extra = RetryOptions.fromExtra(err.requestOptions) ?? options;

    if (extra.retries <= 0) {
      return handler.next(err);
    }

    if (err.type == DioExceptionType.cancel) {
      return handler.next(err);
    }

    await Future.delayed(extra.retryInterval);

    final requestOptions = err.requestOptions;
    requestOptions.extra[RetryOptions.extraKey] = extra.copyWith(retries: extra.retries - 1);

    try {
      final response = await dio.fetch(requestOptions);
      return handler.resolve(response);
    } catch (e) {
      return handler.next(err);
    }
  }
}

class RetryOptions {
  static const String extraKey = 'retry_options';
  
  final int retries;
  final Duration retryInterval;

  const RetryOptions({
    required this.retries,
    required this.retryInterval,
  });

  static RetryOptions? fromExtra(RequestOptions request) {
    return request.extra[extraKey] as RetryOptions?;
  }

  RetryOptions copyWith({int? retries, Duration? retryInterval}) {
    return RetryOptions(
      retries: retries ?? this.retries,
      retryInterval: retryInterval ?? this.retryInterval,
    );
  }
}