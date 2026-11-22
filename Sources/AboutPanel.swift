import AppKit

enum AboutPanel {
    static let authorURL = URL(string: "https://nilambar.net/")!
    static let repositoryURL = URL(string: "https://github.com/ernilambar/stayman")!
    static let licenseURL = URL(string: "https://github.com/ernilambar/stayman/blob/main/LICENSE")!

    static func show() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        let credits = NSMutableAttributedString()

        func append(_ text: String, link: URL? = nil) {
            var attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .paragraphStyle: paragraph,
            ]
            if let link {
                attributes[.link] = link
            }
            credits.append(NSAttributedString(string: text, attributes: attributes))
        }

        append(authorURL.absoluteString, link: authorURL)

        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .applicationName: AppInfo.name,
            .credits: credits,
        ])
    }
}
