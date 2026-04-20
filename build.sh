#!/bin/bash
# Exit on error
set -e

echo "Installing Flutter..."
if [ ! -f ".flutter-sdk/bin/flutter" ]; then
  echo "Downloading Flutter SDK..."
  rm -rf .flutter-sdk
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 .flutter-sdk
else
  echo "Flutter SDK already exists."
fi
export PATH="$PATH:`pwd`/.flutter-sdk/bin"

echo "Flutter version:"
flutter --version

echo "Enabling Flutter Web..."
flutter config --enable-web

echo "Running Flutter pub get..."
flutter pub get

echo "Building Flutter Web with WebAssembly..."
flutter build web --wasm --release
