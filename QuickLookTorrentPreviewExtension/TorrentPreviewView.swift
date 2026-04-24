import SwiftUI

enum TorrentPreviewState {
    case loading
    case success(TorrentMetadata)
    case failure(String)
}

struct TorrentPreviewView: View {
    let state: TorrentPreviewState

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView(L10n.tr("ui.loading"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failure(let message):
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 30))
                    Text(L10n.tr("ui.failureTitle"))
                        .font(.headline)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .success(let metadata):
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(metadata.name)
                            .font(.title2)
                            .bold()

                        metadataGrid(metadata: metadata)
                        if metadata.files.count > 1 {
                            multiFileTable(metadata.files)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.tr("ui.trackers"))
                                .font(.headline)
                            if metadata.trackers.isEmpty {
                                Text(L10n.tr("ui.noTrackers"))
                                    .foregroundStyle(.secondary)
                            } else {
                                if metadata.trackers.count > 10 {
                                    ScrollView {
                                        trackerList(metadata.trackers)
                                    }
                                    .frame(height: trackerRowHeight * 10)
                                } else {
                                    trackerList(metadata.trackers)
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
    }

    @ViewBuilder
    private func metadataGrid(metadata: TorrentMetadata) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
            GridRow {
                Text(L10n.tr("ui.totalSize"))
                    .foregroundStyle(.secondary)
                Text(formattedSize(metadata.totalSize))
            }
            GridRow {
                Text(L10n.tr("ui.fileCount"))
                    .foregroundStyle(.secondary)
                Text("\(metadata.fileCount)")
            }
            GridRow {
                Text(L10n.tr("ui.infoHash"))
                    .foregroundStyle(.secondary)
                Text(metadata.infoHash)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
    }

    private func formattedSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.includesUnit = true
        formatter.isAdaptive = true

        let readable = formatter.string(fromByteCount: bytes)
        return String(format: L10n.tr("ui.sizeWithBytes"), readable, "\(bytes)")
    }

    private var trackerRowHeight: CGFloat { 20 }

    @ViewBuilder
    private func trackerList(_ trackers: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(trackers, id: \.self) { tracker in
                Text(tracker)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, minHeight: trackerRowHeight, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func multiFileTable(_ files: [TorrentFileEntry]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.tr("ui.files"))
                .font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    Text(L10n.tr("ui.fileName")).bold()
                    Text(L10n.tr("ui.fileSize")).bold()
                    Text(L10n.tr("ui.pieces")).bold()
                }
                Divider()
                ForEach(Array(files.enumerated()), id: \.offset) { _, file in
                    GridRow {
                        Text(file.name)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(formattedSize(file.size))
                        Text("\(file.pieces)")
                    }
                }
            }
            .font(.system(.footnote, design: .monospaced))
        }
    }
}
