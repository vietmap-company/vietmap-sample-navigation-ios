#!/usr/bin/env bash

# Turns on recording in all .swift-files inside ../VietMapNavigationTests, runs the testing target, and turns recording back to false.
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
find "${DIR}/../VietMapNavigationTests" -name "*.swift" -exec sed -i '' "s/recordMode = false/recordMode = true/g" {} \;
xcodebuild -sdk iphonesimulator -destination 'platform=iOS Simulator,OS=11.4,name=iPhone 6 Plus' -project VietMapNavigation.xcodeproj -scheme VietMapNavigation build test | xcpretty
xcodebuild -sdk iphonesimulator -destination 'platform=iOS Simulator,OS=12.0,name=iPhone 6 Plus' -project VietMapNavigation.xcodeproj -scheme VietMapNavigation build test | xcpretty
find "${DIR}/../VietMapNavigationTests" -name "*.swift" -exec sed -i '' "s/recordMode = true/recordMode = false/g" {} \;