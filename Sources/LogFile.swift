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

    /// Caps how much output the viewer keeps in memory during a session.
    static let maximumDisplayedLines = 10_000

    /// Merges a fresh tail read into the text already on screen.
    ///
    /// Consecutive tail reads overlap while the file only grows. Keeping the
    /// overlap lets the view append instead of replacing all text, which
    /// preserves scroll position and selection. An empty tail means the log
    /// was cleared.
    static func merge(
        existing: String,
        tail: String,
        maximumLines: Int = LogFile.maximumDisplayedLines
    ) -> String {
        if existing.isEmpty || tail.isEmpty {
            return tail
        }

        if tail.hasPrefix(existing) {
            return tail
        }

        let oldLines = lines(in: existing)
        let newLines = lines(in: tail)
        let maximumOverlap = min(oldLines.count, newLines.count)

        for overlap in stride(from: maximumOverlap, through: 1, by: -1)
        where oldLines.suffix(overlap).elementsEqual(newLines.prefix(overlap)) {
            let appended = Array(newLines.dropFirst(overlap))
            guard !appended.isEmpty else {
                return existing
            }
            return trim(oldLines + appended, maximumLines: maximumLines)
        }

        return tail
    }

    private static func lines(in text: String) -> [Substring] {
        // A trailing newline terminates the last line rather than starting an
        // empty one; dropping it keeps line joins from adding blank lines.
        let body = text.hasSuffix("\n") ? text.dropLast() : text[...]
        return body.split(separator: "\n", omittingEmptySubsequences: false)
    }

    private static func trim(_ lines: [Substring], maximumLines: Int) -> String {
        guard lines.count > maximumLines else {
            return lines.joined(separator: "\n")
        }
        return lines.suffix(maximumLines).joined(separator: "\n")
    }
}
