#!/bin/bash
# build_android.sh

echo "Building Android native libraries..."

cd android
./gradlew assembleDebug

if [ $? -eq 0 ]; then
    echo "Android build successful!"
else
    echo "Android build failed!"
    exit 1
fi