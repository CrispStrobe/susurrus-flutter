import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'screens/transcription_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/model_management_screen.dart';
import 'services/audio_service.dart';
import 'services/transcription_service.dart';
import 'theme/app_theme.dart';
import 'engines/engine_factory.dart';

// Engine manager provider
final engineManagerProvider = StateNotifierProvider<EngineManagerNotifier, EngineManagerState>((ref) {
  return EngineManagerNotifier();
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Request necessary permissions
  await _requestPermissions();
  
  // Initialize services
  await _initializeServices();
  
  runApp(
    ProviderScope(
      child: SusurrusApp(),
    ),
  );
}

Future<void> _requestPermissions() async {
  final permissions = [
    Permission.microphone,
    Permission.storage,
    Permission.manageExternalStorage,
  ];
  
  await permissions.request();
}

Future<void> _initializeServices() async {
  // Initialize path providers and other async services
  await getApplicationDocumentsDirectory();
}

class SusurrusApp extends ConsumerWidget {
  SusurrusApp({super.key});

  final _router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const TranscriptionScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/models',
        name: 'models',
        builder: (context, state) => const ModelManagementScreen(),
      ),
    ],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Susurrus',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: _router,
    );
  }
}

// Global providers
final audioServiceProvider = Provider<AudioService>((ref) {
  return AudioService();
});

final transcriptionServiceProvider = Provider<TranscriptionService>((ref) {
  final audioService = ref.watch(audioServiceProvider);
  return TranscriptionService(audioService);
});

// App state providers
final currentTranscriptionProvider = StateProvider<String?>((ref) => null);
final isTranscribingProvider = StateProvider<bool>((ref) => false);
final transcriptionProgressProvider = StateProvider<double>((ref) => 0.0);

class AppState {
  final String? currentTranscription;
  final bool isTranscribing;
  final double progress;
  final String? errorMessage;
  final List<TranscriptionSegment> segments;
  
  const AppState({
    this.currentTranscription,
    this.isTranscribing = false,
    this.progress = 0.0,
    this.errorMessage,
    this.segments = const [],
  });
  
  AppState copyWith({
    String? currentTranscription,
    bool? isTranscribing,
    double? progress,
    String? errorMessage,
    List<TranscriptionSegment>? segments,
  }) {
    return AppState(
      currentTranscription: currentTranscription ?? this.currentTranscription,
      isTranscribing: isTranscribing ?? this.isTranscribing,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      segments: segments ?? this.segments,
    );
  }
}

class TranscriptionSegment {
  final String text;
  final double startTime;
  final double endTime;
  final String? speaker;
  final double confidence;
  
  const TranscriptionSegment({
    required this.text,
    required this.startTime,
    required this.endTime,
    this.speaker,
    this.confidence = 1.0,
  });
  
  String get formattedTime {
    final start = _formatTime(startTime);
    final end = _formatTime(endTime);
    return '[$start -> $end]';
  }
  
  String _formatTime(double seconds) {
    final minutes = (seconds / 60).floor();
    final secs = (seconds % 60);
    return '${minutes.toString().padLeft(2, '0')}:${secs.toStringAsFixed(3).padLeft(6, '0')}';
  }
  
  @override
  String toString() {
    final speakerPrefix = speaker != null ? '$speaker: ' : '';
    return '$formattedTime $speakerPrefix$text';
  }
}

final appStateProvider = StateNotifierProvider<AppStateNotifier, AppState>((ref) {
  return AppStateNotifier();
});

class AppStateNotifier extends StateNotifier<AppState> {
  AppStateNotifier() : super(const AppState());
  
  void startTranscription() {
    state = state.copyWith(
      isTranscribing: true,
      progress: 0.0,
      errorMessage: null,
    );
  }
  
  void updateProgress(double progress) {
    state = state.copyWith(progress: progress);
  }
  
  void addSegment(TranscriptionSegment segment) {
    final updatedSegments = [...state.segments, segment];
    final fullText = updatedSegments.map((s) => s.text).join(' ');
    
    state = state.copyWith(
      segments: updatedSegments,
      currentTranscription: fullText,
    );
  }
  
  void completeTranscription(List<TranscriptionSegment> segments) {
    final fullText = segments.map((s) => s.text).join(' ');
    
    state = state.copyWith(
      isTranscribing: false,
      segments: segments,
      currentTranscription: fullText,
      progress: 1.0,
    );
  }
  
  void setError(String error) {
    state = state.copyWith(
      isTranscribing: false,
      errorMessage: error,
    );
  }
  
  void clearTranscription() {
    state = const AppState();
  }
}