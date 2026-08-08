package main

import (
	"bufio"
	"bytes"
	"crypto/aes"
	"crypto/cipher"
	"encoding/binary"
	"flag"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/grafov/m3u8"
)

// SegmentTask represents a single video segment download job
type SegmentTask struct {
	Index int
	URL   string
	Key   *m3u8.Key
	Path  string
}

// Global HTTP client configured with reasonable timeouts
var httpClient = &http.Client{
	Timeout: 30 * time.Second,
}

const userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

func main() {
	// Command line flags
	urlFlag := flag.String("u", "", "URL of the .m3u8 manifest file")
	dirFlag := flag.String("d", "", "Directory location to save the output file")
	outputFlag := flag.String("o", "", "Output file name (e.g., video.mp4 or output.ts)")
	concurrencyFlag := flag.Int("c", 10, "Number of concurrent download threads")
	flag.Parse()

	reader := bufio.NewReader(os.Stdin)

	initialURL := *urlFlag
	initialDir := *dirFlag
	initialOutput := *outputFlag
	concurrency := *concurrencyFlag

	for {
		printBanner()

		err := runDownloader(reader, initialURL, initialDir, initialOutput, concurrency)
		if err != nil {
			fmt.Printf("\n❌ DOWNLOAD FAILED: %v\n", err)
		}

		// Reset initial flag values after first execution so loop prompts interactively
		initialURL = ""
		initialDir = ""
		initialOutput = ""

		fmt.Println("\n==================================================")
		fmt.Print("👉 Press [R] + Enter to run another download, or press [Enter] to exit: ")
		choiceInput, _ := reader.ReadString('\n')
		choice := strings.TrimSpace(choiceInput)

		if strings.EqualFold(choice, "r") {
			fmt.Println("\n🔄 Restarting downloader...\n")
			continue
		}

		fmt.Println("👋 Exiting program. Goodbye!")
		break
	}
}

func printBanner() {
	fmt.Println("==================================================")
	fmt.Println("       🎬  Go M3U8 High-Speed Downloader         ")
	fmt.Println("==================================================")
}

func runDownloader(reader *bufio.Reader, flagURL, flagDir, flagOutput string, concurrency int) error {
	// 1. Prompt for URL if not provided via flags
	m3u8URL := cleanInput(flagURL)
	if m3u8URL == "" {
		fmt.Print("👉 Enter .m3u8 Playlist URL: ")
		input, err := reader.ReadString('\n')
		if err != nil {
			return fmt.Errorf("failed to read input: %w", err)
		}
		m3u8URL = cleanInput(input)
	}

	if m3u8URL == "" {
		return fmt.Errorf("M3U8 URL cannot be empty")
	}

	// Validate URL syntax
	parsedURL, err := url.ParseRequestURI(m3u8URL)
	if err != nil || (parsedURL.Scheme != "http" && parsedURL.Scheme != "https") {
		return fmt.Errorf("invalid URL format '%s'. Must start with http:// or https://", m3u8URL)
	}

	// 2. Prompt for Output Directory if not provided via flags
	outputDir := cleanInput(flagDir)
	if outputDir == "" {
		fmt.Print("📁 Enter output directory location (leave blank for current directory): ")
		input, err := reader.ReadString('\n')
		if err == nil {
			outputDir = cleanInput(input)
		}
	}
	if outputDir == "" {
		outputDir = "."
	}

	// 3. Prompt for Output Filename if not provided via flags
	outputFilename := cleanInput(flagOutput)
	if outputFilename == "" {
		fmt.Print("📄 Enter output filename [default: output.mp4]: ")
		input, err := reader.ReadString('\n')
		if err == nil {
			outputFilename = cleanInput(input)
		}
		if outputFilename == "" {
			outputFilename = "output.mp4"
		}
	}

	// If outputFilename contains directory path, resolve it with outputDir
	if filepath.Dir(outputFilename) != "." && outputDir == "." {
		outputDir = filepath.Dir(outputFilename)
		outputFilename = filepath.Base(outputFilename)
	}

	// Ensure destination directory exists
	err = os.MkdirAll(outputDir, 0755)
	if err != nil {
		return fmt.Errorf("failed to create destination directory '%s': %w", outputDir, err)
	}

	finalOutputPath := filepath.Join(outputDir, outputFilename)

	if concurrency <= 0 {
		concurrency = 10
	}

	fmt.Printf("\n📂 Save Path : %s\n", finalOutputPath)
	fmt.Println("🔍 Parsing playlist manifest...")

	// Parse manifest and obtain segment URLs
	segmentTasks, err := fetchAndParseManifest(m3u8URL)
	if err != nil {
		return fmt.Errorf("parsing manifest failed: %w", err)
	}

	totalSegments := len(segmentTasks)
	if totalSegments == 0 {
		return fmt.Errorf("no valid video segments found in playlist")
	}

	fmt.Printf("✔ Found %d video segments.\n", totalSegments)
	fmt.Printf("🚀 Downloading with concurrency level = %d workers...\n\n", concurrency)

	// Create temporary directory for segments
	tempDir, err := os.MkdirTemp("", "m3u8_downloader_*")
	if err != nil {
		return fmt.Errorf("failed to create temporary directory: %w", err)
	}
	defer func() {
		_ = os.RemoveAll(tempDir)
	}()

	// Set destination file paths for tasks
	for i := range segmentTasks {
		segmentTasks[i].Path = filepath.Join(tempDir, fmt.Sprintf("segment_%05d.ts", segmentTasks[i].Index))
	}

	// Cache for encryption keys (URL -> byte slice)
	keyCache := make(map[string][]byte)
	var keyMutex sync.Mutex

	downloadStartTime := time.Now()

	// Download segments concurrently
	err = downloadSegmentsConcurrently(segmentTasks, concurrency, &keyCache, &keyMutex, downloadStartTime)
	if err != nil {
		return fmt.Errorf("downloading segments failed: %w", err)
	}

	fmt.Println("\n\n📦 Merging video segments into single output file...")
	totalBytesWritten, err := mergeSegments(segmentTasks, finalOutputPath)
	if err != nil {
		return fmt.Errorf("merging segments failed: %w", err)
	}

	if totalBytesWritten == 0 {
		return fmt.Errorf("output file is 0 bytes (no data merged)")
	}

	elapsedTime := time.Since(downloadStartTime)
	printSuccessSummary(finalOutputPath, totalSegments, totalBytesWritten, elapsedTime)
	return nil
}

