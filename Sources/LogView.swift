import AppKit
import Combine
import SwiftUI

struct LogView: View {
    let script: Script
    let logURL: URL

    @Environment(\.dismiss) private var dismiss

    @StateBox private var text = ""
    @StateBox private var logExists = false
    @StateBox private var errorMessage: String?

    private let refreshTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

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
                    clearLog()
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
        .onAppear {
            reload()
        }
        .onReceive(refreshTimer) { _ in
            reload()
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

    private func reload() {
        logExists = FileManager.default.fileExists(atPath: logURL.path)

        guard logExists else {
            text = ""
            return
        }

        do {
            text = try LogFile.tail(at: logURL)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func clearLog() {
        do {
            try LogFile.clear(at: logURL)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
