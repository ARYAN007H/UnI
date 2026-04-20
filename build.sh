#!/bin/bash
# Exit on error
set -e

echo "Installing Flutter..."
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
else
  echo "Flutter directory already exists."
fi
export PATH="$PATH:`pwd`/flutter/bin"

echo "Flutter version:"
flutter --version

echo "Enabling Flutter Web..."
flutter config --enable-web

echo "Running Flutter pub get..."
flutter pub get

echo "Building Flutter Web with WebAssembly..."
flutter build web --wasm --release
