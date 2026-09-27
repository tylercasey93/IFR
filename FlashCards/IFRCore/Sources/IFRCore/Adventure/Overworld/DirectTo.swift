import Foundation

public enum DirectTo {
    public static func targets(save: AdventureSave, region: RegionMap) -> [Airport] {
        region.airports.filter { save.visitedAirportIDs.contains($0.id) }
    }

    public static func destination(of airport: Airport, in map: TileMap) -> GridPoint? {
        map.doorAirportIDs.first { $0.value == airport.id }?.key
    }
}
