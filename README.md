# MyMoThErWoUlDnTaDoPtMe

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)](https://www.apple.com/macos/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A macOS music player that plays a single video or GIF loop behind entire playlists—import from YouTube or SoundCloud, set a background, and let it run.

Inspired by [nuclearplayer.com](https://nuclearplayer.com) and the visual style of [のろヰ](https://lit.link/en/rnatataki) and [@mentaldisorders_](https://www.youtube.com/@mentaldisorders_).

![Demo]((_-_).gif)

## What it does

- Import playlists from YouTube or SoundCloud
- Play them with a single background video or GIF behind all the tracks
- Manage playback (shuffle, repeat modes), favorites, queue
- Adjust volume, see now-playing info in the Control Center
- Discovery mode: auto-play similar tracks (via Last.fm) when one finishes

## Building and running 

Requires Swift 5.9, macOS 14.0 or later.

```bash
git clone https://github.com/mymommyplayer/mymotherwouldntadoptme.git
cd mymotherwouldntadoptme
chmod +x run.sh
./run.sh
```

## Tests

```bash
swift test
```

Tests cover YouTube and SoundCloud URL parsing (various formats, edge cases), CoreData operations (adding/removing tracks, index ordering).

## How it works 

**ContentView** owns the main UI. It delegates to:

- **AudioPlayer**: handles playback
- **QueueManager**: track ordering and queue state
- **PlaylistImportService**: fetch and parse YouTube/SoundCloud URLs, create playlists in CoreData
- **YouTubeProvider** / **SoundCloudProvider**: network calls and response parsing
- **BackgroundManager**: video/GIF rendering
- **DiscoveryManager**: queries Last.fm for similar tracks, auto-queues them when current track ends
- **FavoritesManager**, **NowPlayingManager**: state for favorites and Control Center display

Data lives in CoreData: **PlaylistEntity** (the playlist itself) and **PlaylistTrackEntity** (individual tracks, stored with index order).

The import flow: user pastes a URL → service extracts the playlist ID → provider fetches track list → tracks get stored locally → they play against the user's chosen background.

Discovery mode: when a track finishes, DiscoveryManager asks Last.fm for similar tracks, picks one weighted by match strength, searches YouTube/SoundCloud for it, resolves the stream, and queues it. A[...]

## Project structure

```
Sources/MyMoThErWoUlDnTaDoPtMe/
├── ContentView.swift
├── Core/
│   └── AppContainer.swift
├── Services/
│   └── PlaylistImportService.swift
├── Managers/
│   ├── AudioPlayer.swift
│   ├── QueueManager.swift
│   ├── BackgroundManager.swift
│   ├── DiscoveryManager.swift
│   ├── FavoritesManager.swift
│   └── NowPlayingManager.swift
├── Providers/
│   ├── YouTubeProvider.swift
│   └── SoundCloudProvider.swift
└── Resources/

Tests/MyMoThErWoUlDnTaDoPtMe/
├── PlaylistImportServiceTests.swift
└── CoreDataTests.swift 

```

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Support

If you enjoy this project, consider supporting it:

[![Donate](https://img.shields.io/badge/Donate-DonationAlerts-red.svg)](https://www.donationalerts.com/r/mymommyplayer)

## License 

MIT - See [LICENSE](LICENSE) for details
