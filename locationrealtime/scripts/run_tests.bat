@echo off
REM Authentication Unit Tests Runner Script for Windows
REM This script generates mock files and runs all authentication tests

echo 🚀 Starting Authentication Unit Tests...

REM Check if Flutter is installed
flutter --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Flutter is not installed or not in PATH
    exit /b 1
)

REM Get dependencies
echo 📦 Getting dependencies...
flutter pub get

REM Generate mock files
echo 🔧 Generating mock files...
flutter packages pub run build_runner build --delete-conflicting-outputs

REM Check if mock generation was successful
if %errorlevel% neq 0 (
    echo ❌ Failed to generate mock files
    exit /b 1
)

echo ✅ Mock files generated successfully

REM Run all tests
echo 🧪 Running all authentication tests...
flutter test test/ --coverage

REM Check if tests passed
if %errorlevel% equ 0 (
    echo ✅ All tests passed!
    
    REM Show coverage summary if available
    where genhtml >nul 2>&1
    if %errorlevel% equ 0 (
        echo 📊 Generating coverage report...
        genhtml coverage/lcov.info -o coverage/html
        echo 📊 Coverage report generated at coverage/html/index.html
    )
) else (
    echo ❌ Some tests failed
    exit /b 1
)

echo 🎉 Test run completed! 