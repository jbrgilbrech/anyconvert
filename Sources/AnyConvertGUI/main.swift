import AnyConvertCore
import AppKit
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let engine = ConversionEngine()

    private var window: NSWindow!
    private let sourceField = NSTextField(labelWithString: "No file selected")
    private let categoryField = NSTextField(labelWithString: "Category: -")
    private let statusField = NSTextField(labelWithString: "Pick a file to begin.")
    private let formatPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let convertButton = NSButton(title: "Convert", target: nil, action: nil)

    private var sourceURL: URL?
    private var availableFormats: [OutputFormat] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        buildWindow()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func buildMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit AnyConvert", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        menu.addItem(appItem)
        NSApp.mainMenu = menu
    }

    private func buildWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 310),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "AnyConvert"

        let chooseButton = NSButton(title: "Choose File", target: self, action: #selector(selectFile))
        chooseButton.bezelStyle = .rounded

        convertButton.target = self
        convertButton.action = #selector(convertFile)
        convertButton.isEnabled = false

        let labelStyle: (NSTextField) -> Void = { label in
            label.lineBreakMode = .byTruncatingMiddle
            label.maximumNumberOfLines = 2
        }

        [sourceField, categoryField, statusField].forEach(labelStyle)
        statusField.textColor = .secondaryLabelColor

        let formatLabel = NSTextField(labelWithString: "Output Format")

        let stack = NSStackView(views: [
            chooseButton,
            sourceField,
            categoryField,
            formatLabel,
            formatPopUp,
            convertButton,
            statusField,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let contentView = NSView()
        contentView.addSubview(stack)
        window.contentView = contentView

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor),
            formatPopUp.widthAnchor.constraint(equalToConstant: 220),
            chooseButton.widthAnchor.constraint(equalToConstant: 140),
            convertButton.widthAnchor.constraint(equalToConstant: 140),
        ])

        window.makeKeyAndOrderFront(nil)
    }

    @objc
    private func selectFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        sourceURL = url
        sourceField.stringValue = "Source: \(url.path)"

        do {
            availableFormats = try engine.supportedFormats(for: url)
            formatPopUp.removeAllItems()
            formatPopUp.addItems(withTitles: availableFormats.map { "\($0.displayName) (.\($0.fileExtension))" })
            categoryField.stringValue = "Category: \(availableFormats.first?.category.rawValue.capitalized ?? "-")"
            statusField.stringValue = "Choose an output format and convert."
            convertButton.isEnabled = !availableFormats.isEmpty
        } catch {
            availableFormats = []
            formatPopUp.removeAllItems()
            categoryField.stringValue = "Category: Unsupported"
            statusField.stringValue = error.localizedDescription
            convertButton.isEnabled = false
        }
    }

    @objc
    private func convertFile() {
        guard let sourceURL else { return }
        let selectedIndex = formatPopUp.indexOfSelectedItem
        guard availableFormats.indices.contains(selectedIndex) else { return }
        let selectedFormat = availableFormats[selectedIndex]

        let panel = NSSavePanel()
        panel.nameFieldStringValue = engine.defaultOutputURL(for: sourceURL, targetExtension: selectedFormat.fileExtension).lastPathComponent
        panel.allowedContentTypes = []

        guard panel.runModal() == .OK, let outputURL = panel.url else { return }

        do {
            let result = try engine.convert(inputURL: sourceURL, to: selectedFormat.fileExtension, outputURL: outputURL)
            statusField.stringValue = "Saved to \(result.outputURL.path)"
        } catch {
            statusField.stringValue = error.localizedDescription
        }
    }
}

@MainActor
@main
struct AnyConvertGUIApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.setActivationPolicy(.regular)
        app.delegate = delegate
        app.run()
    }
}
