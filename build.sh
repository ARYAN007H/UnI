#!/bin/bash
# Vercel CI build script for U&i Flutter Web
set -e

# ── Create .env from Vercel environment variables ──────────────
echo "Creating .env from Vercel environment variables..."
echo "SUPABASE_URL=${SUPABASE_URL}" > .env
echo "SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}" >> .env

# ── Install Flutter SDK ────────────────────────────────────────
echo "Installing Flutter..."
if [ ! -f ".flutter-sdk/bin/flutter" ]; then
  echo "Downloading Flutter SDK..."
  rm -rf .flutter-sdk
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 .flutter-sdk
else
  echo "Flutter SDK already cached."
fi
export PATH="$PATH:$(pwd)/.flutter-sdk/bin"

# ── Suppress all analytics & telemetry (prevents CI hangs) ─────
export CI=true
export FLUTTER_SUPPRESS_ANALYTICS=true
flutter config --no-analytics 2>/dev/null || true
dart --disable-telemetry 2>/dev/null || true

echo "Flutter version:"
flutter --version

# ── Build ──────────────────────────────────────────────────────
echo "Running flutter pub get..."
flutter pub get

echo "Generating sqflite web workers..."
dart run sqflite_common_ffi_web:setup

echo "Building Flutter Web (JS, release)..."
flutter build web --release
