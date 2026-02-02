# PickleClipper macOS App Spec

## 1. Clarifying Questions (max 8)
1. Should clips be trimmed **frame-accurately** (slow) or is keyframe-accurate acceptable for speed? (AVFoundation export is usually frame-accurate, but can be slower for long clips.)
2. Do you want **portrait/landscape preservation** as-is (letterbox if resizing) or should the app **crop** to fill target resolution?
3. Are clips **always within one video** per export session, or do you need batch processing of multiple source videos later?
4. Do you need **timecode input in SMPTE format** with frames (e.g., `00:01:23:15`), or is seconds-level precision enough for V1?
5. Should exports **overwrite** existing files or append a suffix like `_v2` when conflicts occur?
6. Do you want a **preview** player for scrub/check, or is timestamp-only input acceptable for V1?
7. Is a **single output codec** acceptable (H.264 + AAC), or do you need HEVC for smaller files?
8. Should the app support **drag & drop** for video import in V1?

## 2. Functional Spec (requirements + edge cases)
### Core requirements
- Import a single source video file (MOV/MP4/M4V). Validate supported codecs via AVFoundation.
- Allow multiple clip ranges defined as `Start - End` with `HH:MM:SS` or `MM:SS` input.
- User picks output folder; remember the last-used folder.
- Resolution selection: Same as source, 1080p, 720p, Custom (width x height).
- Export each clip to its own MP4 (H.264 + AAC). Preserve audio if present.
- Non-blocking exports with per-clip progress and overall progress.

### Validation & errors
- Start < End.
- Non-negative timestamps.
- End <= video duration.
- Invalid range or parse errors show inline warning and do not enqueue.
- If resolution exceeds source size, warn and suggest nearest supported resolution.
- If output folder is not writable, show explicit permission error.
- If export fails for a clip, mark it as failed and continue with remaining clips.

### Edge cases
- Video has **no audio track** → export should still succeed (video-only).
- Variable frame-rate video → use AVAssetExportSession for reliable trimming.
- Duplicate clip ranges → allowed; file names should remain unique.
- Very short clips (< 0.5s) → still attempt export; warn if too short.
- User pastes multiple ranges → parse line-by-line, skipping invalid lines and reporting count.

## 3. UI/UX Wire Description (screens + controls)
### Main window (single screen)
- **Top bar**
  - “Select Video” button + selected filename label.
  - Optional drag-and-drop zone.
- **Clip list panel**
  - Input field with placeholder (`00:02:10 - 00:02:45`).
  - “Add” button.
  - Multi-line paste support (one range per line).
  - List of added clips with per-clip status + progress bar.
  - Trash/remove action per clip.
- **Output settings**
  - Output folder picker + path label.
  - Resolution picker (Same/1080/720/Custom). If Custom, show width/height fields.
  - Optional warning banner if chosen resolution is invalid for the source.
- **Export area**
  - “Export Clips” button.
  - Overall progress bar.
  - Summary result (success/failure count) + “Open output folder” button.

## 4. Architecture (modules/classes)
- **AppModel (ObservableObject)**
  - Holds app state: sourceURL, clips, output folder, resolution, progress, alerts.
  - Coordinates imports and exports.
- **VideoImporter**
  - NSOpenPanel wrapper for file and folder selection.
- **ClipParser**
  - Parses timestamp ranges, returns validated ClipRange.
- **ExportService**
  - Background queue; uses AVAssetExportSession per clip.
  - Reports progress callbacks.
- **VideoCompositionBuilder**
  - Builds AVMutableVideoComposition for resizing.
- **SettingsStore**
  - UserDefaults for last output folder and last resolution.

## 5. Data Model (clips + settings)
- **ClipRange**
  - start: CMTime
  - end: CMTime
- **ClipItem**
  - id: UUID
  - range: ClipRange
  - progress: Double?
  - status: pending/exporting/completed/failed
- **Settings**
  - lastOutputFolderURL: URL?
  - lastResolution: OutputResolution

## 6. Export Pipeline Design
1. Load source asset via AVAsset.
2. Validate all ranges against asset duration.
3. For each clip:
   - Configure AVAssetExportSession with timeRange.
   - Apply AVMutableVideoComposition when scaling is required.
   - Export to MP4 with H.264 + AAC.
4. Track progress via exportSession.progress.
5. On completion, update per-clip status; continue to next clip.

### Resolution handling
- Use `VideoCompositionBuilder` to scale while preserving aspect ratio (letterbox if necessary).
- If custom resolution invalid (<1 or > source size), warn and suggest:
  - Nearest supported (e.g., fall back to 1080p or source size).

### AVFoundation vs FFmpeg
- **AVFoundation** is preferred for macOS App Store compatibility and code-signing.
- **FFmpeg** would require bundling binary, managing licensing, and may be rejected in App Store; better for non-store distribution.

## 7. Step-by-Step Build Plan (milestones)
1. **Project scaffold**: SwiftUI app shell, basic layout.
2. **Import workflow**: NSOpenPanel for source video and output folder.
3. **Timestamp parsing**: ClipParser, validation, bulk paste.
4. **Clip list UI**: list with status + progress.
5. **Export pipeline**: AVAssetExportSession, progress reporting.
6. **Resolution controls**: picker + custom input + validation warnings.
7. **Error handling**: alert system for invalid ranges and export failures.
8. **Polish**: persist output folder, “Open output folder”, app icon.

## 8. Starter Code Skeleton (Swift/SwiftUI)
See `StarterCode/Sources/PickleClipper` for a minimal SwiftUI + AVFoundation skeleton:
- Video import & output folder picker (`VideoImporter.swift`).
- Timestamp list input + parsing (`ContentView.swift`, `Validation.swift`).
- Resolution picker (`ContentView.swift`, `Models.swift`).
- Export queue with background dispatch (`ExportService.swift`).

## 9. Testing Checklist
- Import MOV/MP4/M4V with and without audio.
- Enter valid `MM:SS` and `HH:MM:SS` ranges.
- Paste multiple ranges; verify invalid lines are rejected.
- Start/end equal → rejected.
- End beyond duration → rejected or flagged.
- Export 1 clip and 10+ clips; UI remains responsive.
- Resolution set to 1080p with smaller source → warning and fallback.
- Custom resolution invalid (0 or negative) → warning.
- Output folder not writable → explicit error.
- Duplicate ranges → unique filenames.
- Cancel export by closing app → safe cleanup.

## 10. Optional Extra Credit (future milestone)
- **Auto-clip suggestions**: detect pauses via silence/scoreboard changes; propose ranges.
- **Open output folder** button after export.
- Output format picker (MP4/MOV) and frame-rate selection.
