import Foundation

public enum TileSprites {
    public static let all: [String: PixelSprite] = [
        "tile-ground": tileSprite(fill: 3, border: 2),
        "tile-airway": tileSprite(fill: 13, border: 0),
        "tile-cloud": tileSprite(fill: 12, border: 6),
        "tile-water": tileSprite(fill: 11, border: 0),
        "tile-terrain": tileSprite(fill: 2, border: 0),
        "tile-building": tileSprite(fill: 9, border: 0),
        "tile-door": tileSprite(fill: 8, border: 6),
        "tile-sign": tileSprite(fill: 5, border: 0),
        "walker-down-0": walkerSprite(fill: 4, border: 0, detail: 6, footLeft: true),
        "walker-down-1": walkerSprite(fill: 4, border: 0, detail: 6, footLeft: false),
        "walker-up-0": walkerSprite(fill: 5, border: 0, detail: 2, footLeft: true),
        "walker-up-1": walkerSprite(fill: 5, border: 0, detail: 2, footLeft: false),
        "walker-left-0": walkerSprite(fill: 9, border: 0, detail: 7, footLeft: true),
        "walker-left-1": walkerSprite(fill: 9, border: 0, detail: 7, footLeft: false),
        "trainer-student": walkerSprite(fill: 10, border: 0, detail: 3, footLeft: true),
        "path-marker": pathMarker,
    ]

    public static func name(for kind: TileKind) -> String {
        switch kind {
        case .ground: return "tile-ground"
        case .airway: return "tile-airway"
        case .cloud: return "tile-cloud"
        case .water: return "tile-water"
        case .terrain: return "tile-terrain"
        case .building: return "tile-building"
        case .door: return "tile-door"
        case .sign: return "tile-sign"
        }
    }

    private static let pathMarker = try! PixelSprite(rows: (0..<16).map { y in
        String((0..<16).map { x -> Character in
            abs(x - 7) + abs(y - 7) <= 3 ? "5" : "."
        })
    })

    private static func tileSprite(fill: UInt8, border: UInt8) -> PixelSprite {
        try! PixelSprite(rows: (0..<16).map { y in
            String((0..<16).map { x -> Character in
                isEdge(x, y) ? hexDigit(border) : hexDigit(fill)
            })
        })
    }

    private static func walkerSprite(fill: UInt8, border: UInt8, detail: UInt8, footLeft: Bool) -> PixelSprite {
        try! PixelSprite(rows: (0..<16).map { y in
            String((0..<16).map { x -> Character in
                walkerPixel(x, y, fill: fill, border: border, detail: detail, footLeft: footLeft)
            })
        })
    }

    private static func walkerPixel(_ x: Int, _ y: Int, fill: UInt8, border: UInt8, detail: UInt8, footLeft: Bool) -> Character {
        if isEdge(x, y) { return hexDigit(border) }
        if isFoot(x, y, footLeft: footLeft) { return hexDigit(detail) }
        return hexDigit(fill)
    }

    private static func isEdge(_ x: Int, _ y: Int) -> Bool {
        x == 0 || x == 15 || y == 0 || y == 15
    }

    private static func isFoot(_ x: Int, _ y: Int, footLeft: Bool) -> Bool {
        y >= 12 && (footLeft ? x < 8 : x >= 8)
    }

    private static func hexDigit(_ value: UInt8) -> Character {
        Character(String(value, radix: 16))
    }
}
