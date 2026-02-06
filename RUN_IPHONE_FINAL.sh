#!/bin/bash

echo "🚀 Launching GameForge AI on iPhone with Google Sign-In..."

echo "📱 Launching iPhone Simulator..."
open -a Simulator

echo "⏳ Waiting for simulator to start..."
sleep 3

echo "🔍 Building and running Flutter..."
flutter run -d "iPhone 17 Pro Max"

echo "✅ GameForge AI is running on iPhone!"
echo ""
echo "📋 Test Steps:"
echo "1. Click on 'Debug: Test Google Sign-In' to check configuration"
echo "2. Click on 'Continue with Google' to test authentication"
echo "3. Check console logs for detailed debugging info"
echo ""
echo "🎯 Expected logs:"
echo "🔍 Platform: ios"
echo "🔍 Using Client ID: 392208742095-d3ndk33to900aovhiop0bn5u0h2cgfk2.apps.googleusercontent.com"
echo "✅ Google login successful!"
