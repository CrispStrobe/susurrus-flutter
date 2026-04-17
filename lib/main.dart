import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/transcription_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/model_management_screen.dart';
import 'screens/history_screen.dart';
import 'screens/logs_screen.dart';
import 'screens/about_screen.dart';
import 'services/audio_service.dart';
import 'services/history_service.dart';
import 'services/log_service.dart';
import 'services/native_licenses.dart';
import 'services/share_intake_service.dart';
import 'services/transcription_service.dart';
import 'services/model_service.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';
import 'engines/transcription_engine.dart'; // Use engine TranscriptionSegment

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Log.instance.i('main', 'CrisperWeaver starting — platform=${Platform.operatingSystem}');
  FlutterError.onError = (details) {
    Log.instance.e(
      'flutter',
      details.exceptionAsString(),
      error: details.exception,
      stack: details.stack,
    );
    FlutterError.presentError(details);
  };

  await _requestPermissions();
  await _initializeServices();
  await registerNativeLicenses();

  final prefs = await SharedPreferences.getInstance();
  final settingsService = SettingsService(prefs);

  runApp(
    ProviderScope(
      overrides: [
        settingsServiceProvider.overrideWithValue(settingsService),
      ],
      child: const CrisperWeaverApp(),
    ),
  );
}

Future<void> _requestPermissions() async {
  // Only request mobile-only permissions on mobile platforms. On desktop the
  // permission_handler plugin simply returns granted or unknown, so asking
  // is cheap but unnecessary.
  if (!(Platform.isIOS || Platform.isAndroid)) return;

  final permissions = <Permission>[
    Permission.microphone,
  ];
  if (Platform.isAndroid) {
    permissions.add(Permission.storage);
  }

  try {
    await permissions.request();
  } catch (e) {
    debugPrint('Permission request failed: $e');
  }
}

Future<void> _initializeServices() async {
  try {
    await getApplicationDocumentsDirectory();
  } catch (e) {
    debugPrint('Failed to initialize services: $e');
  }
}

class CrisperWeaverApp extends ConsumerStatefulWidget {
  const CrisperWeaverApp({super.key});

  @override
  ConsumerState<CrisperWeaverApp> createState() => _CrisperWeaverAppState();
}

class _CrisperWeaverAppState extends ConsumerState<CrisperWeaverApp> {
  @override
  void initState() {
    super.initState();
    // Kick off OS-level share intake after the first frame so Riverpod's
    // provider graph is fully built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(shareIntakeServiceProvider).start();
    });
  }


  static final GoRouter _router = GoRouter(
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
      GoRoute(
        path: '/history',
        name: 'history',
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: '/logs',
        name: 'logs',
        builder: (context, state) => const LogsScreen(),
      ),
      GoRoute(
        path: '/about',
        name: 'about',
        builder: (context, state) => const AboutScreen(),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'CrisperWeaver',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: _router,
      locale: locale,
      // i18n: English (fallback) + German. Flutter picks the closest match
      // to the system locale automatically.
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Make the title locale-aware too.
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appName,
    );
  }
}

// Global providers
final audioServiceProvider = Provider<AudioService>((ref) => AudioService());

final historyServiceProvider =
    Provider<HistoryService>((ref) => HistoryService());

final modelServiceProvider = Provider<ModelService>((ref) {
  final settingsService = ref.watch(settingsServiceProvider);
  return ModelService(settingsService);
});

final transcriptionServiceProvider = Provider<TranscriptionService>((ref) {
  final audioService = ref.watch(audioServiceProvider);
  final modelService = ref.watch(modelServiceProvider);
  return TranscriptionService(audioService, modelService);
});

/// Path to the audio file the user has selected or just recorded — used to
/// hand off a recording from the recorder widget to the transcription screen.
final selectedAudioPathProvider = StateProvider<String?>((ref) => null);

// App state using engine TranscriptionSegment
class AppState {
  final String? currentTranscription;
  final bool isTranscribing;
  final double progress;
  final String? errorMessage;
  final List<TranscriptionSegment> segments;
  final PerformanceStats? performance;

  const AppState({
    this.currentTranscription,
    this.isTranscribing = false,
    this.progress = 0.0,
    this.errorMessage,
    this.segments = const [],
    this.performance,
  });

  AppState copyWith({
    String? currentTranscription,
    bool? isTranscribing,
    double? progress,
    String? errorMessage,
    List<TranscriptionSegment>? segments,
    PerformanceStats? performance,
  }) {
    return AppState(
      currentTranscription: currentTranscription ?? this.currentTranscription,
      isTranscribing: isTranscribing ?? this.isTranscribing,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      segments: segments ?? this.segments,
      performance: performance ?? this.performance,
    );
  }
}

/// Performance snapshot for the most recent transcription run.
class PerformanceStats {
  final double audioSeconds;
  final double wallSeconds;
  final double rtf;
  final int wordCount;
  final double wordsPerSecond;
  final String? engineId;
  final String? modelId;

  const PerformanceStats({
    required this.audioSeconds,
    required this.wallSeconds,
    required this.rtf,
    required this.wordCount,
    required this.wordsPerSecond,
    this.engineId,
    this.modelId,
  });

  static PerformanceStats? fromMetadata(
    Map<String, dynamic>? md, {
    String? engineId,
    String? modelId,
  }) {
    if (md == null) return null;
    final a = (md['audioSeconds'] as num?)?.toDouble();
    final w = (md['wallSeconds'] as num?)?.toDouble();
    final r = (md['rtf'] as num?)?.toDouble();
    final wc = (md['wordCount'] as num?)?.toInt();
    final wps = (md['wordsPerSecond'] as num?)?.toDouble();
    if (a == null || w == null) return null;
    return PerformanceStats(
      audioSeconds: a,
      wallSeconds: w,
      rtf: r ?? 0.0,
      wordCount: wc ?? 0,
      wordsPerSecond: wps ?? 0.0,
      engineId: engineId ?? md['engine'] as String?,
      modelId: modelId ?? md['model'] as String?,
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

  void completeTranscription(
    List<TranscriptionSegment> segments, {
    PerformanceStats? performance,
  }) {
    final fullText = segments.map((s) => s.text).join(' ');
    state = state.copyWith(
      isTranscribing: false,
      segments: segments,
      currentTranscription: fullText,
      progress: 1.0,
      errorMessage: null,
      performance: performance,
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

/// Manages the app's locale based on user preference or system default.
class LocaleNotifier extends StateNotifier<Locale?> {
  final SettingsService _settingsService;

  LocaleNotifier(this._settingsService) : super(null) {
    _init();
  }

  void _init() {
    final localeCode = _settingsService.appLocale;
    if (localeCode != null && localeCode.isNotEmpty) {
      state = Locale(localeCode);
    }
  }

  Future<void> setLocale(String? languageCode) async {
    _settingsService.appLocale = languageCode;
    if (languageCode == null || languageCode.isEmpty) {
      state = null;
    } else {
      state = Locale(languageCode);
    }
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>((ref) {
  final settingsService = ref.watch(settingsServiceProvider);
  return LocaleNotifier(settingsService);
});