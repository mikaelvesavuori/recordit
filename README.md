# RecordIt

A macOS menu bar app for recording system audio from any application — lossless or lossy. Built to replace manual solutions like BlackHole or paid apps like Dipper.

## Features

- **App-specific capture** — record audio from any running app (Apple Music, Safari, Spotify, etc.)
- **No virtual audio devices** — uses Core Audio process taps, no BlackHole or loopback needed
- **Format options** — ALAC (lossless) or AAC (lossy), with quality settings
- **Menu bar app** — lives in your menu bar, always one click away
- **Configurable output** — choose where recordings are saved

## Requirements

- macOS 15.0 or later
- Xcode 16+ (for building from source)

## Build & Run

```bash
make run
```

## Tests

```bash
make test
```

## Package Release

```bash
make package          # build + test + zip + DMG
make package-fast     # skip tests
```

## Architecture

RecordIt is split into two targets:

- **RecordItCore** — capture engine (CATap + aggregate device), file writer (AVAudioFile), recording storage, models
- **RecordIt** — SwiftUI menu bar app UI and app state

The app uses Core Audio process taps (`CATapDescription` + `AudioHardwareCreateProcessTap`) wrapped in a private `AudioAggregateDevice` to capture audio from a specific process without virtual loopback devices. Audio is encoded via `AVAudioFile` to ALAC or AAC.

## License

MIT — see [LICENSE](LICENSE).