// cleanInput trims spaces, tabs, newlines, and surrounding double/single quotes from user input
func cleanInput(input string) string {
	s := strings.TrimSpace(input)
	s = strings.Trim(s, "\"\r\n\t'")
	return strings.TrimSpace(s)
}

// fetchAndParseManifest handles fetching and decoding master or media playlists
func fetchAndParseManifest(manifestURL string) ([]SegmentTask, error) {
	req, err := http.NewRequest("GET", manifestURL, nil)
	if err != nil {
		return nil, fmt.Errorf("invalid request: %w", err)
	}
	req.Header.Set("User-Agent", userAgent)
	req.Header.Set("Accept", "*/*")

	resp, err := httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to URL: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("server returned HTTP %d (%s)", resp.StatusCode, resp.Status)
	}

	playlist, playlistType, err := m3u8.DecodeFrom(resp.Body, true)
	if err != nil {
		return nil, fmt.Errorf("failed to decode m3u8 playlist format: %w", err)
	}

	baseURL, err := url.Parse(manifestURL)
	if err != nil {
		return nil, fmt.Errorf("invalid base URL: %w", err)
	}

	switch playlistType {
	case m3u8.MASTER:
		masterPl := playlist.(*m3u8.MasterPlaylist)
		var bestVariant *m3u8.Variant
		var maxBandwidth uint32

		for _, variant := range masterPl.Variants {
			if variant != nil && variant.Bandwidth > maxBandwidth {
				maxBandwidth = variant.Bandwidth
				bestVariant = variant
			}
		}

		if bestVariant == nil {
			return nil, fmt.Errorf("master playlist contains no valid stream variants")
		}

		variantURL, err := resolveURL(baseURL, bestVariant.URI)
		if err != nil {
			return nil, fmt.Errorf("failed to resolve variant stream URL: %w", err)
		}

		fmt.Printf("ℹ Master playlist detected. Selected highest quality stream (Bandwidth: %d bps)\n", bestVariant.Bandwidth)
		return fetchAndParseManifest(variantURL)

	case m3u8.MEDIA:
		mediaPl := playlist.(*m3u8.MediaPlaylist)
		var tasks []SegmentTask
		var currentKey *m3u8.Key

		for i, seg := range mediaPl.Segments {
			if seg == nil {
				continue
			}

			if seg.Key != nil {
				currentKey = seg.Key
			}

			segURL, err := resolveURL(baseURL, seg.URI)
			if err != nil {
				return nil, fmt.Errorf("segment %d URL error: %w", i, err)
			}

			tasks = append(tasks, SegmentTask{
				Index: i,
				URL:   segURL,
				Key:   currentKey,
			})
		}
		return tasks, nil

	default:
		return nil, fmt.Errorf("unsupported or unrecognized M3U8 playlist format")
	}
}

