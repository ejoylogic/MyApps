import AppKit
import Foundation
import UniformTypeIdentifiers

final class VideoImporter {
    func pickVideo(completion: @escaping (Result<URL, Error>) -> Void) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .mpeg4Movie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                completion(.failure(ImporterError.cancelled))
                return
            }
            completion(.success(url))
        }
    }

    func pickFolder(completion: @escaping (Result<URL, Error>) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                completion(.failure(ImporterError.cancelled))
                return
            }
            completion(.success(url))
        }
    }
}

enum ImporterError: LocalizedError {
    case cancelled

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "The selection was cancelled."
        }
    }
}
