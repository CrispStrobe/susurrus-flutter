# Susurrus Flutter Deployment Guide

## Prerequisites

### Required Tools
- Flutter SDK (3.10.0 or higher)
- Dart SDK (3.0.0 or higher)
- Android Studio (for Android development)
- Xcode (for iOS development, macOS only)
- Git

### Environment Setup

#### Android
```bash
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/tools/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools
```

#### iOS (macOS only)
```bash
# Install Xcode Command Line Tools
xcode-select --install

# Install CocoaPods
sudo gem install cocoapods
```

## Manual Setup Steps

### 1. File Renames
Navigate to the project root and rename files:

```bash
cd android/app/src/main/kotlin/com/susurrus/flutter/
mv MainActivity.kt.flutter MainActivity.kt
mv rename.me.flutter AudioProcessingPlugin.kt  
mv rename2.me.flutter WhisperCppPlugin.kt
```

### 2. Create Required Directories
```bash
mkdir -p android/app/src/main/res/xml
mkdir -p android/app/src/main/cpp
mkdir -p assets/models
mkdir -p assets/images
mkdir -p fonts
```

### 3. Android File Provider Setup
Create `android/app/src/main/res/xml/file_paths.xml` (already provided in artifacts)

### 4. iOS Permissions Setup
Add the provided Info.plist entries to your `ios/Runner/Info.plist`

## Build Process

### Development Build
```bash
# Install dependencies
flutter pub get

# iOS (macOS only)
cd ios && pod install && cd ..

# Run on device/simulator
flutter run

# Or specify platform
flutter run -d ios
flutter run -d android
```

### Release Build

#### Android APK
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

#### Android App Bundle (for Play Store)
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

#### iOS (macOS only)
```bash
flutter build ios --release
# Then open ios/Runner.xcworkspace in Xcode for signing and distribution
```

## Native Dependencies

### Whisper.cpp Integration
The app includes placeholder native code for whisper.cpp integration. For full functionality:

1. Add whisper.cpp source to `android/app/src/main/cpp/`
2. Update `CMakeLists.txt` to include whisper.cpp
3. Implement actual JNI bindings in `whisper_jni.cpp`

### CoreML Models (iOS)
For iOS CoreML support:
1. Download CoreML Whisper models
2. Add to iOS project bundle
3. Update model loading paths in `CoreMLWhisperPlugin.swift`

## Testing

### Unit Tests
```bash
flutter test
```

### Integration Tests
```bash
flutter test integration_test/
```

### Platform-specific Testing
- Android: Use Android Studio's device manager
- iOS: Use Xcode's iOS Simulator

## Common Issues

### Android Issues
1. **NDK not found**: Install Android NDK through Android Studio
2. **CMake errors**: Ensure CMake 3.22.1+ is installed
3. **Permission denied**: Grant microphone and storage permissions

### iOS Issues
1. **CocoaPods errors**: Run `pod repo update` and `pod install`
2. **Signing issues**: Configure proper provisioning profiles in Xcode
3. **Simulator crashes**: Check iOS deployment target (13.0+)

### Flutter Issues
1. **Dependency conflicts**: Run `flutter clean` and `flutter pub get`
2. **Build errors**: Check `flutter doctor` for missing dependencies
3. **Hot reload not working**: Restart debug session

## Performance Optimization

### Release Builds
- Enable R8/ProGuard for Android
- Use `--split-per-abi` for smaller APKs
- Optimize iOS build with Xcode's release configuration

### Model Optimization
- Use quantized models for better performance
- Implement model caching
- Add progress indicators for long operations

## Security Considerations

### Permissions
- Request permissions at runtime
- Explain permission usage to users
- Handle permission denials gracefully

### Data Privacy
- All processing happens on-device
- No audio data sent to external servers
- Local storage of transcriptions only

## Distribution

### Android
1. Sign APK with release keystore
2. Upload to Google Play Console
3. Configure app signing and release tracks

### iOS
1. Configure signing certificates in Xcode
2. Archive and upload to App Store Connect
3. Submit for review through Apple's process

## Monitoring

### Crash Reporting
Consider integrating:
- Firebase Crashlytics
- Sentry for Flutter

### Analytics
Optional analytics frameworks:
- Firebase Analytics
- Amplitude Flutter SDK

Note: Respect user privacy and comply with GDPR/privacy regulations.