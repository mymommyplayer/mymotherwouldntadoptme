# MyMoThErWoUlDnTaDoPtMe

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)](https://www.apple.com/macos/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A macOS music player. Paste a YouTube or SoundCloud playlist URL, set a looping video background, and play. Discovery mode finds similar tracks automatically when each one ends.

Inspired by [nuclearplayer.com](https://nuclearplayer.com) and the visual style of [のろヰ](https://lit.link/en/rnatataki) and [@mentaldisorders_](https://www.youtube.com/@mentaldisorders_).

![Demo]((_-_).gif)

## Features

- **Dual-source search** — YouTube and SoundCloud results merged into one list
- **Background video** — loop a video, GIF, or image behind all tracks. Each playlist can have its own background.
- **Discovery** — when a track ends, queries Last.fm for similar tracks, picks one weighted by match strength, and queues it
- **Queue** — drag-reorder, persistent across launches, play-next insertion
- **Import** — paste a YouTube/SoundCloud playlist URL, fetches all tracks automatically
- **Crossfade** — configurable crossfade between tracks (0.5–10s)
- **Control Center** — reports track info, artwork, and remote commands to macOS
- **Keyboard shortcuts** — Space, arrows, S/R/L, Cmd+F

## Building

Requires Xcode 15+, macOS 14.0+.

```bash
git clone https://github.com/mymommyplayer/mymotherwouldntadoptme.git
cd mymotherwouldntadoptme
```

1. Open `MyMoThErWoUlDnTaDoPtMe.xcodeproj` in Xcode
2. Select the `MyMoThErWoUlDnTaDoPtMe` scheme
3. Build and run (Cmd+R)


### API keys

Last.fm and SoundCloud require API keys. Create `Config.xcconfig` in the project root:

```
LASTFM_API_KEY=your_key_here
SOUNDCLOUD_CLIENT_ID=your_id_here
```

Get a Last.fm key at https://www.last.fm/api/account/create. SoundCloud client ID requires a registered app at https://soundcloud.com/you/apps.

Without these keys, streaming still works but Last.fm discovery and SoundCloud playlists will fail.

## Project structure

```
MyMoThErWoUlDnTaDoPtMe/
├── App.swift                         @main entry point
├── ContentView.swift                 root view
├── WindowManager.swift               window config
├── SearchResult.swift                track model
├── SourceProvider.swift              provider protocol
├── YouTubeProvider.swift             YouTube search/stream via yt-dlp
├── SoundCloudProvider.swift          SoundCloud search/stream via yt-dlp
├── Core/
│   ├── AppContainer.swift            dependency injection
│   ├── BackgroundManager.swift       video/GIF/image backgrounds
│   ├── BackgroundMode.swift          background mode enum
│   ├── SecretsLoader.swift           reads Config.xcconfig
│   └── LastFMAPIKey.swift            loads Last.fm key
├── CoreData/
│   ├── PersistenceController.swift   CoreData stack
│   ├── PlaylistEntity.swift          playlist model
│   └── PlaylistTrackEntity.swift     track model
├── Discovery/
│   ├── DiscoveryManager.swift        auto-discovery via Last.fm
│   ├── LastFMService.swift           Last.fm API calls
│   └── SimilarTrack.swift            response models
├── Networking/
│   └── NetworkClient.swift           URLSession wrapper
├── Player/
│   ├── AudioPlayer.swift             AVPlayer playback + crossfade
│   ├── PlayerState.swift             playback state enum
│   ├── StreamExpiryManager.swift     stream URL TTL tracking
│   └── NowPlayingManager.swift       Control Center integration
├── Queue/
│   ├── QueueItem.swift               queue item model
│   ├── QueueManager.swift            queue CRUD + persistence
│   └── QueueManagerProtocol.swift    queue protocol
├── Services/
│   ├── YTDLP.swift                   yt-dlp CLI wrapper
│   ├── PlaylistService.swift         playlist CRUD
│   └── PlaylistImportService.swift   import from URL
├── ViewModels/
│   ├── SearchViewModel.swift         search with debounce
│   └── FavoritesManager.swift        favorites (UserDefaults)
├── Views/
│   ├── DesignTokens.swift            spacing, colors, fonts
│   ├── ControlCenterView.swift       main panel
│   ├── QueuePanelView.swift          queue sidebar
│   ├── NowPlayingBar.swift           player bar
│   ├── SettingsView.swift            settings
│   ├── BackgroundContainer.swift     background renderer
│   ├── VideoBackgroundView.swift     AVPlayer layer
│   ├── KeyboardShortcutsHandler.swift
│   └── ... (search, playlists, artwork, empty states)
├── Resources/
│   └── AppIcon.icns                  app icon
└── Assets.xcassets/                  icon assets
```

## How it works

**AudioPlayer** wraps `AVPlayer` with dual-player crossfade. **QueueManager** holds the track list, persists to UserDefaults, and advances on track end. **PlaylistImportService** parses YouTube/SoundCloud playlist URLs, extracts IDs, fetches track lists via Piped API (YouTube) or SoundCloud API v2, and stores them in CoreData.

**DiscoveryManager** runs after each track finishes. It calls `track.getSimilar` on Last.fm, falls back to `artist.getSimilar` → `artist.getTopTracks` if needed, picks a track weighted by match percentage, searches YouTube/SoundCloud for it via yt-dlp, and queues the result. A variety slider controls how close matches are.

**BackgroundManager** renders video via `AVQueuePlayer` with `AVPlayerLooper`, images via `NSImage`, GIFs via `AVQueuePlayer`. Playlists can bind a background; switching playlists switches the background.

Stream URLs expire. **StreamExpiryManager** tracks TTL per stream (30min–4hr configurable) and re-resolves the URL before playback.

## Keyboard shortcuts

| Key | Action |
|-----|--------|
| Space | Play/Pause |
| Left/Right | Previous/Next track |
| Up/Down | Volume ± |
| S | Toggle shuffle |
| R | Toggle repeat |
| L | Toggle discovery |
| Cmd+F | Focus search |
| Escape | Toggle control panel |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Support

[![Donate](https://img.shields.io/badge/Donate-DonationAlerts-red.svg)](https://www.donationalerts.com/r/mymommyplayer)

## License

MIT — see [LICENSE](LICENSE).
