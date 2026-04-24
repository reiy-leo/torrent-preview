import CryptoKit
import Foundation

final class TorrentParser {
    func parse(data: Data) throws -> TorrentMetadata {
        let root = try BencodeDecoder(data: data).decode()
        guard case .dictionary(let rootPairs) = root.value else {
            throw TorrentParseError.invalidRoot
        }

        guard let infoNode = value(forKey: "info", in: rootPairs),
              case .dictionary(let infoPairs) = infoNode.value else {
            throw TorrentParseError.missingInfoDictionary
        }

        guard let name = readString(forKey: "name.utf-8", in: infoPairs) ??
                readString(forKey: "name", in: infoPairs) else {
            throw TorrentParseError.missingName
        }

        let pieceLength = readInt(forKey: "piece length", in: infoPairs)
        let files = try parseFiles(infoPairs: infoPairs, rootName: name, pieceLength: pieceLength)
        let totalSize = files.reduce(0) { $0 + $1.size }
        let fileCount = files.count
        let infoHash = sha1Hex(of: data.subdata(in: infoNode.byteRange))
        let trackers = parseTrackers(from: rootPairs)

        return TorrentMetadata(
            name: name,
            totalSize: totalSize,
            fileCount: fileCount,
            infoHash: infoHash,
            trackers: trackers,
            files: files
        )
    }

    private func parseFiles(
        infoPairs: [(key: Data, value: BencodeNode)],
        rootName: String,
        pieceLength: Int64?
    ) throws -> [TorrentFileEntry] {
        if let filesNode = value(forKey: "files", in: infoPairs),
           case .list(let fileNodes) = filesNode.value {
            var entries: [TorrentFileEntry] = []
            var byteOffset: Int64 = 0
            for fileNode in fileNodes {
                guard case .dictionary(let filePairs) = fileNode.value else { continue }
                guard let length = readInt(forKey: "length", in: filePairs), length >= 0 else {
                    throw TorrentParseError.invalidLength
                }

                let fileName = parsePath(in: filePairs) ?? "Unnamed File"
                let pieces = piecesCount(offset: byteOffset, length: length, pieceLength: pieceLength)
                entries.append(TorrentFileEntry(name: fileName, size: length, pieces: pieces))
                byteOffset += length
            }
            return entries
        }

        guard let length = readInt(forKey: "length", in: infoPairs), length >= 0 else {
            throw TorrentParseError.invalidLength
        }
        let pieces = piecesCount(offset: 0, length: length, pieceLength: pieceLength)
        return [TorrentFileEntry(name: rootName, size: length, pieces: pieces)]
    }

    private func parsePath(in pairs: [(key: Data, value: BencodeNode)]) -> String? {
        let key = value(forKey: "path.utf-8", in: pairs) != nil ? "path.utf-8" : "path"
        guard let node = value(forKey: key, in: pairs),
              case .list(let pathNodes) = node.value else {
            return nil
        }

        let segments = pathNodes.compactMap { node -> String? in
            guard case .string(let data) = node.value else { return nil }
            return String(data: data, encoding: .utf8)
        }
        return segments.isEmpty ? nil : segments.joined(separator: "/")
    }

    private func piecesCount(offset: Int64, length: Int64, pieceLength: Int64?) -> Int {
        guard let pieceLength, pieceLength > 0, length > 0 else { return 0 }
        let startPiece = offset / pieceLength
        let endPiece = (offset + length - 1) / pieceLength
        return Int(endPiece - startPiece + 1)
    }

    private func parseTrackers(from rootPairs: [(key: Data, value: BencodeNode)]) -> [String] {
        var all: [String] = []

        if let announce = readString(forKey: "announce", in: rootPairs) {
            all.append(announce)
        }

        if let listNode = value(forKey: "announce-list", in: rootPairs),
           case .list(let tiers) = listNode.value {
            for tier in tiers {
                switch tier.value {
                case .list(let tierValues):
                    for node in tierValues {
                        if case .string(let data) = node.value,
                           let text = String(data: data, encoding: .utf8),
                           !text.isEmpty {
                            all.append(text)
                        }
                    }
                case .string(let data):
                    if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                        all.append(text)
                    }
                default:
                    continue
                }
            }
        }

        var seen = Set<String>()
        return all.filter { seen.insert($0).inserted }
    }

    private func value(forKey key: String, in pairs: [(key: Data, value: BencodeNode)]) -> BencodeNode? {
        for pair in pairs {
            if String(data: pair.key, encoding: .utf8) == key {
                return pair.value
            }
        }
        return nil
    }

    private func readString(forKey key: String, in pairs: [(key: Data, value: BencodeNode)]) -> String? {
        guard let node = value(forKey: key, in: pairs),
              case .string(let data) = node.value else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func readInt(forKey key: String, in pairs: [(key: Data, value: BencodeNode)]) -> Int64? {
        guard let node = value(forKey: key, in: pairs),
              case .integer(let value) = node.value else {
            return nil
        }
        return value
    }

    private func sha1Hex(of data: Data) -> String {
        Insecure.SHA1.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
