# Vocal Liquid

A macOS menu bar application for quick audio transcription using Whisper.

## Features

- Records audio between hotkey presses (default: Command-Shift-R to start/stop)
- Automatically transcribes recorded audio using Whisper
- Copies transcription to clipboard
- Visual indicator when recording is active

## Technical Details

- Uses whisper.cpp via xcframework with the base English model
- Maximum recording duration: 4 hours
- Records high-quality audio and processes the full recording
- Runs as a menu bar application

## Requirements

- macOS 14.0 or later
- Xcode 15.0 or later (for development)

## Installation

1. Download the latest release
2. Move the application to your Applications folder
3. Launch the application

## Usage

1. Press Command-Shift-R to start recording
2. Speak your content
3. Press Command-Shift-R again to stop recording
4. The transcription will be processed and copied to your clipboard automatically
5. A visual indicator in the menu bar shows when recording is active

## Development

This project is structured as follows:

- `Managers/` - Core management classes for audio, transcription, hotkeys, and the status bar
- `Services/` - Support services like logging
- `Utilities/` - Helper utilities
- `Views/` - SwiftUI views (for future enhancements)

### Building from Source

1. Clone the repository
2. Open `VocalLiquid.xcodeproj` in Xcode
3. Build and run the project

## License

All rights reserved.