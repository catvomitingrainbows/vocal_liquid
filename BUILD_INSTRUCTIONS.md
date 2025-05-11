# Build Instructions for VocalLiquid

## Prerequisites

- Xcode 14.0 or later
- macOS 11.0 or later (recommended)

## Building the Application

1. First, run the build preparation script:

```bash
./build.sh
```

This script:
- Creates necessary directories
- Copies the whisper model file to the Resources directory
- Ensures the whisper.xcframework is in the correct location

2. Open the project in Xcode:

```bash
open VocalLiquid.xcodeproj
```

3. In Xcode, make sure the Resources folder (with the model file) is included in the target:
   - Select the VocalLiquid project in the navigator
   - Select the VocalLiquid target
   - Go to the "Build Phases" tab
   - Expand "Copy Bundle Resources"
   - Click the "+" button and select the "Resources/ggml-base.en.bin" file
   - Also ensure the "whisper.xcframework" is included in "Frameworks, Libraries, and Embedded Content"

4. Build and run the application (⌘R)

## Debugging

If the application builds but doesn't appear in the menu bar:

1. Check the console output in Xcode for any errors
2. Verify the model file exists in the built application bundle:
   - Right-click on the built app in Finder
   - Select "Show Package Contents"
   - Navigate to Contents/Resources
   - Confirm "ggml-base.en.bin" exists in this directory

3. If the model is missing, manually copy it to the application bundle:
```bash
cp VocalLiquid/Resources/ggml-base.en.bin /path/to/built/VocalLiquid.app/Contents/Resources/
```

## Common Issues and Solutions

### Model File Not Found
Error: "Error: Model file not found in bundle"

Solution: 
- Make sure the model file is included in the "Copy Bundle Resources" build phase
- Run the `build.sh` script to ensure the model file is in the correct location

### App Not Showing in Menu Bar
If the app builds but doesn't appear in the menu bar:

- Check the Console app for any error messages from VocalLiquid
- Make sure your macOS version is supported (macOS 10.15 or later)
- Try running the app from the command line for more verbose output:
```bash
/path/to/VocalLiquid.app/Contents/MacOS/VocalLiquid
```