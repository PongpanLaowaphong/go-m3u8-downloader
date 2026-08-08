#!/usr/bin/env bash

# Set working directory to script location
cd "$(dirname "$0")" || exit 1

echo "=================================================="
echo "       🎬 Go M3U8 High-Speed Downloader Setup      "
echo "=================================================="
echo ""

# Check if binary exists, compile if needed
if [ ! -f "./go-m3u8-downloader" ]; then
    echo "🔧 Building go-m3u8-downloader binary..."
    if ! command -v go &> /dev/null; then
        echo "❌ Error: Go compiler not found! Please install Go to build the binary."
        exit 1
    fi
    go build -o go-m3u8-downloader main.go
    if [ $? -ne 0 ]; then
        echo "❌ Error: Build failed!"
        exit 1
    fi
    echo "✔ Build completed successfully!"
    echo ""
fi

chmod +x ./go-m3u8-downloader
./go-m3u8-downloader "$@"
