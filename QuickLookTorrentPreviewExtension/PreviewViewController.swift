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
    }
}
