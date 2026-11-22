import AppKit

enum AboutPanel {
    static let author = "Nilambar Sharma"
    static let authorURL = "https://nilambar.net/"
    static let repositoryURL = "https://github.com/ernilambar/stayman"

    static func show() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        let credits = NSMutableAttributedString()

        func append(_ text: String, link: String? = nil) {
            var attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .paragraphStyle: paragraph,
            ]
            if let link, let url = URL(string: link) {
                attributes[.link] = url
            }
            credits.append(NSAttributedString(string: text, attributes: attributes))
        }

        append(author + "\n")
        append(authorURL, link: authorURL)
        append("\n")
        append(repositoryURL, link: repositoryURL)

        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .applicationName: AppInfo.name,
            .credits: credits,
        ])
    }
}
