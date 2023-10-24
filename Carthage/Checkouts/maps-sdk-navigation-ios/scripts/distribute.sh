#!/bin/bash

set -eo pipefail

# Set output directory
OUTPUT_DIR="./build/vietmap"

# Clean up the output directory if it exists
if [ -d "$OUTPUT_DIR" ]; then
  rm -rf "$OUTPUT_DIR"
fi

# Build XCFramework for iOS devices (arm64, armv7)
xcodebuild archive \
  -scheme "VietMapNavigation" \
  -archivePath "$OUTPUT_DIR/VietMapNavigation-iOS" \
  -sdk "iphoneos" \
  -configuration Release \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  archive \
  SKIP_INSTALL=NO | xcpretty

# Build XCFramework for iOS simulator (x86_64, arm64)
xcodebuild archive \
  -scheme "VietMapNavigation" \
  -archivePath "$OUTPUT_DIR/VietMapNavigation-iOS-Simulator" \
  -sdk "iphonesimulator" \
  -configuration Release \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  archive \
  SKIP_INSTALL=NO | xcpretty

# Create a universal XCFramework
xcodebuild -create-xcframework \
  -framework "$OUTPUT_DIR/VietMapNavigation-iOS.xcarchive/Products/Library/Frameworks/VietMapNavigation.framework" \
  -framework "$OUTPUT_DIR/VietMapNavigation-iOS-Simulator.xcarchive/Products/Library/Frameworks/VietMapNavigation.framework" \
  -output "$OUTPUT_DIR/VietMapNavigation.xcframework"

# Clean up the intermediate build artifacts
rm -rf "$OUTPUT_DIR/VietMapNavigation-iOS.xcarchive"
rm -rf "$OUTPUT_DIR/VietMapNavigation-iOS-Simulator.xcarchive"

echo "Distribution XCFramework is created at: $OUTPUT_DIR/VietMapNavigation.xcframework"
