import AppKit
import SwiftUI

struct LogView: View {
    let script: Script
    let logURL: URL

    private static let maximumMatches = 1000
    private static let pollInterval: UInt64 = 2_000_000_000

    @Environment(\.dismiss) private var dismiss

    @StateBox private var text = ""
    @StateBox private var logExists = false
    @StateBox private var errorMessage: String?
    @StateBox private var isPaused = false
    @StateBox private var follow = true
    @StateBox private var searchQuery = ""
    @StateBox private var selectedMatch = 0

    var body: some View {
        let matches = searchMatches
        let selectedIndex = matches.isEmpty ? 0 : min(max(selectedMatch, 0), matches.count - 1)

        VStack(spacing: 0) {
            header(matches: matches, selectedIndex: selectedIndex)
            Divider()

            if logExists {
                LogTextView(
                    text: text,
                    follow: follow,
                    query: searchQuery,
                    matches: matches,
                    selectedMatch: selectedIndex
                )
            } else {
                Text("No log output yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()
            footer
        }
        .frame(width: 760, height: 480)
        .task(id: isPaused) {
            guard !isPaused else {
                return
            }

            while !Task.isCancelled {
                await reload()
                do {
                    try await Task.sleep(nanoseconds: Self.pollInterval)
                } catch {
                    break
                }
            }
        }
        .alert("Error", isPresented: errorBinding) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func header(matches: [NSRange], selectedIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text("Log — \(script.name)")
                    .font(.headline)
                Spacer()
                Text(logURL.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search log", text: searchBinding)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
                    .onSubmit {
                        selectNextMatch(matches)
                    }

                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Clear search")

                    Text(matchLabel(matches: matches, selectedIndex: selectedIndex))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 70, alignment: .leading)

                    Button {
                        selectPreviousMatch(matches)
                    } label: {
                        Image(systemName: "chevron.up")
                    }
                    .buttonStyle(.borderless)
                    .disabled(matches.isEmpty)
                    .help("Previous match")

                    Button {
                        selectNextMatch(matches)
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .buttonStyle(.borderless)
                    .disabled(matches.isEmpty)
                    .help("Next match")
                }

                Spacer()

                Text(isPaused ? "Paused" : "Live tail")
                    .font(.caption)
                    .foregroundStyle(isPaused ? Color.orange : Color.secondary)
            }
        }
        .padding()
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button(isPaused ? "Resume" : "Pause") {
                isPaused.toggle()
            }
            .help(isPaused ? "Resume live updates" : "Stop live updates")

            Toggle("Follow", isOn: $follow)
                .toggleStyle(.switch)
                .controlSize(.small)
                .help("Scroll to the bottom when new output arrives while already at the bottom")

            Spacer()

            Button("Open in Editor") {
                openInEditor()
            }
            .disabled(!logExists)

            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([logURL])
            }
            .disabled(!logExists)

            Button("Clear log") {
                Task {
                    await clearLog()
                }
            }
            .disabled(!logExists)

            Button("Close") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding()
    }

    private var searchBinding: Binding<String> {
        Binding(
            get: { searchQuery },
            set: { value in
                searchQuery = value
                selectedMatch = 0
            }
        )
    }

    private var searchMatches: [NSRange] {
        let query = searchQuery
        guard !query.isEmpty else {
            return []
        }

        let source = text as NSString
        var results: [NSRange] = []
        var searchRange = NSRange(location: 0, length: source.length)

        while searchRange.length > 0, results.count < Self.maximumMatches {
            let found = source.range(of: query, options: .caseInsensitive, range: searchRange)
            guard found.location != NSNotFound else {
                break
            }

            results.append(found)
            let nextLocation = NSMaxRange(found)
            guard nextLocation < source.length else {
                break
            }
            searchRange = NSRange(location: nextLocation, length: source.length - nextLocation)
        }

        return results
    }

    private func matchLabel(matches: [NSRange], selectedIndex: Int) -> String {
        guard !matches.isEmpty else {
            return "No matches"
        }
        let more = matches.count >= Self.maximumMatches ? "+" : ""
        return "\(selectedIndex + 1) of \(matches.count)\(more)"
    }

    private func selectNextMatch(_ matches: [NSRange]) {
        guard !matches.isEmpty else {
            return
        }
        let current = min(max(selectedMatch, 0), matches.count - 1)
        selectedMatch = (current + 1) % matches.count
    }

    private func selectPreviousMatch(_ matches: [NSRange]) {
        guard !matches.isEmpty else {
            return
        }
        let current = min(max(selectedMatch, 0), matches.count - 1)
        selectedMatch = (current - 1 + matches.count) % matches.count
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    errorMessage = nil
                }
            }
        )
    }

    /// Reads off the main actor; `nil` means the log does not exist yet.
    private func reload() async {
        let url = logURL
        let result = await Task.detached(priority: .utility) { () -> Result<String?, Error> in
            guard FileManager.default.fileExists(atPath: url.path) else {
                return .success(nil)
            }
            return Result { try LogFile.tail(at: url) }
        }.value

        switch result {
        case .success(let tail):
            logExists = tail != nil
            text = LogFile.merge(existing: text, tail: tail ?? "")
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func clearLog() async {
        let url = logURL
        let result = await Task.detached(priority: .utility) {
            Result { try LogFile.clear(at: url) }
        }.value

        switch result {
        case .success:
            text = ""
            selectedMatch = 0
        case .failure(let error):
            errorMessage = error.localizedDescription
        }

        await reload()
    }

    private func openInEditor() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-t", logURL.path]

        do {
            try process.run()
        } catch {
            errorMessage = "Could not open the log: \(error.localizedDescription)"
        }
    }
}
