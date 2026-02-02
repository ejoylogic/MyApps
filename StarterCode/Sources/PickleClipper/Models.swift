import AppKit
import AVFoundation
import Combine
import Foundation
import SwiftUI

final class AppModel: ObservableObject {
    @Published var sourceURL: URL?
    @Published var outputFolderURL: URL?
    @Published var clips: [ClipItem] = []
    @Published var selectedResolution: OutputResolution = .source
    @Published var isExporting = false
    @Published var overallProgress: Double = 0
    @Published var statusMessage: String?
    @Published var activeAlert: AlertInfo?

    private let importer = VideoImporter()
    private let exportService = ExportService()
    private var cancellables = Set<AnyCancellable>()

    var canExport: Bool {
        sourceURL != nil && outputFolderURL != nil && !clips.isEmpty && !isExporting
    }

    var statusColor: Color {
        statusMessage == nil ? .primary : .secondary
    }

    init() {
        outputFolderURL = UserDefaults.standard.url(forKey: UserDefaultsKeys.outputFolder)
    }

    func pickSourceVideo() {
        importer.pickVideo { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let url):
                    self?.sourceURL = url
                    self?.statusMessage = "Loaded video: \(url.lastPathComponent)"
                case .failure(let error):
                    self?.activeAlert = AlertInfo(title: "Video Import Failed", message: error.localizedDescription)
                }
            }
        }
    }

    func pickOutputFolder() {
        importer.pickFolder { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let url):
                    self?.outputFolderURL = url
                    UserDefaults.standard.set(url, forKey: UserDefaultsKeys.outputFolder)
                case .failure(let error):
                    self?.activeAlert = AlertInfo(title: "Folder Selection Failed", message: error.localizedDescription)
                }
            }
        }
    }

    func addClipRange(from text: String) {
        let entries = text.split(whereSeparator: \.$isNewline)
        let ranges = entries.flatMap { ClipParser.parse(line: String($0)) }
        let newClips = ranges.map { ClipItem(range: $0) }
        clips.append(contentsOf: newClips)
        if newClips.isEmpty {
            activeAlert = AlertInfo(title: "Invalid Range", message: "Use HH:MM:SS - HH:MM:SS or MM:SS - MM:SS")
        }
    }

    func deleteClips(at offsets: IndexSet) {
        clips.remove(atOffsets: offsets)
    }

    func startExport() {
        guard let sourceURL, let outputFolderURL else { return }
        isExporting = true
        overallProgress = 0
        statusMessage = "Export started…"

        exportService.export(
            sourceURL: sourceURL,
            outputFolder: outputFolderURL,
            clips: clips,
            resolution: selectedResolution
        ) { [weak self] update in
            DispatchQueue.main.async {
                self?.apply(update: update)
            }
        }
    }

    private func apply(update: ExportUpdate) {
        switch update {
        case .clipProgress(let id, let progress, let status):
            if let index = clips.firstIndex(where: { $0.id == id }) {
                clips[index].progress = progress
                clips[index].status = status
            }
        case .overallProgress(let progress):
            overallProgress = progress
        case .finished(let result):
            isExporting = false
            switch result {
            case .success:
                statusMessage = "All clips exported."
            case .failure(let error):
                activeAlert = AlertInfo(title: "Export Failed", message: error.localizedDescription)
            }
        }
    }
}

struct ClipItem: Identifiable {
    let id = UUID()
    let range: ClipRange
    var progress: Double?
    var status: ClipStatus = .pending

    var displayRange: String {
        "\(range.start.displayString) - \(range.end.displayString)"
    }
}

enum ClipStatus {
    case pending
    case exporting
    case completed
    case failed

    var displayText: String {
        switch self {
        case .pending: return "Pending"
        case .exporting: return "Exporting"
        case .completed: return "Done"
        case .failed: return "Failed"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .secondary
        case .exporting: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
}

struct ClipRange {
    let start: CMTime
    let end: CMTime

    var duration: CMTime {
        CMTimeSubtract(end, start)
    }
}

enum OutputResolution: Hashable, Identifiable {
    case source
    case hd1080
    case hd720
    case custom(width: Int, height: Int)

    var id: String {
        switch self {
        case .source: return "source"
        case .hd1080: return "1080"
        case .hd720: return "720"
        case .custom(let width, let height): return "custom-\(width)x\(height)"
        }
    }

    var title: String {
        switch self {
        case .source: return "Same as Source"
        case .hd1080: return "1080p"
        case .hd720: return "720p"
        case .custom: return "Custom"
        }
    }

    static let options: [OutputResolution] = [
        .source,
        .hd1080,
        .hd720,
        .custom(width: 1920, height: 1080)
    ]
}

struct AlertInfo: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

enum ExportUpdate {
    case clipProgress(id: UUID, progress: Double, status: ClipStatus)
    case overallProgress(Double)
    case finished(Result<Void, Error>)
}

enum UserDefaultsKeys {
    static let outputFolder = "pickleclipper.outputFolder"
}
