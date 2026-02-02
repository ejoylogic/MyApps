import AVFoundation
import Foundation

enum ClipParser {
    static func parse(line: String) -> [ClipRange] {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let parts = trimmed.split(separator: "-")
        guard parts.count == 2 else { return [] }
        let startText = parts[0].trimmingCharacters(in: .whitespaces)
        let endText = parts[1].trimmingCharacters(in: .whitespaces)
        guard let start = parseTimecode(startText), let end = parseTimecode(endText) else {
            return []
        }
        guard end > start else { return [] }
        return [ClipRange(start: start, end: end)]
    }

    static func parseTimecode(_ text: String) -> CMTime? {
        let parts = text.split(separator: ":").map(String.init)
        let numbers = parts.compactMap { Double($0) }
        guard numbers.count == parts.count else { return nil }

        let seconds: Double
        switch numbers.count {
        case 2:
            seconds = numbers[0] * 60 + numbers[1]
        case 3:
            seconds = numbers[0] * 3600 + numbers[1] * 60 + numbers[2]
        default:
            return nil
        }

        guard seconds >= 0 else { return nil }
        return CMTime(seconds: seconds, preferredTimescale: 600)
    }
}
