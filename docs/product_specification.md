# Whisper Transcription Tool - Product Specification

## Core Functionality
- macOS application that runs in the menubar
- Uses whisper.cpp (via xcframework) with the base model for transcription
- Records audio between hotkey presses (push to start, push to stop)
- Automatically transcribes recorded audio and copies to clipboard
- Shows a popup window that briefly displays transcription before auto-dismissing
- Visual indicator when recording is active

## Technical Details
- Full recording method for transcription (no chunking)
- Maximum recording duration: 4 hours
- Expected processing time: ~3-6 seconds per minute of audio on M1 Max
- Supports recordings typically 30-60 seconds, occasionally up to 5 minutes
- Configuration stored in config file, not UI preferences panel
- Error handling via log files

## User Experience
- Launches automatically at login
- System notifications when transcription is complete
- Minimal interaction required - emphasizes ease of use and efficiency
- Configurable global hotkey for starting/stopping recording

## Future Enhancement (post-MVP)
- History of last 5 transcriptions in menubar dropdown
- Ability to select and copy previous transcriptions to clipboard
- Clear history function
- Persistent history between app restarts