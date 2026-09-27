import Foundation

public struct NamePlate: Equatable, Sendable {
    public let origin: GridPoint
    public let showsNumbers: Bool

    public init(origin: GridPoint, showsNumbers: Bool) {
        self.origin = origin
        self.showsNumbers = showsNumbers
    }

    public static let enemy = NamePlate(origin: GridPoint(x: 16, y: 16), showsNumbers: false)
    public static let player = NamePlate(origin: GridPoint(x: 144, y: 80), showsNumbers: true)

    public var height: Int {
        showsNumbers ? 20 : 12
    }

    public var nameOrigin: GridPoint {
        GridPoint(x: origin.x + 2, y: origin.y + 1)
    }

    public var barOrigin: GridPoint {
        GridPoint(x: origin.x + 8, y: origin.y + 7)
    }

    public var numbersRightEdge: GridPoint? {
        guard showsNumbers else { return nil }
        return GridPoint(x: origin.x + 62, y: origin.y + 12)
    }
}
