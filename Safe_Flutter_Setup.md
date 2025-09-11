# Safe Flutter Setup Procedures

## Pre-Flight Checklist

Before running any Flutter commands, complete these mandatory file operations:

### 1. File System Fixes (Critical)
```bash
# Navigate to project root
cd C:\Users\stc\Downloads\code\susurrus_flutter

# Rename Podfile
mv ios/Podfile.txt ios/Podfile

# Create missing engine directory
mkdir -p lib/engines

# Create missing assets directories  
mkdir -p assets/models
mkdir -p assets/images
mkdir -p fonts
```

### 2. Add Missing Engine Files
You need to create these files from the artifacts I provided:

**Required files to create:**
- `lib/engines/transcription_engine.dart`
- `lib/engines/engine_factory.dart` 
- `lib/engines/mock_engine.dart`
- `lib/engines/whisper_cpp_engine.dart`
- `lib/engines/coreml_engine.dart`

### 3. Update Service Dependencies
The existing service files need to import the new engine system. Update these imports:

**In `lib/services/transcription_service.dart`:**
```dart
// Replace the existing backend enum with:
import '../engines/transcription_engine.dart';
import '../engines/engine_factory.dart';

// Remove the old TranscriptionBackend enum
// Update the service to use the new engine system
```

**In `lib/main.dart`:**
```dart
// Add engine provider
import 'engines/engine_factory.dart';

// Add engine manager provider
final engineManagerProvider = StateNotifierProvider<EngineManagerNotifier, EngineManagerState>((ref) {
  return EngineManagerNotifier();
});
```

## Safe Flutter Commands Sequence

### Step 1: Verify Flutter Installation
```bash
flutter --version
flutter doctor
```

**Expected output:** Flutter 3.10.0+ with no critical issues

### Step 2: Check Project Structure
```bash
flutter analyze --no-pub
```

**Expected result:** Should complete without running pub get first

### Step 3: Safe Pub Get
```bash
flutter pub get
```

**Potential issues:**
- Dependency conflicts: Some packages may not be compatible
- Platform-specific issues: iOS/Android SDK problems
- Network issues: Package download failures

**If pub get fails:**
```bash
flutter clean
flutter pub get --verbose
```

### Step 4: iOS-Specific Setup (Focus Platform)
```bash
cd ios
pod install --repo-update
cd ..
```

**Common iOS issues:**
- CocoaPods not installed: `sudo gem install cocoapods`
- Outdated pod repo: `pod repo update`
- Xcode command line tools: `xcode-select --install`

### Step 5: Verify Build Configuration
```bash
flutter analyze
```

**Expected:** Warnings about missing implementations, no errors

### Step 6: Test with Mock Engine
```bash
flutter run -d ios --debug
```

**Critical:** This should launch with mock engine only

## Testing Strategy

### Phase 1: UI Testing (Immediate)
- App launches without crashes
- Navigation works between screens
- Settings screen opens
- Mock engine can be selected and "transcribes" test data

### Phase 2: Mock Engine Validation
- Record audio (should work)
- Select audio files (should work)  
- Run "transcription" with mock engine (should return fake results)
- Test speaker diarization toggle (should affect mock output)

### Phase 3: Real Engine Integration (Later)
- Only after mock engine works completely
- Add whisper.cpp native libraries
- Add CoreML models
- Test real transcription

## Critical Configuration Issues

### iOS Info.plist Requirements
Your `ios/Runner/Info.plist` must include:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access for audio transcription</string>

<key>NSDocumentsFolderUsageDescription</key>
<string>This app needs access to documents to save transcriptions</string>
```

### Android Manifest Issues
Check `android/app/src/main/AndroidManifest.xml` includes:
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

## Debugging Failed Setup

### If Flutter Pub Get Fails
1. Check internet connection
2. Clear Flutter cache: `flutter clean`
3. Delete `pubspec.lock`
4. Retry with verbose output: `flutter pub get --verbose`

### If iOS Build Fails
1. Open `ios/Runner.xcworkspace` in Xcode
2. Check signing & capabilities
3. Verify deployment target is iOS 13.0+
4. Run pod install again

### If Engine System Fails
1. Verify all engine files are created
2. Check imports in existing services
3. Test mock engine in isolation
4. Use `flutter run --verbose` for detailed errors

## Validation Checklist

Before proceeding to real engines:

- [ ] Flutter pub get completes successfully
- [ ] iOS pod install works
- [ ] App launches on iOS simulator/device
- [ ] Mock engine can be selected in settings
- [ ] Mock transcription produces fake results
- [ ] Audio recording UI appears functional
- [ ] File picker opens and selects files
- [ ] Navigation between all screens works

## Known Limitations

The current setup will have these limitations until real engines are implemented:

1. **No actual transcription** - Mock engine only
2. **No model downloads** - UI exists but doesn't download
3. **Limited audio processing** - Basic file handling only
4. **No native code** - Placeholder implementations

## Next Steps After Successful Setup

1. **Validate mock engine thoroughly**
2. **Add whisper.cpp native integration**
3. **Implement CoreML model loading**
4. **Add real model download functionality**
5. **Test with actual audio files**

## Emergency Fallback

If setup completely fails:
1. Create new Flutter project: `flutter create susurrus_test`
2. Copy only `lib/` directory contents
3. Use minimal `pubspec.yaml` with core dependencies only
4. Add engine system incrementally

This approach ensures you can test the UI and mock engine before dealing with native code complexity.