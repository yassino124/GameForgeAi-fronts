#!/bin/bash

echo "📱 Launching iPhone Simulator..."
open -a Simulator

echo "⏳ Waiting for simulator to start..."
sleep 5

echo "🔍 Checking available devices..."
flutter devices

echo "🚀 Running Flutter on iPhone..."
flutter run -d "iPhone 17 Pro Max"

echo "✅ Done!"
