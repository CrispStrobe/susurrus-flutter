#!/bin/bash
# build_ios.sh

echo "Building iOS..."

cd ios
pod install

cd ..
flutter build ios --debug --no-codesign

if [ $? -eq 0 ]; then
    echo "iOS build successful!"
else
    echo "iOS build failed!"
    exit 1
fi