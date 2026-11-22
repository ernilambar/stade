import Testing
@testable import AppCore

struct LogFileMergeTests {
    @Test func appendsLinesInsideTheTailWindow() {
        #expect(LogFile.merge(existing: "a\nb", tail: "a\nb\nc") == "a\nb\nc")
    }

    @Test func appendsAfterTheWindowSlides() {
        #expect(LogFile.merge(existing: "a\nb\nc", tail: "b\nc\nd") == "a\nb\nc\nd")
    }

    @Test func leavesUnchangedTextAlone() {
        #expect(LogFile.merge(existing: "a\nb", tail: "a\nb") == "a\nb")
    }

    @Test func emptyTailClearsTheView() {
        #expect(LogFile.merge(existing: "a\nb", tail: "") == "")
    }

    @Test func replacesWhenThereIsNoOverlap() {
        #expect(LogFile.merge(existing: "a\nb", tail: "x\ny") == "x\ny")
    }

    @Test func doesNotAddBlankLinesForTrailingNewlines() {
        #expect(LogFile.merge(existing: "a\n", tail: "a\nb\n") == "a\nb\n")
        #expect(LogFile.merge(existing: "a\nb\n", tail: "b\nc\n") == "a\nb\nc")
    }

    @Test func trimsOldLinesAfterAppending() {
        let merged = LogFile.merge(existing: "a\nb\nc", tail: "c\nd", maximumLines: 3)
        #expect(merged == "b\nc\nd")
    }
}
