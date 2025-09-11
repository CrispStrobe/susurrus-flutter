// lib/main.dart - FIXED VERSION
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
import 'engines/transcription_engine.dart'; // Use engine TranscriptionSegment

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _requestPermissions();
  await _initializeServices();

  runApp(ProviderScope(child: SusurrusApp()));
}

Future<void> _requestPermissions() async {
  final permissions = [
    Permission.microphone,
    Permission.storage,
  ];

  // Request additional permissions on Android
  if (Theme.of(WidgetsBinding.instance.platformDispatcher.platformBrightness.index == 0 ?
      TargetPlatform.android : TargetPlatform.iOS) == TargetPlatform.android) {
    permissions.add(Permission.manageExternalStorage);
  }

  await permissions.request();
}

Future<void> _initializeServices() async {
  try {
    await getApplicationDocumentsDirectory();
  } catch (e) {
    debugPrint('Failed to initialize services: $e');
  }
}

class SusurrusApp extends ConsumerWidget {
  SusurrusApp({super.key});

  final _router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const TranscriptionScreen()
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen()
      ),
      GoRoute(
        path: '/models',
        name: 'models',
        builder: (context, state) => const ModelManagementScreen()
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
final audioServiceProvider = Provider<AudioService>((ref) => AudioService());

final transcriptionServiceProvider = Provider<TranscriptionService>((ref) {
  final audioService = ref.watch(audioServiceProvider);
  return TranscriptionService(audioService);
});

// App state using engine TranscriptionSegment
class AppState {
  final String? currentTranscription;
  final bool isTranscribing;
  final double progress;
  final String? errorMessage;
  final List<TranscriptionSegment> segments; // From engines/transcription_engine.dart

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
      segments: [], // Clear previous segments
    );
  }

  void updateProgress(double progress) {
    state = state.copyWith(progress: progress.clamp(0.0, 1.0));
  }

  void addSegment(TranscriptionSegment segment) {
    final updatedSegments = [...state.segments, segment];
    final fullText = updatedSegments.map((s) => s.text).join(' ');
    state = state.copyWith(
      segments: updatedSegments,
      currentTranscription: fullText
    );
  }

  void completeTranscription(List<TranscriptionSegment> segments) {
    final fullText = segments.map((s) => s.text).join(' ');
    state = state.copyWith(
      isTranscribing: false,
      segments: segments,
      currentTranscription: fullText,
      progress: 1.0,
      errorMessage: null,
    );
  }

  void setError(String error) {
    state = state.copyWith(
      isTranscribing: false,
      errorMessage: error
    );
  }

  void clearTranscription() {
    state = const AppState();
  }
}