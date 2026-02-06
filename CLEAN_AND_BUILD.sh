#!/bin/bash

echo "🧹 Cleaning Flutter project..."
flutter clean

echo "📦 Getting dependencies..."
flutter pub get

echo "🍎 Cleaning macOS pods..."
cd macos
rm -rf Pods Podfile.lock

echo "📦 Installing pods..."
pod install

echo "🔧 Cleaning Xcode build cache..."
cd ..
xcodebuild clean -workspace macos/Runner.xcworkspace -scheme Runner -configuration Debug

echo "🚀 Building and running Flutter..."
flutter run -d macos

echo "✅ Clean and build complete!"
