#!/bin/bash
# Exit on error
set -e

echo "Installing Flutter..."
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PATH:`pwd`/flutter/bin"

echo "Flutter version:"
flutter --version

echo "Running Flutter pub get..."
flutter pub get

echo "Building Flutter Web..."
flutter build web --release
