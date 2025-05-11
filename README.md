# Vocal Liquid

A macOS menu bar application for quick audio transcription using Whisper.

## Features

- Records audio between hotkey presses (default: Option-Shift-T to start/stop)
- Automatically transcribes recorded audio using Whisper
- Copies transcription to clipboard
- Visual indicator when recording is active
- Notifications for recording status and transcription results
- Works offline - all processing is done on your device

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
4. Run `./setup_startup.sh` to configure the app to start at login (optional)

## Usage

1. Launch VocalLiquid from Applications or have it start automatically at login
2. The app will appear as a small waveform icon in your menu bar
3. Press Option-Shift-T to start recording
4. The icon will turn orange while recording (along with a system microphone indicator)
5. Press Option-Shift-T again to stop recording
6. After a brief processing delay, the transcribed text will be copied to your clipboard
7. You'll receive a notification when transcription is complete

## Menu Options

Click the menu bar icon to access the following options:

- **Force Release Microphone**: Use if the system microphone indicator gets stuck
- **Gentle Reset Icon**: Attempt to reset the menu bar icon if it's stuck
- **Nuclear Reset Icon**: Stronger approach to reset the icon if it's stuck
- **ULTRA NUCLEAR Reset Icon**: Last resort if icon is still stuck
- **Quit**: Exit the application

## Troubleshooting

### Permissions

VocalLiquid requires microphone permission to record audio and notification permission to display status updates. If you encounter permission prompts:

1. Grant the permissions when requested
2. If you get repeated prompts, run `./fix_permissions.sh` to reset permission state

### Orange Microphone Indicator Stuck

If the orange microphone indicator in the system menu bar stays on after stopping recording:

1. Click the VocalLiquid menu bar icon
2. Select "Force Release Microphone" from the menu

### Menu Bar Icon Issues

If the menu bar icon remains orange after stopping recording:

1. Click the VocalLiquid menu bar icon
2. Try "Gentle Reset Icon" first
3. If that doesn't work, try "Nuclear Reset Icon"
4. As a last resort, try "ULTRA NUCLEAR Reset Icon"

## Development

This project is structured as follows:

- `Managers/` - Core management classes for audio, transcription, hotkeys, and the status bar
- `Services/` - Support services like logging
- `Utilities/` - Helper utilities and permission management
- `Views/` - SwiftUI views (for future enhancements)

### Building from Source

1. Clone the repository
2. Open `VocalLiquid.xcodeproj` in Xcode
3. Build and run the project

## License

All rights reserved.

## Acknowledgments

- Based on Whisper.cpp for efficient speech recognition
- Uses the ggml-base.en.bin model for English transcription