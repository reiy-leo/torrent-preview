import Foundation

enum BencodeValue {
    case integer(Int64)
    case string(Data)
    case list([BencodeNode])
    case dictionary([(key: Data, value: BencodeNode)])
}

struct BencodeNode {
    let value: BencodeValue
    let byteRange: Range<Int>
}

enum BencodeError: Error, LocalizedError {
    case unexpectedEOF
    case invalidToken(UInt8)
    case invalidInteger
    case invalidStringLength
    case trailingData

    var errorDescription: String? {
        switch self {
        case .unexpectedEOF:
            return L10n.tr("error.unexpectedEOF")
        case .invalidToken(let token):
            let tokenText = String(Character(UnicodeScalar(token)))
            return String(format: L10n.tr("error.invalidToken"), tokenText)
        case .invalidInteger:
            return L10n.tr("error.invalidInteger")
        case .invalidStringLength:
            return L10n.tr("error.invalidStringLength")
        case .trailingData:
            return L10n.tr("error.trailingData")
        }
    }
}

final class BencodeDecoder {
    private let bytes: [UInt8]
    private var index: Int = 0

    init(data: Data) {
        self.bytes = Array(data)
    }

    func decode() throws -> BencodeNode {
        let node = try parseNode()
        guard index == bytes.count else {
            throw BencodeError.trailingData
        }
        return node
    }

    private func parseNode() throws -> BencodeNode {
        guard index < bytes.count else { throw BencodeError.unexpectedEOF }
        let start = index
        let token = bytes[index]

        switch token {
        case UInt8(ascii: "i"):
            let intValue = try parseInteger()
            return BencodeNode(value: .integer(intValue), byteRange: start..<index)
        case UInt8(ascii: "l"):
            index += 1
            var values: [BencodeNode] = []
            while true {
                guard index < bytes.count else { throw BencodeError.unexpectedEOF }
                if bytes[index] == UInt8(ascii: "e") {
                    index += 1
                    break
                }
                values.append(try parseNode())
            }
            return BencodeNode(value: .list(values), byteRange: start..<index)
        case UInt8(ascii: "d"):
            index += 1
            var pairs: [(key: Data, value: BencodeNode)] = []
            while true {
                guard index < bytes.count else { throw BencodeError.unexpectedEOF }
                if bytes[index] == UInt8(ascii: "e") {
                    index += 1
                    break
                }
                let keyNode = try parseNode()
                guard case .string(let keyData) = keyNode.value else {
                    throw BencodeError.invalidToken(bytes[index])
                }
                let value = try parseNode()
                pairs.append((key: keyData, value: value))
            }
            return BencodeNode(value: .dictionary(pairs), byteRange: start..<index)
        case UInt8(ascii: "0")...UInt8(ascii: "9"):
            let stringData = try parseString()
            return BencodeNode(value: .string(stringData), byteRange: start..<index)
        default:
            throw BencodeError.invalidToken(token)
        }
    }

    private func parseInteger() throws -> Int64 {
        guard bytes[index] == UInt8(ascii: "i") else { throw BencodeError.invalidInteger }
        index += 1

        let start = index
        while index < bytes.count, bytes[index] != UInt8(ascii: "e") {
            index += 1
        }

        guard index < bytes.count else { throw BencodeError.unexpectedEOF }
        let numBytes = bytes[start..<index]
        index += 1

        guard let text = String(bytes: numBytes, encoding: .utf8),
              let value = Int64(text) else {
            throw BencodeError.invalidInteger
        }
        return value
    }

    private func parseString() throws -> Data {
        let lengthStart = index
        while index < bytes.count, bytes[index] != UInt8(ascii: ":") {
            guard bytes[index].isASCIIDigit else {
                throw BencodeError.invalidStringLength
            }
            index += 1
        }

        guard index < bytes.count else { throw BencodeError.unexpectedEOF }
        let lengthBytes = bytes[lengthStart..<index]
        index += 1

        guard let text = String(bytes: lengthBytes, encoding: .utf8),
              let length = Int(text),
              length >= 0 else {
            throw BencodeError.invalidStringLength
        }

        let end = index + length
        guard end <= bytes.count else { throw BencodeError.unexpectedEOF }
        let data = Data(bytes[index..<end])
        index = end
        return data
    }
}

private extension UInt8 {
    var isASCIIDigit: Bool {
        self >= UInt8(ascii: "0") && self <= UInt8(ascii: "9")
    }
}
