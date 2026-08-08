#!/usr/bin/env bash

# Set working directory to script location
cd "$(dirname "$0")" || exit 1

echo "=================================================="
echo "       🎬 Go M3U8 High-Speed Downloader Setup      "
echo "=================================================="
echo ""

# Function to check or install Go
check_or_install_go() {
    if command -v go &> /dev/null; then
        GO_VER=$(go version)
        echo "✔ Go compiler is already installed: $GO_VER"
        return 0
    fi

    echo "⚠️  Go compiler was not found on your system."
    echo "🌐 Reference: https://go.dev/doc/install"
    echo ""
    read -p "👉 Would you like to automatically install Go compiler now? (Y/n): " INSTALL_CHOICE
    INSTALL_CHOICE=${INSTALL_CHOICE:-Y}

    if [[ "$INSTALL_CHOICE" =~ ^[Yy]$ ]]; then
        echo "🚀 Installing Go compiler..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y golang-go
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y golang
        elif command -v yum &> /dev/null; then
            sudo yum install -y golang
        elif command -v pacman &> /dev/null; then
            sudo pacman -S --noconfirm go
        elif command -v brew &> /dev/null; then
            brew install go
        else
            echo "📥 Downloading official Go package from https://go.dev/dl/..."
            GO_TAR="go1.22.5.linux-amd64.tar.gz"
            curl -OL "https://go.dev/dl/$GO_TAR"
            sudo tar -C /usr/local -xzf "$GO_TAR"
            export PATH=$PATH:/usr/local/go/bin
            rm -f "$GO_TAR"
        fi

        export PATH=$PATH:/usr/local/go/bin:~/go/bin

        if command -v go &> /dev/null; then
            echo "✔ Go compiler successfully installed: $(go version)"
        else
            echo "❌ Failed to automatically install Go. Please install Go manually from https://go.dev/doc/install"
            exit 1
        fi
    else
        echo "❌ Go compiler is required to build the program. Exiting."
        exit 1
    fi
}

check_or_install_go

# Check if binary exists or build it
if [ ! -f "./go-m3u8-downloader" ]; then
    echo ""
    echo "🔧 Building go-m3u8-downloader binary..."
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
