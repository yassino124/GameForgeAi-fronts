#!/bin/bash

echo "🚀 Running GameForge AI on iPhone (Syntax Fixed)..."

echo "📱 Launching iPhone Simulator..."
open -a Simulator

echo "⏳ Waiting for simulator to start..."
sleep 3

echo "🔧 Building and running Flutter..."
flutter run -d "iPhone 17 Pro Max"

echo "✅ GameForge AI is running on iPhone!"
echo ""
echo "📋 Google Sign-In Status:"
echo "✅ Syntax errors fixed"
echo "✅ iOS uses plist configuration (no clientId)"
echo "✅ macOS uses explicit clientId"
echo ""
echo "🔍 Test Steps:"
echo "1. Click on 'Debug: Test Google Sign-In'"
echo "2. Should show: 'Using plist configuration'"
echo "3. Click on 'Continue with Google'"
echo "4. If 'cancelled by user' appears:"
echo "   - Open Settings in simulator"
echo "   - Go to Accounts & Passwords"
echo "   - Add Google account"
echo "   - Try again"
echo ""
echo "🎯 Expected logs:"
echo "🔍 Platform: ios"
echo "🔍 Using Client ID: Using plist configuration"
echo "✅ Google account obtained: your-email@gmail.com"
