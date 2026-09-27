import Foundation

public struct GridRect: Codable, Equatable, Sendable {
    public let x: Int
    public let y: Int
    public let w: Int
    public let h: Int

    public init(x: Int, y: Int, w: Int, h: Int) {
        self.x = x
        self.y = y
        self.w = w
        self.h = h
    }

    public func contains(_ point: GridPoint) -> Bool {
        point.x >= x && point.x < x + w && point.y >= y && point.y < y + h
    }
}

public struct TileArea: Codable, Equatable, Sendable {
    public let id: String
    public let category: Category
    public let rect: GridRect

    public init(id: String, category: Category, rect: GridRect) {
        self.id = id
        self.category = category
        self.rect = rect
    }
}

public struct TileMap: Codable, Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let rows: [[TileKind]]
    public let doorAirportIDs: [GridPoint: String]
    public let signTexts: [GridPoint: String]
    public let itemDropItemIDs: [GridPoint: String]
    public let spawn: GridPoint
    public let areas: [TileArea]

    private enum CodingKeys: String, CodingKey {
        case width, height, rows, warps, signs, itemDrops, spawn, areas
    }

    private struct Warp: Codable { let at: GridPoint; let airportID: String }
    private struct Sign: Codable { let at: GridPoint; let text: String }
    private struct ItemDrop: Codable { let id: String; let at: GridPoint; let itemID: String }

    public init(
        width: Int, height: Int, rows: [[TileKind]],
        doorAirportIDs: [GridPoint: String] = [:],
        signTexts: [GridPoint: String] = [:],
        itemDropItemIDs: [GridPoint: String] = [:],
        spawn: GridPoint = GridPoint(x: 0, y: 0),
        areas: [TileArea] = []
    ) {
        self.width = width
        self.height = height
        self.rows = rows
        self.doorAirportIDs = doorAirportIDs
        self.signTexts = signTexts
        self.itemDropItemIDs = itemDropItemIDs
        self.spawn = spawn
        self.areas = areas
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        width = try container.decode(Int.self, forKey: .width)
        height = try container.decode(Int.self, forKey: .height)
        let glyphRows = try container.decode([String].self, forKey: .rows)
        rows = try TileMap.decodeRows(glyphRows)
        let warps = try container.decodeIfPresent([Warp].self, forKey: .warps) ?? []
        doorAirportIDs = Dictionary(uniqueKeysWithValues: warps.map { ($0.at, $0.airportID) })
        let signs = try container.decodeIfPresent([Sign].self, forKey: .signs) ?? []
        signTexts = Dictionary(uniqueKeysWithValues: signs.map { ($0.at, $0.text) })
        let itemDrops = try container.decodeIfPresent([ItemDrop].self, forKey: .itemDrops) ?? []
        itemDropItemIDs = Dictionary(uniqueKeysWithValues: itemDrops.map { ($0.at, $0.itemID) })
        spawn = try container.decodeIfPresent(GridPoint.self, forKey: .spawn) ?? GridPoint(x: 0, y: 0)
        areas = try container.decodeIfPresent([TileArea].self, forKey: .areas) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        try container.encode(TileMap.encodeRows(rows), forKey: .rows)
        try container.encode(doorAirportIDs.map { Warp(at: $0.key, airportID: $0.value) }, forKey: .warps)
        try container.encode(signTexts.map { Sign(at: $0.key, text: $0.value) }, forKey: .signs)
        try container.encode(itemDropItemIDs.map { ItemDrop(id: "\($0.key.x)-\($0.key.y)", at: $0.key, itemID: $0.value) }, forKey: .itemDrops)
        try container.encode(spawn, forKey: .spawn)
        try container.encode(areas, forKey: .areas)
    }

    public subscript(_ point: GridPoint) -> TileKind? {
        guard rows.indices.contains(point.y) else { return nil }
        let row = rows[point.y]
        guard row.indices.contains(point.x) else { return nil }
        return row[point.x]
    }

    public func category(at point: GridPoint) -> Category? {
        areas.first { $0.rect.contains(point) }?.category
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
