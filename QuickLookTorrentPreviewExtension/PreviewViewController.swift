import AppKit
import QuickLookUI
import SwiftUI

final class PreviewViewController: NSViewController, QLPreviewingController {
    private var hostingController: NSHostingController<TorrentPreviewView>?
    private let parser = TorrentParser()

    override func loadView() {
        view = NSView()
        show(state: .loading)
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        do {
            let data = try Data(contentsOf: url)
            let metadata = try parser.parse(data: data)
            show(state: .success(metadata))
            handler(nil)
        } catch {
            show(state: .failure(error.localizedDescription))
            handler(nil)
        }
    }

    private func show(state: TorrentPreviewState) {
        let host = NSHostingController(rootView: TorrentPreviewView(state: state))
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false

        if let existing = hostingController {
            existing.view.removeFromSuperview()
            existing.removeFromParent()
        }

        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        hostingController = host
        updatePreferredSize(for: state)
    }

    private func updatePreferredSize(for state: TorrentPreviewState) {
        guard case .success(let metadata) = state else {
            preferredContentSize = NSSize(width: 460, height: 200)
            return
        }

        let padding: CGFloat = 20 * 2
        let title: CGFloat = 30
        let metadataGrid: CGFloat = 70
        let sectionHeader: CGFloat = 24
        let trackerRow: CGFloat = 24

        var height = padding + title + metadataGrid
        var width: CGFloat = 480

        if metadata.files.count > 1 {
            height += sectionHeader + CGFloat(metadata.files.count) * trackerRow + 16

            // Calculate width from longest file name
            let font = NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
            let attrs: [NSAttributedString.Key: Any] = [.font: font]
            var maxNameWidth: CGFloat = 0
            for file in metadata.files {
                let w = (file.name as NSString).size(withAttributes: attrs).width
                if w > maxNameWidth { maxNameWidth = w }
            }
            // padding(20*2) + section header space + name column + size column(~90) + pieces column(~50) + grid spacing(~36)
            width = max(480, maxNameWidth + 20 * 2 + 90 + 50 + 36)
        }

        if !metadata.trackers.isEmpty {
            height += sectionHeader
            let visibleTrackers = min(metadata.trackers.count, 10)
            height += CGFloat(visibleTrackers) * trackerRow
        }

        height = max(height, 180)
        preferredContentSize = NSSize(width: width, height: height)
    }
}
