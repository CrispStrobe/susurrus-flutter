// Basic smoke tests for the CrisperWeaver Flutter app.
//
// These intentionally avoid pumping the full `CrisperWeaverApp` — that triggers
// platform-channel calls, file IO, and FFI which cannot run under
// `flutter test`. Instead we cover pure-Dart building blocks.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crisper_weaver/engines/engine_factory.dart';
import 'package:crisper_weaver/engines/transcription_engine.dart';
import 'package:crisper_weaver/services/log_service.dart';
import 'package:crisper_weaver/theme/app_theme.dart';

void main() {
  test('MockEngine initializes and returns models', () async {
    final engine = EngineFactory.create(EngineType.mock);
    expect(await engine.initialize(), isTrue);
    final models = await engine.getAvailableModels();
    expect(models, isNotEmpty);
    expect(models.first, isA<EngineModel>());
    await engine.dispose();
  });

  test('Log ring buffer accepts entries at configured level', () {
    final log = Log.instance;
    log.setMinLevel(LogLevel.trace);
    final before = log.snapshot().length;
    log.d('test', 'hello');
    final after = log.snapshot().length;
    expect(after, greaterThan(before));
    expect(log.snapshot().last.message, 'hello');
  });

  test('Themes build without throwing', () {
    expect(AppTheme.lightTheme, isA<ThemeData>());
    expect(AppTheme.darkTheme, isA<ThemeData>());
  });

  test('EngineFactory recommends CrispASR by default', () {
    expect(EngineFactory.getRecommendedEngine(), EngineType.crispasr);
    expect(EngineFactory.getAvailableEngines(), contains(EngineType.crispasr));
  });
}
