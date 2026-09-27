import Foundation

public struct TileMap: Codable, Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let rows: [[TileKind]]

    private enum CodingKeys: String, CodingKey {
        case width, height, rows
    }

    public init(width: Int, height: Int, rows: [[TileKind]]) {
        self.width = width
        self.height = height
        self.rows = rows
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        width = try container.decode(Int.self, forKey: .width)
        height = try container.decode(Int.self, forKey: .height)
        let glyphRows = try container.decode([String].self, forKey: .rows)
        rows = try TileMap.decodeRows(glyphRows)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        try container.encode(TileMap.encodeRows(rows), forKey: .rows)
    }

    public subscript(_ point: GridPoint) -> TileKind? {
        guard rows.indices.contains(point.y) else { return nil }
        let row = rows[point.y]
        guard row.indices.contains(point.x) else { return nil }
        return row[point.x]
    }

    private static func decodeRows(_ glyphRows: [String]) throws -> [[TileKind]] {
        let characterRows = glyphRows.map { Array($0) }
        let expectedWidth = characterRows.first?.count ?? 0
        guard characterRows.allSatisfy({ $0.count == expectedWidth }) else {
            throw AdventureContentError.raggedRows
        }
        return try characterRows.enumerated().map { y, row in
            try row.enumerated().map { x, glyph in
                guard let kind = TileKind(rawValue: glyph) else {
                    throw AdventureContentError.unknownTile(x: x, y: y)
                }
                return kind
            }
        }
    }

    private static func encodeRows(_ kindRows: [[TileKind]]) -> [String] {
        kindRows.map { row in String(row.map(\.rawValue)) }
    }
}