// resolveURL resolves relative path URIs against the base playlist URL
func resolveURL(base *url.URL, relative string) (string, error) {
	relURL, err := url.Parse(relative)
	if err != nil {
		return "", err
	}
	return base.ResolveReference(relURL).String(), nil
}

// downloadSegmentsConcurrently downloads all segments using a worker pool pattern
func downloadSegmentsConcurrently(tasks []SegmentTask, workers int, keyCache *map[string][]byte, keyMutex *sync.Mutex, startTime time.Time) error {
	total := len(tasks)
	tasksChan := make(chan SegmentTask, total)
	errChan := make(chan error, total)
	var completedCount uint64
	var totalDownloadedBytes uint64

	for _, t := range tasks {
		tasksChan <- t
	}
	close(tasksChan)

	var wg sync.WaitGroup

	for i := 0; i < workers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for task := range tasksChan {
				bytesCount, err := downloadSingleSegment(task, keyCache, keyMutex)
				if err != nil {
					errChan <- fmt.Errorf("segment %d error: %w", task.Index, err)
					return
				}

				atomic.AddUint64(&totalDownloadedBytes, uint64(bytesCount))
				newCompleted := atomic.AddUint64(&completedCount, 1)

				renderProgressBar(int(newCompleted), total, atomic.LoadUint64(&totalDownloadedBytes), startTime)
			}
		}()
	}

	wg.Wait()
	close(errChan)

	if len(errChan) > 0 {
		return <-errChan
	}
	return nil
}

// downloadSingleSegment handles downloading, optional key fetching, and AES decryption for a segment
func downloadSingleSegment(task SegmentTask, keyCache *map[string][]byte, keyMutex *sync.Mutex) (int, error) {
	maxRetries := 3
	var lastErr error

	for attempt := 1; attempt <= maxRetries; attempt++ {
		data, err := fetchURLBytes(task.URL)
		if err == nil {
			// Decrypt if AES-128 key is specified
			if task.Key != nil && strings.ToUpper(task.Key.Method) == "AES-128" {
				decryptedData, decErr := decryptSegment(data, task, keyCache, keyMutex)
				if decErr != nil {
					return 0, fmt.Errorf("decryption error: %w", decErr)
				}
				data = decryptedData
			}

			// Write segment data to disk
			err = os.WriteFile(task.Path, data, 0644)
			if err == nil {
				return len(data), nil
			}
		}

		lastErr = err
		time.Sleep(time.Duration(attempt*500) * time.Millisecond)
	}

	return 0, fmt.Errorf("after %d attempts: %w", maxRetries, lastErr)
}

// decryptSegment decrypts AES-128 encrypted HLS segments
func decryptSegment(data []SegmentTaskData, task SegmentTask, keyCache *map[string][]byte, keyMutex *sync.Mutex) ([]byte, error) {
	keyURL := task.Key.URI
	keyMutex.Lock()
	keyBytes, exists := (*keyCache)[keyURL]
	keyMutex.Unlock()

	if !exists {
		fetchedKey, err := fetchURLBytes(keyURL)
		if err != nil {
			return nil, fmt.Errorf("failed to fetch key from %s: %w", keyURL, err)
		}
		keyMutex.Lock()
		(*keyCache)[keyURL] = fetchedKey
		keyBytes = fetchedKey
		keyMutex.Unlock()
	}

	if len(keyBytes) != 16 {
		return nil, fmt.Errorf("invalid AES key length: %d (expected 16 bytes)", len(keyBytes))
	}

	// Determine IV (Initialization Vector)
	var iv []byte
	if task.Key.IV != "" {
		iv = []byte(task.Key.IV)
	} else {
		// Default IV is sequence number formatted as 16-byte BigEndian integer
		iv = make([]byte, 16)
		binary.BigEndian.PutUint64(iv[8:], uint64(task.Index))
	}

	block, err := aes.NewCipher(keyBytes)
	if err != nil {
		return nil, err
	}

	if len(data)%aes.BlockSize != 0 {
		return nil, fmt.Errorf("encrypted segment size %d is not multiple of block size", len(data))
	}

	mode := cipher.NewCBCDecrypter(block, iv)
	decrypted := make([]byte, len(data))
	mode.CryptBlocks(decrypted, data)

	// PKCS#7 Unpadding
	unpadded, err := pkcs7Unpad(decrypted, aes.BlockSize)
	if err != nil {
		return decrypted, nil // Fallback to raw decrypted data if unpadding fails
	}
	return unpadded, nil
}

