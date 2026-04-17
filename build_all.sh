#!/bin/bash
# build_all.sh

echo "Building CrisperWeaver for all platforms..."

# Check if whisper.cpp exists
if [ ! -d "android/app/src/main/cpp/whisper.cpp" ]; then
    echo "Downloading whisper.cpp..."
    cd android/app/src/main/cpp
    git clone https://github.com/ggerganov/whisper.cpp.git
    cd ../../../../..
fi

# Flutter clean and pub get
flutter clean
flutter pub get

# Platform-specific builds
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Building for iOS..."
    ./build_ios.sh
fi

echo "Building for Android..."
./build_android.sh

echo "All builds completed!"