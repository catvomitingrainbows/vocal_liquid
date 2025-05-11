# Development Roadmap

## Phase 1: Core Infrastructure (MVP)
1. Setup project with Swift and SwiftUI
2. Integrate whisper.cpp xcframework
3. Implement menu bar application structure
4. Create audio recording functionality
   - Start/stop recording with hotkey
   - Handle audio permissions
5. Build basic transcription pipeline
   - Process full audio file with whisper.cpp
   - Copy result to clipboard
6. Add visual recording indicator
7. Implement basic error logging

## Phase 2: User Experience
1. Create popup window for displaying transcription results
2. Implement system notifications for completion
3. Add global hotkey configuration
4. Enable launch at login functionality
5. Create basic config file structure
6. Add maximum recording duration limit (4 hours)

## Phase 3: Refinement & Testing
1. Optimize transcription performance
2. Improve error handling and recovery
3. Memory optimization for longer recordings
4. Battery usage optimization
5. Comprehensive testing across recording scenarios
6. Create installer and distribution package

## Phase 4: History Feature (Post-MVP)
1. Implement transcription history storage
2. Add menu bar dropdown UI for history display
3. Enable selecting/copying previous transcriptions
4. Add clear history functionality
5. Implement persistent storage between app restarts

## Phase 5: Future Enhancements
1. Support for different whisper.cpp models
2. Customizable popup display duration
3. Keyboard shortcut for accessing history
4. Export functionality for transcription history
5. Basic editing capabilities for transcriptions before copying