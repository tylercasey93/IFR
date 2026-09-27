import Foundation

public enum PixelSpriteError: Error, Equatable {
    case raggedRows
    case badCharacter(Character)
}

public struct PixelSprite: Equatable, Sendable {
    public let width: Int
    public let height: Int
    private let indices: [UInt8]

    public init(rows: [String]) throws {
        let charRows = rows.map { Array($0) }
        let width = charRows.first?.count ?? 0
        guard charRows.allSatisfy({ $0.count == width }) else {
            throw PixelSpriteError.raggedRows
        }
        var indices: [UInt8] = []
        indices.reserveCapacity(width * charRows.count)
        for row in charRows {
            for character in row {
                indices.append(try PixelSprite.index(for: character))
            }
        }
        self.width = width
        self.height = charRows.count
        self.indices = indices
    }

    private init(width: Int, height: Int, indices: [UInt8]) {
        self.width = width
        self.height = height
        self.indices = indices
    }

    public subscript(x: Int, y: Int) -> UInt8 {
        indices[y * width + x]
    }

    public func flippedHorizontally() -> PixelSprite {
        var flipped = indices
        for y in 0..<height {
            for x in 0..<width {
                flipped[y * width + x] = indices[y * width + (width - 1 - x)]
            }
        }
        return PixelSprite(width: width, height: height, indices: flipped)
    }

    public func recoloured(_ map: [UInt8: UInt8]) -> PixelSprite {
        PixelSprite(width: width, height: height, indices: indices.map { map[$0] ?? $0 })
    }

    private static func index(for character: Character) throws -> UInt8 {
        if character == "." {
            return Palette.transparent
        }
        if let value = character.hexDigitValue {
            return UInt8(value)
        }
        throw PixelSpriteError.badCharacter(character)
    }
}
