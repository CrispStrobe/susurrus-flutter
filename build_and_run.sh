#!/bin/bash

# Flutter Audio Transcription App Build Script
# This script sets up and builds the CrisperWeaver Flutter app

set -e

echo "Building CrisperWeaver Flutter Audio Transcription App..."

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "ERROR: Flutter is not installed or not in PATH"
    echo "Please install Flutter from https://flutter.dev/docs/get-started/install"
    exit 1
fi

# Check Flutter doctor
echo "Checking Flutter installation..."
flutter doctor

# Clean previous builds
echo "Cleaning previous builds..."
flutter clean

# Get dependencies
echo "Getting Flutter dependencies..."
flutter pub get

# Generate code if needed
echo "Generating code..."
if [ -f "pubspec.yaml" ] && grep -q "build_runner" pubspec.yaml; then
    flutter packages pub run build_runner build --delete-conflicting-outputs
fi

# Check for platform-specific setup
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macOS detected - Setting up iOS dependencies..."
    
    # iOS setup
    if [ -d "ios" ]; then
        cd ios
        
        # Install CocoaPods if not installed
        if ! command -v pod &> /dev/null; then
            echo "Installing CocoaPods..."
            sudo gem install cocoapods
        fi
        
        # Install iOS pods
        echo "Installing iOS CocoaPods..."
        pod install --repo-update
        cd ..
    fi
fi

# Android setup
if [ -d "android" ]; then
    echo "Setting up Android dependencies..."
    
    # Create necessary directories
    mkdir -p android/app/src/main/res/xml
    mkdir -p android/app/src/main/cpp
    
    # Check if Android SDK is available
    if [ -z "$ANDROID_HOME" ]; then
        echo "WARNING: ANDROID_HOME not set. Please set up Android SDK."
    fi
fi

# Create asset directories
echo "Creating asset directories..."
mkdir -p assets/models
mkdir -p assets/images
mkdir -p fonts

# Platform selection for build
echo "Select platform to build:"
echo "1) Android (debug)"
echo "2) iOS (debug) - macOS only"
echo "3) Both platforms"
echo "4) Just run analysis"

read -p "Enter choice (1-4): " choice

case $choice in
    1)
        echo "Building Android debug..."
        flutter build apk --debug
        echo "Android build complete!"
        echo "To install: flutter install"
        ;;
    2)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "Building iOS debug..."
            flutter build ios --debug --no-codesign
            echo "iOS build complete!"
            echo "To run on simulator: flutter run -d ios"
        else
            echo "ERROR: iOS builds are only supported on macOS"
        fi
        ;;
    3)
        echo "Building both platforms..."
        flutter build apk --debug
        if [[ "$OSTYPE" == "darwin"* ]]; then
            flutter build ios --debug --no-codesign
        fi
        echo "Multi-platform build complete!"
        ;;
    4)
        echo "Running Flutter analysis..."
        flutter analyze
        echo "Analysis complete!"
        ;;
    *)
        echo "ERROR: Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "Build process completed!"
echo ""
echo "Next steps:"
echo "1. flutter run                    # Run on connected device"
echo "2. flutter run -d ios            # Run on iOS simulator (macOS only)"
echo "3. flutter run -d android        # Run on Android emulator"
echo "4. flutter build apk --release   # Build release APK"
echo ""
echo "If you encounter issues:"
echo "1. Check flutter doctor"
echo "2. Ensure all permissions are granted"
echo "3. For iOS: open ios/Runner.xcworkspace in Xcode"
echo "4. For Android: open android/ in Android Studio"