import AVFoundation
import Foundation

final class ExportService {
    private let queue = DispatchQueue(label: "pickleclipper.export", qos: .userInitiated)

    func export(
        sourceURL: URL,
        outputFolder: URL,
        clips: [ClipItem],
        resolution: OutputResolution,
        progress: @escaping (ExportUpdate) -> Void
    ) {
        queue.async {
            let asset = AVAsset(url: sourceURL)
            let duration = asset.duration

            let normalizedClips = clips.filter { clip in
                clip.range.start >= .zero && clip.range.end <= duration
            }

            guard !normalizedClips.isEmpty else {
                progress(.finished(.failure(ExportError.noValidClips)))
                return
            }

            var completed = 0

            for (index, clip) in normalizedClips.enumerated() {
                progress(.clipProgress(id: clip.id, progress: 0, status: .exporting))

                let result = self.exportClip(
                    asset: asset,
                    clip: clip,
                    clipIndex: index,
                    sourceURL: sourceURL,
                    outputFolder: outputFolder,
                    resolution: resolution,
                    progress: { clipProgress in
                        progress(.clipProgress(id: clip.id, progress: clipProgress, status: .exporting))
                    }
                )

                switch result {
                case .success:
                    progress(.clipProgress(id: clip.id, progress: 1, status: .completed))
                case .failure:
                    progress(.clipProgress(id: clip.id, progress: 1, status: .failed))
                }

                completed += 1
                progress(.overallProgress(Double(completed) / Double(normalizedClips.count)))
            }

            progress(.finished(.success(())))
        }
    }

    private func exportClip(
        asset: AVAsset,
        clip: ClipItem,
        clipIndex: Int,
        sourceURL: URL,
        outputFolder: URL,
        resolution: OutputResolution,
        progress: @escaping (Double) -> Void
    ) -> Result<Void, Error> {
        let timeRange = CMTimeRange(start: clip.range.start, end: clip.range.end)
        let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality)

        guard let session = exportSession else {
            return .failure(ExportError.sessionCreation)
        }

        let outputURL = outputFolder
            .appendingPathComponent(exportFileName(sourceURL: sourceURL, clip: clip, clipIndex: clipIndex))
            .appendingPathExtension("mp4")

        session.outputURL = outputURL
        session.outputFileType = .mp4
        session.timeRange = timeRange

        if let composition = VideoCompositionBuilder.build(asset: asset, resolution: resolution) {
            session.videoComposition = composition
        }

        let group = DispatchGroup()
        group.enter()
        session.exportAsynchronously {
            group.leave()
        }

        while session.status == .exporting {
            progress(session.progress)
            Thread.sleep(forTimeInterval: 0.1)
        }

        group.wait()

        switch session.status {
        case .completed:
            return .success(())
        case .failed:
            return .failure(session.error ?? ExportError.exportFailed)
        case .cancelled:
            return .failure(ExportError.cancelled)
        default:
            return .failure(ExportError.exportFailed)
        }
    }

    private func exportFileName(sourceURL: URL, clip: ClipItem, clipIndex: Int) -> String {
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let indexString = String(format: "%02d", clipIndex + 1)
        return "\(baseName)_clip\(indexString)_\(clip.range.start.displayString)_to_\(clip.range.end.displayString)"
            .replacingOccurrences(of: ":", with: "-")
    }
}

enum ExportError: LocalizedError {
    case noValidClips
    case sessionCreation
    case exportFailed
    case cancelled

    var errorDescription: String? {
        switch self {
        case .noValidClips:
            return "No valid clips were within the video duration."
        case .sessionCreation:
            return "Could not create an export session."
        case .exportFailed:
            return "The export failed."
        case .cancelled:
            return "The export was cancelled."
        }
    }
}

enum VideoCompositionBuilder {
    static func build(asset: AVAsset, resolution: OutputResolution) -> AVMutableVideoComposition? {
        guard let videoTrack = asset.tracks(withMediaType: .video).first else { return nil }
        let naturalSize = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
        let sourceSize = CGSize(width: abs(naturalSize.width), height: abs(naturalSize.height))

        let targetSize = validatedResolution(sourceSize: sourceSize, resolution: resolution)
        guard targetSize != sourceSize else { return nil }

        let composition = AVMutableVideoComposition()
        composition.renderSize = targetSize
        composition.frameDuration = CMTime(value: 1, timescale: 30)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: asset.duration)

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        let scale = min(targetSize.width / sourceSize.width, targetSize.height / sourceSize.height)
        let transform = videoTrack.preferredTransform
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: 0, y: 0)
        layerInstruction.setTransform(transform, at: .zero)

        instruction.layerInstructions = [layerInstruction]
        composition.instructions = [instruction]
        return composition
    }

    private static func validatedResolution(sourceSize: CGSize, resolution: OutputResolution) -> CGSize {
        switch resolution {
        case .source:
            return sourceSize
        case .hd1080:
            return CGSize(width: 1920, height: 1080)
        case .hd720:
            return CGSize(width: 1280, height: 720)
        case .custom(let width, let height):
            let safeWidth = max(1, width)
            let safeHeight = max(1, height)
            return CGSize(width: safeWidth, height: safeHeight)
        }
    }
}

extension CMTime {
    var displayString: String {
        let totalSeconds = Int(CMTimeGetSeconds(self))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
