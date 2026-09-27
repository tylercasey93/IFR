import XCTest
@testable import IFRCore

final class DirectToTests: XCTestCase {
    private func airport(_ id: String, role: AirportRole = .waypoint) -> Airport {
        Airport(id: id, name: id, position: GridPoint(x: 0, y: 0), gymID: nil, role: role)
    }

    func testDirectToOnlyTargetsVisitedAirports() {
        let region = RegionMap(
            airports: [airport("KHYP"), airport("KGYR"), airport("KELF")],
            airways: []
        )
        var save = AdventureSave.new
        save.visitedAirportIDs = ["KGYR", "KHYP"]
        let targets = DirectTo.targets(save: save, region: region)
        XCTAssertEqual(targets.map(\.id), ["KHYP", "KGYR"])
    }

    func testDirectToDestinationIsTheAirportDoorTile() {
        let map = TileMap(
            width: 1, height: 1, rows: [[.door]],
            doorAirportIDs: [GridPoint(x: 0, y: 0): "KHYP"]
        )
        let destination = DirectTo.destination(of: airport("KHYP"), in: map)
        XCTAssertEqual(destination, GridPoint(x: 0, y: 0))
    }
}
