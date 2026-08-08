# 🎬 go-m3u8-downloader

A fast, concurrent, and robust Command Line Interface (CLI) application written in **Go** for downloading and merging HLS (`.m3u8`) streaming videos into a single output file (`.mp4` / `.ts`).

Works seamlessly on **Windows**, **Linux**, and **macOS**.

---

## ✨ Features

- 🚀 **High-Speed Concurrent Downloads**: Worker pool architecture utilizing Goroutines and WaitGroups for maximum speed.
- 🎯 **Master & Media Playlist Support**: Automatically parses Master Playlists and selects the highest resolution/bandwidth stream variant.
- 🔐 **AES-128 Decryption**: Automatically fetches key files and decrypts AES-128 encrypted HLS streams.
- 📊 **Real-Time Live Progress Bar**: Displays ASCII progress bar, percentage, total downloaded MB, live speed (MB/s), and estimated time remaining (ETA).
- 📁 **Custom Output Location Selection**: Allows choosing custom output directories and filenames, automatically creating target folders.
- 🔄 **Interactive Retry Menu & Error Resilience**: Friendly terminal prompts, URL quote trimming, and option to run multiple downloads without restarting the app.
- 💻 **Cross-Platform & Single Executable**: Compiles into a single standalone binary with zero external runtime dependencies.

---

## 🚀 Quick Start

### Windows Users
Simply double-click **`setup.bat`** in the project directory. It automatically builds the application (if needed) and launches the interactive downloader menu.

Or run from Command Prompt / PowerShell:
```cmd
.\go-m3u8-downloader.exe
```

### Linux & macOS Users
Make the shell script executable and run **`setup.sh`**:
```bash
chmod +x setup.sh
./setup.sh
```

---

## 💻 Installation & Building from Source

### Prerequisites
- [Go 1.18 or higher](https://go.dev/dl/) installed on your system.

### Step 1: Clone Repository
```bash
git clone https://github.com/PongpanLaowaphong/go-m3u8-downloader.git
cd go-m3u8-downloader
```

### Step 2: Install Dependencies
```bash
go mod download
```

### Step 3: Build Executable

#### On Windows:
```cmd
go build -o go-m3u8-downloader.exe main.go
```

#### On Linux / macOS:
```bash
go build -o go-m3u8-downloader main.go
chmod +x go-m3u8-downloader
```

---

## 📖 Usage Guide

### Mode 1: Interactive Terminal Mode
Run the application without flags to be guided interactively:

```bash
./go-m3u8-downloader
```

**Prompts example:**
```text
==================================================
       🎬  Go M3U8 High-Speed Downloader         
==================================================
👉 Enter .m3u8 Playlist URL: https://example.com/video/playlist.m3u8
📁 Enter output directory location (leave blank for current directory): D:\Downloads
📄 Enter output filename [default: output.mp4]: my_movie.mp4
```

### Mode 2: Command Line Flags Mode
Pass arguments directly for automated or scripted downloads:

```bash
./go-m3u8-downloader -u "https://example.com/video.m3u8" -d "./output" -o "video.mp4" -c 16
```

### 🚩 Command Line Flags Reference

| Flag | Short | Default | Description |
| :--- | :--- | :--- | :--- |
| `--url` | `-u` | `""` | URL of the `.m3u8` playlist manifest file |
| `--dir` | `-d` | `"."` | Directory location where the output file will be saved |
| `--output` | `-o` | `"output.mp4"` | Output filename (e.g. `video.mp4` or `video.ts`) |
| `--concurrency` | `-c` | `10` | Number of concurrent download worker threads (1-50) |

---

## 🌐 Cross-Compilation for Linux / Windows / macOS

Go allows building binaries for any target OS from your local machine:

### Cross-Compile for Linux 64-bit (from Windows)
```powershell
$env:GOOS="linux"; $env:GOARCH="amd64"; go build -o go-m3u8-downloader-linux main.go
```

### Cross-Compile for Windows 64-bit (from Linux/macOS)
```bash
GOOS=windows GOARCH=amd64 go build -o go-m3u8-downloader.exe main.go
```

### Cross-Compile for macOS ARM64 (Apple Silicon)
```bash
GOOS=darwin GOARCH=arm64 go build -o go-m3u8-downloader-mac main.go
```

---

## 🛠 Project Structure

```text
go-m3u8-downloader/
├── main.go               # Core application logic & HLS downloader engine
├── setup.bat             # Automated Windows setup & launcher script
├── setup.sh              # Automated Linux / macOS setup & launcher script
├── go.mod                # Go module metadata
├── go.sum                # Dependency checksums
└── README.md             # Project documentation
```

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
