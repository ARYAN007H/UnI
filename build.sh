#!/bin/bash
# Vercel CI build for U&i Flutter Web (demo/funnel only — web is not a target platform).
# NOTE: local development uses the SYSTEM flutter (~/development/flutter).
# The old vendored .flutter-sdk/ is deprecated; CI clones stable fresh each build.
set -e

# ── Create .env from Vercel environment variables ──────────────
echo "Creating .env from Vercel environment variables..."
echo "SUPABASE_URL=${SUPABASE_URL}" > .env
echo "SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}" >> .env

# ── Install Flutter SDK (fresh stable clone, not vendored) ─────
echo "Installing Flutter..."
rm -rf .flutter-sdk
git clone https://github.com/flutter/flutter.git -b stable --depth 1 .flutter-sdk
export PATH="$PATH:$(pwd)/.flutter-sdk/bin"

# ── Suppress analytics & telemetry (prevents CI hangs) ─────────
export CI=true
export FLUTTER_SUPPRESS_ANALYTICS=true
flutter config --no-analytics 2>/dev/null || true
dart --disable-telemetry 2>/dev/null || true

echo "Flutter version:"
flutter --version

# ── Build ──────────────────────────────────────────────────────
echo "Running flutter pub get..."
flutter pub get

echo "Building Flutter Web (release)..."
flutter build web --release