type SegmentTaskData = byte

func pkcs7Unpad(b []byte, blockSize int) ([]byte, error) {
	if len(b) == 0 {
		return nil, fmt.Errorf("empty slice")
	}
	if len(b)%blockSize != 0 {
		return nil, fmt.Errorf("data length is not a multiple of block size")
	}
	c := b[len(b)-1]
	n := int(c)
	if n == 0 || n > blockSize || n > len(b) {
		return nil, fmt.Errorf("invalid padding")
	}
	for i := 0; i < n; i++ {
		if b[len(b)-n+i] != c {
			return nil, fmt.Errorf("invalid padding byte")
		}
	}
	return b[:len(b)-n], nil
}

// fetchURLBytes fetches raw bytes from an HTTP URL
func fetchURLBytes(targetURL string) ([]byte, error) {
	req, err := http.NewRequest("GET", targetURL, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", userAgent)
	req.Header.Set("Accept", "*/*")

	resp, err := httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("HTTP status %d", resp.StatusCode)
	}

	var buf bytes.Buffer
	_, err = io.Copy(&buf, resp.Body)
	if err != nil {
		return nil, err
	}

	return buf.Bytes(), nil
}

// renderProgressBar prints an interactive real-time progress bar with download speed, downloaded size, and ETA
func renderProgressBar(completed, total int, downloadedBytes uint64, startTime time.Time) {
	percent := float64(completed) / float64(total) * 100.0
	barWidth := 25
	filled := int(float64(barWidth) * float64(completed) / float64(total))

	bar := strings.Repeat("█", filled) + strings.Repeat("░", barWidth-filled)

	downloadedMB := float64(downloadedBytes) / (1024 * 1024)
	elapsedSec := time.Since(startTime).Seconds()

	speedMBs := 0.0
	etaStr := "--:--"
	if elapsedSec > 0 {
		speedMBs = downloadedMB / elapsedSec
		if completed > 0 && completed < total {
			avgTimePerSeg := elapsedSec / float64(completed)
			remainingSegs := total - completed
			etaSec := time.Duration(avgTimePerSeg*float64(remainingSegs)) * time.Second
			etaSec = etaSec.Round(time.Second)
			mins := int(etaSec.Minutes())
			secs := int(etaSec.Seconds()) % 60
			etaStr = fmt.Sprintf("%02dm:%02ds", mins, secs)
		} else if completed >= total {
			etaStr = "00m:00s"
		}
	}

	fmt.Printf("\r⏳ Downloading: [%s] %5.1f%% (%d/%d) | 💾 %.2f MB | 🚀 %.2f MB/s | ⏱ ETA: %s",
		bar, percent, completed, total, downloadedMB, speedMBs, etaStr)
}

// mergeSegments concatenates downloaded temp segment files into final output file
func mergeSegments(tasks []SegmentTask, outputPath string) (int64, error) {
	outFile, err := os.Create(outputPath)
	if err != nil {
		return 0, fmt.Errorf("failed to create output file: %w", err)
	}
	defer outFile.Close()

	var totalBytes int64

	for _, task := range tasks {
		segFile, err := os.Open(task.Path)
		if err != nil {
			return totalBytes, fmt.Errorf("failed to open segment %d (%s): %w", task.Index, task.Path, err)
		}

		n, err := io.Copy(outFile, segFile)
		segFile.Close()
		if err != nil {
			return totalBytes, fmt.Errorf("failed to write segment %d to output: %w", task.Index, err)
		}
		totalBytes += n
	}

	return totalBytes, nil
}

func printSuccessSummary(outputPath string, totalSegments int, totalBytes int64, duration time.Duration) {
	absPath, err := filepath.Abs(outputPath)
	if err != nil {
		absPath = outputPath
	}

	sizeMB := float64(totalBytes) / (1024 * 1024)

	fmt.Println("==================================================")
	fmt.Println("🎉  DOWNLOAD & MERGE COMPLETE!")
	fmt.Println("==================================================")
	fmt.Printf("📁 Saved File Location : %s\n", absPath)
	fmt.Printf("🧩 Total Segments      : %d\n", totalSegments)
	fmt.Printf("💾 Total File Size     : %.2f MB (%d bytes)\n", sizeMB, totalBytes)
	fmt.Printf("⏱  Total Elapsed Time   : %s\n", duration.Round(time.Millisecond))
	fmt.Println("==================================================")
}
