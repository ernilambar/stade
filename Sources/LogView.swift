import AppKit
import SwiftUI

struct LogView: View {
    let script: Script
    let logURL: URL

    @Environment(\.dismiss) private var dismiss

    @StateBox private var text = ""
    @StateBox private var logExists = false
    @StateBox private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
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
            .padding()

            Divider()

            if logExists {
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(text.isEmpty ? " " : text)
                            .font(.system(size: 12, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)

                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .onAppear {
                        scrollToBottom(proxy)
                    }
                    .onChange(of: text) { _ in
                        scrollToBottom(proxy)
                    }
                }
            } else {
                Text("No log output yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()

            HStack {
                Button("Open in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([logURL])
                }
                .disabled(!logExists)

                Button("Clear log") {
                    Task {
                        await clearLog()
                    }
                }
                .disabled(!logExists)

                Spacer()

                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
        }
        .frame(width: 760, height: 480)
        .task {
            while !Task.isCancelled {
                await reload()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
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

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
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
            text = tail ?? ""
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func clearLog() async {
        let url = logURL
        let result = await Task.detached(priority: .utility) {
            Result { try LogFile.clear(at: url) }
        }.value

        if case .failure(let error) = result {
            errorMessage = error.localizedDescription
        }
        await reload()
    }
}
