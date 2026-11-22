import Foundation

/// Tail/compaction helpers for launchd log files, which are never rotated.
enum LogFile {
    static let maximumBytes: Int64 = 5 * 1024 * 1024
    static let retainedBytes: Int64 = 1 * 1024 * 1024
    static let defaultLineCount = 500
    /// Caps a tail read when lines are long or newlines are missing.
    static let maximumTailBytes = 256 * 1024

    /// Cuts a log over 5 MB down to its last 1 MB, in place.
    static func truncateIfNeeded(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = (attributes[.size] as? NSNumber)?.int64Value, size > maximumBytes else {
            return
        }

        let handle = try FileHandle(forUpdating: url)
        defer { try? handle.close() }

        let start = max(0, size - retainedBytes)
        try handle.seek(toOffset: UInt64(start))
        let kept = try handle.readToEnd() ?? Data()

        try handle.truncate(atOffset: 0)
        try handle.seek(toOffset: 0)
        try handle.write(contentsOf: kept)
    }

    /// Last `lineCount` lines. Compacts first, then reads backwards in chunks.
    static func tail(at url: URL, lineCount: Int = LogFile.defaultLineCount) throws -> String {
        try truncateIfNeeded(at: url)

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var offset = try handle.seekToEnd()
        var data = Data()
        var newlines = 0
        let chunkSize: UInt64 = 64 * 1024

        while offset > 0 {
            let readSize = min(chunkSize, offset)
            offset -= readSize
            try handle.seek(toOffset: offset)

            guard let chunk = try handle.read(upToCount: Int(readSize)), !chunk.isEmpty else {
                break
            }

            newlines += chunk.reduce(0) { $0 + ($1 == 0x0A ? 1 : 0) }
            data.insert(contentsOf: chunk, at: 0)

            if newlines > lineCount || data.count >= maximumTailBytes {
                break
            }
        }

        var lines = String(decoding: data, as: UTF8.self)
            .split(separator: "\n", omittingEmptySubsequences: false)

        if lines.last?.isEmpty == true {
            lines.removeLast()
        }

        if lines.count > lineCount {
            lines = Array(lines.suffix(lineCount))
        }

        return lines.joined(separator: "\n")
    }

    /// Truncates in place; launchd keeps appending through its open descriptor.
    static func clear(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.truncate(atOffset: 0)
    }
}
