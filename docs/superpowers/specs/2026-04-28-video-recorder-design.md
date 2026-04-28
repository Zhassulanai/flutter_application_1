# Video Recorder Feature — Design Spec
**Date:** 2026-04-28

## Overview

Add a background video recorder to the existing Flutter messenger app. The recorder captures video simultaneously from the rear and front cameras, continues recording when the screen is off (foreground service), and composites both streams into a single `.mp4` file with a PiP overlay (front camera as a circle in the top-left corner).

---

## Goals

- Record video from rear + front cameras simultaneously
- Continue recording with the screen turned off
- Save a single composited `.mp4` to internal app storage (not visible in gallery)
- View, share (to chat or export), and delete recordings from within the app
- Graceful fallback if device does not support concurrent cameras

---

## Architecture

```
Flutter UI (VideoRecorderScreen)
        │  MethodChannel("video_recorder")
        ▼
Kotlin VideoRecorderPlugin + VideoRecorderService (ForegroundService)
        │
        ├── Camera2 API
        │     ├── CameraDevice (rear)  → MediaRecorder → back.mp4  (temp)
        │     └── CameraDevice (front) → MediaRecorder → front.mp4 (temp)
        │
        └── VideoCompositor (runs after Stop)
              ├── MediaCodec — decodes back.mp4 and front.mp4
              ├── OpenGL ES — renders rear full-frame, front as circular PiP (top-left, ~25% width)
              └── MediaCodec encoder + MediaMuxer → output_<timestamp>.mp4
```

Temp files are deleted after successful composition.

---

## Android Native (Kotlin)

### Classes

**`VideoRecorderPlugin`**
Registers `MethodChannel("video_recorder")` and handles Flutter calls:
- `initialize` — checks concurrent camera support via `getConcurrentCameraIds()`; returns TextureIds for preview surfaces
- `startRecording` — opens both `CameraDevice`s, starts two `MediaRecorder` instances
- `stopRecording` — stops recorders, invokes `VideoCompositor`, returns path to final file
- `getVideos` — returns list of files from `filesDir/videos/`
- `deleteVideo(path)` — deletes file and removes DB record
- `getThumbnail(path)` — generates thumbnail via `MediaMetadataRetriever`

**`VideoRecorderService`** (extends `ForegroundService`)
Keeps camera sessions alive when the screen is off. Integrates with existing `foreground_service.dart` infrastructure.

**`VideoCompositor`**
- Decodes `back.mp4` and `front.mp4` via `MediaCodec`
- OpenGL ES shader: rear camera fills the frame; front camera rendered as a circular mask, top-left corner, ~25% of frame width
- Encodes output via `MediaCodec` encoder + `MediaMuxer` → `output_<timestamp>.mp4`

### Permissions (AndroidManifest.xml)
```xml
CAMERA
RECORD_AUDIO
FOREGROUND_SERVICE
FOREGROUND_SERVICE_CAMERA
```

### Concurrent camera fallback
If `getConcurrentCameraIds()` returns no pair containing both front and rear cameras, show an error dialog to the user and record only the rear camera.

---

## Flutter UI

### Screens

**`VideoRecorderScreen`**
- Rear camera preview fills the full screen (`AndroidView` → `TextureView`)
- Front camera preview: circular widget, top-left corner, ~25% of screen width (`AndroidView` with circular clip)
- Start/Stop button centered at the bottom
- Recording timer (`00:00:00`) at the top
- "Processing…" indicator shown after Stop while composition runs

**`VideoLibraryScreen`**
- List of recordings: thumbnail, date, duration, file size
- Per-item actions: Play, Share, Delete

**`VideoPlayerScreen`**
- Full-screen playback via `video_player` package
- Back and Share buttons

### BLoC

`VideoRecorderBloc` with states:
```
idle → recording → processing → done
                             → error(message)
```

---

## Data

### File system

```
filesDir/
└── videos/
    ├── tmp_<timestamp>/
    │     ├── back.mp4        (deleted after composition)
    │     └── front.mp4       (deleted after composition)
    └── output_<timestamp>.mp4
```

### Database (existing SQLite via `database.dart`)

New table `recordings`:

| Column       | Type    | Notes                  |
|--------------|---------|------------------------|
| id           | TEXT    | PRIMARY KEY (UUID)     |
| file_path    | TEXT    | absolute path          |
| created_at   | INTEGER | unix timestamp (ms)    |
| duration_ms  | INTEGER |                        |
| size_bytes   | INTEGER |                        |

### Sharing

- **Send to chat** — via existing `FileTransfer` mechanism (`file_transfer.dart`)
- **Export** — via Android `Intent.ACTION_SEND` (system share sheet); add `share_plus` package

---

## Dependencies to add

| Package       | Purpose                        |
|---------------|--------------------------------|
| `video_player` | In-app video playback         |
| `share_plus`   | Export via system share sheet |

---

## Out of Scope

- Automatic chunking / segment recording
- Saving to gallery / public storage
- In-app video trimming or editing
- iOS support (Android only for this feature)
