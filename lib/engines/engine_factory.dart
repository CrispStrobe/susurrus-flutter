import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'transcription_engine.dart';
import 'mock_engine.dart';
import 'whisper_cpp_engine.dart';
import 'coreml_engine.dart';
import 'crispasr_engine.dart';

/// Available transcription engine types.
///
/// `Sherpa ONNX` was previously listed here but was never implemented; it's
/// been removed to avoid advertising capabilities the app doesn't have. If
/// we want ONNX-based ASR in the future, add it back here + create an
/// `EngineFactory._creators` entry + a concrete `TranscriptionEngine` impl.
enum EngineType {
  mock('mock', 'Mock Engine', 'Testing engine with simulated responses'),
  crispasr('crispasr', 'CrispASR (ggml)', 'On-device ASR via the CrispASR FFI runtime'),
  whisperCpp('whisper_cpp', 'Whisper.cpp', 'Cross-platform Whisper implementation (method channel)'),
  coreML('coreml', 'CoreML Whisper', 'Apple CoreML optimized engine');

  const EngineType(this.id, this.displayName, this.description);
  
  final String id;
  final String displayName;
  final String description;
}

/// Factory for creating transcription engines
class EngineFactory {
  static final Map<EngineType, TranscriptionEngine Function()> _creators = {
    EngineType.mock: () => MockEngine(),
    EngineType.crispasr: () => CrispASREngine(),
    EngineType.whisperCpp: () => WhisperCppEngine(),
    EngineType.coreML: () => CoreMLEngine(),
  };

  /// Create an engine instance
  static TranscriptionEngine create(EngineType type) {
    final creator = _creators[type];
    if (creator == null) {
      throw UnsupportedError('Engine type $type is not implemented');
    }
    return creator();
  }

  /// Get available engines for current platform
  static List<EngineType> getAvailableEngines() {
    // CrispASR and Mock work everywhere; native-plugin engines are
    // gated on the platform that provides their plugin.
    final available = <EngineType>[EngineType.crispasr, EngineType.mock];

    if (Platform.isIOS) {
      available.addAll([
        EngineType.whisperCpp,
        EngineType.coreML,
      ]);
    } else if (Platform.isAndroid) {
      available.add(EngineType.whisperCpp);
    } else if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
      // Desktop runs the CrispASR FFI runtime; no extra engines yet.
    }

    return available;
  }

  /// Check if engine type is supported on current platform
  static bool isSupported(EngineType type) {
    return getAvailableEngines().contains(type);
  }

  /// Get recommended engine for current platform
  static EngineType getRecommendedEngine() {
    // CrispASR is the default cross-platform engine; we fall back to the
    // platform-specific plugins when the app is built with them.
    return EngineType.crispasr;
  }
}

/// Engine manager for handling engine lifecycle and selection
class EngineManager {
  TranscriptionEngine? _currentEngine;
  EngineType? _currentEngineType;

  /// Currently active engine
  TranscriptionEngine? get currentEngine => _currentEngine;
  EngineType? get currentEngineType => _currentEngineType;
  
  bool get hasActiveEngine => _currentEngine != null;

  /// Switch to a different engine
  Future<bool> switchEngine(EngineType type, {Map<String, dynamic>? config}) async {
    try {
      // Dispose current engine
      await _currentEngine?.dispose();
      
      // Create new engine
      _currentEngine = EngineFactory.create(type);
      _currentEngineType = type;
      
      // Initialize new engine
      final success = await _currentEngine!.initialize(config: config);
      
      if (!success) {
        await _currentEngine?.dispose();
        _currentEngine = null;
        _currentEngineType = null;
        return false;
      }
      
      return true;
    } catch (e) {
      // Cleanup on failure
      await _currentEngine?.dispose();
      _currentEngine = null;
      _currentEngineType = null;
      return false;
    }
  }

  /// Initialize with recommended engine
  Future<bool> initializeWithRecommended({Map<String, dynamic>? config}) async {
    final recommended = EngineFactory.getRecommendedEngine();
    return await switchEngine(recommended, config: config);
  }

  /// Initialize with mock engine (for testing)
  Future<bool> initializeWithMock({Map<String, dynamic>? config}) async {
    return await switchEngine(EngineType.mock, config: config);
  }

  /// Dispose current engine
  Future<void> dispose() async {
    await _currentEngine?.dispose();
    _currentEngine = null;
    _currentEngineType = null;
  }

  /// Get available engines for selection UI
  List<EngineInfo> getAvailableEnginesInfo() {
    return EngineFactory.getAvailableEngines()
        .map((type) => EngineInfo(
              type: type,
              isActive: type == _currentEngineType,
              isSupported: EngineFactory.isSupported(type),
            ))
        .toList();
  }
}

/// Engine information for UI display
class EngineInfo {
  final EngineType type;
  final bool isActive;
  final bool isSupported;

  const EngineInfo({
    required this.type,
    required this.isActive,
    required this.isSupported,
  });

  String get displayName => type.displayName;
  String get description => type.description;
  String get id => type.id;
}

/// Riverpod providers for engine management
final engineManagerProvider = StateNotifierProvider<EngineManagerNotifier, EngineManagerState>((ref) {
  return EngineManagerNotifier();
});

/// Engine manager state
class EngineManagerState {
  final EngineManager manager;
  final EngineType? currentEngine;
  final bool isInitialized;
  final bool isInitializing;
  final String? error;

  const EngineManagerState({
    required this.manager,
    this.currentEngine,
    this.isInitialized = false,
    this.isInitializing = false,
    this.error,
  });

  EngineManagerState copyWith({
    EngineManager? manager,
    EngineType? currentEngine,
    bool? isInitialized,
    bool? isInitializing,
    String? error,
  }) {
    return EngineManagerState(
      manager: manager ?? this.manager,
      currentEngine: currentEngine ?? this.currentEngine,
      isInitialized: isInitialized ?? this.isInitialized,
      isInitializing: isInitializing ?? this.isInitializing,
      error: error,
    );
  }
}

/// Engine manager state notifier
class EngineManagerNotifier extends StateNotifier<EngineManagerState> {
  EngineManagerNotifier() : super(EngineManagerState(manager: EngineManager()));

  /// Initialize with mock engine (safe for testing)
  Future<void> initializeWithMock() async {
    state = state.copyWith(isInitializing: true, error: null);
    
    try {
      final success = await state.manager.initializeWithMock();
      
      if (success) {
        state = state.copyWith(
          currentEngine: EngineType.mock,
          isInitialized: true,
          isInitializing: false,
        );
      } else {
        state = state.copyWith(
          isInitializing: false,
          error: 'Failed to initialize mock engine',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isInitializing: false,
        error: 'Error initializing mock engine: $e',
      );
    }
  }

  /// Switch to different engine
  Future<void> switchEngine(EngineType type, {Map<String, dynamic>? config}) async {
    state = state.copyWith(isInitializing: true, error: null);
    
    try {
      final success = await state.manager.switchEngine(type, config: config);
      
      if (success) {
        state = state.copyWith(
          currentEngine: type,
          isInitialized: true,
          isInitializing: false,
        );
      } else {
        state = state.copyWith(
          isInitializing: false,
          error: 'Failed to switch to $type engine',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isInitializing: false,
        error: 'Error switching to $type engine: $e',
      );
    }
  }

  /// Dispose engine manager
  @override
  void dispose() {
    state.manager.dispose();
    super.dispose();
  }
}