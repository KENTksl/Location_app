#!/bin/bash

# Authentication Unit Tests Runner Script
# This script generates mock files and runs all authentication tests

echo "🚀 Starting Authentication Unit Tests..."

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed or not in PATH"
    exit 1
fi

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Generate mock files
echo "🔧 Generating mock files..."
flutter packages pub run build_runner build --delete-conflicting-outputs

# Check if mock generation was successful
if [ $? -ne 0 ]; then
    echo "❌ Failed to generate mock files"
    exit 1
fi

echo "✅ Mock files generated successfully"

# Run all tests
echo "🧪 Running all authentication tests..."
flutter test test/ --coverage

# Check if tests passed
if [ $? -eq 0 ]; then
    echo "✅ All tests passed!"
    
    # Show coverage summary if available
    if command -v genhtml &> /dev/null; then
        echo "📊 Generating coverage report..."
        genhtml coverage/lcov.info -o coverage/html
        echo "📊 Coverage report generated at coverage/html/index.html"
    fi
else
    echo "❌ Some tests failed"
    exit 1
fi

echo "🎉 Test run completed!" 