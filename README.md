# CloudyTabsSwift

A Swift rewrite of CloudyTabs - a macOS menu bar application that displays your iCloud Safari tabs from other devices.

## Features

- Display iCloud tabs from all your devices in the menu bar
- Display Safari Reading List items
- Open tabs with various modifier keys (Command, Option)
- Export tabs to CSV
- Launch at login support
- Full Disk Access integration

## Dependencies

This project requires the following dependencies to be added via Swift Package Manager:

1. **FMDB** - SQLite wrapper for reading Safari's CloudTabs.db
   - Repository: https://github.com/ccgus/fmdb
   - Version: Latest

2. **Sparkle** (Optional) - For automatic updates
   - Repository: https://github.com/sparkle-project/Sparkle
   - Version: Latest

## Setup Instructions

1. Open the project in Xcode
2. Go to File → Add Package Dependencies
3. Add the following packages:
   - `https://github.com/ccgus/fmdb.git`
   - `https://github.com/sparkle-project/Sparkle.git` (optional)

## Building

1. Ensure all dependencies are resolved
2. Build and run the project
3. Grant Full Disk Access in System Preferences if prompted

## Notes

- The app requires Full Disk Access to read Safari's database files
- File watching functionality (VDKQueue) is not yet implemented - the menu refreshes when opened
- Favicon support (DSFavIconManager) is not yet implemented - using placeholder images

## Differences from Original

- Written entirely in Swift instead of Objective-C
- Uses Swift Package Manager instead of Carthage
- Some third-party dependencies may need to be replaced or reimplemented:
  - VDKQueue for file watching (can be replaced with FileSystemEventStream)
  - DSFavIconManager for favicons (can be replaced with custom implementation or another library)
  - CHCSVParser for CSV export (replaced with custom implementation)
