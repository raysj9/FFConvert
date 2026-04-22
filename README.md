# FFConvert

FFConvert is a small macOS app for converting media files with FFmpeg.

## Features

- Choose or drop a media file
- Inspect basic video and audio stream details
- Convert to MP4 H.264, HEVC, MP3, AAC, or GIF
- Pick an output folder
- View recent conversion results

## Requirements

- macOS 26.2 or later
- Xcode 26.3 or later
- FFmpeg and FFprobe installed with Homebrew

```sh
brew install ffmpeg
```

## Run

1. Open `FFConvert.xcodeproj` in Xcode.
2. Select the `FFConvert` scheme.
3. Build and run the app.

By default, the app looks for:

- `/opt/homebrew/bin/ffmpeg`
- `/opt/homebrew/bin/ffprobe`
