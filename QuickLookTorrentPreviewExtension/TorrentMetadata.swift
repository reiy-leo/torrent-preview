import Foundation

struct TorrentFileEntry: Equatable {
    let name: String
    let size: Int64
    let pieces: Int
}

struct TorrentMetadata: Equatable {
    let name: String
    let totalSize: Int64
    let fileCount: Int
    let infoHash: String
    let trackers: [String]
    let files: [TorrentFileEntry]
}

enum TorrentParseError: Error, LocalizedError {
    case invalidRoot
    case missingInfoDictionary
    case missingName
    case invalidLength

    var errorDescription: String? {
        switch self {
        case .invalidRoot:
            return L10n.tr("error.invalidRoot")
        case .missingInfoDictionary:
            return L10n.tr("error.missingInfoDictionary")
        case .missingName:
            return L10n.tr("error.missingName")
        case .invalidLength:
            return L10n.tr("error.invalidLength")
        }
    }
}
