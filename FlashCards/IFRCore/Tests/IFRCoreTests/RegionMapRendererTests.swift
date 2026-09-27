import XCTest
@testable import IFRCore

final class RegionMapRendererTests: XCTestCase {
    private func makeAirport(
        id: String, x: Int, y: Int, gymID: GymID? = nil, role: AirportRole = .gym
    ) -> Airport {
        Airport(id: id, name: id, position: GridPoint(x: x, y: y), gymID: gymID, role: role)
    }

    private func makeSave(badges: Set<GymID> = []) -> AdventureSave {
        var save = AdventureSave.new
        save.badges = badges
        return save
    }

    private func pixel(_ frame: PixelFrame, _ x: Int, _ y: Int) -> UInt8 {
        frame.pixels[y * PixelFrame.width + x]
    }

    private func cellPixels(_ frame: PixelFrame, cell: GridPoint) -> [UInt8] {
        let originX = cell.x * RegionMapRenderer.cellSize
        let originY = cell.y * RegionMapRenderer.cellSize
        var values: [UInt8] = []
        for y in originY..<(originY + RegionMapRenderer.cellSize) {
            for x in originX..<(originX + RegionMapRenderer.cellSize) {
                values.append(pixel(frame, x, y))
            }
        }
        return values
    }

    func testLockedAirportsUseGreyIndex() {
        let khyp = makeAirport(id: "KHYP", x: 3, y: 12, gymID: .humanFactors, role: .gym)
        let region = RegionMap(airports: [khyp], airways: [])
        let frame = RegionMapRenderer.frame(region: region, save: makeSave(), nextGym: .instrumentsAndSystems, selected: nil)
        let cell = cellPixels(frame, cell: GridPoint(x: 3, y: 12))
        XCTAssertTrue(cell.contains(13))
        XCTAssertFalse(cell.contains(4))
        XCTAssertFalse(cell.contains(7))
    }

    func testBadgedAirportsUseAccentIndex() {
        let khyp = makeAirport(id: "KHYP", x: 3, y: 12, gymID: .humanFactors, role: .gym)
        let region = RegionMap(airports: [khyp], airways: [])
        let frame = RegionMapRenderer.frame(region: region, save: makeSave(badges: [.humanFactors]), nextGym: nil, selected: nil)
        let cell = cellPixels(frame, cell: GridPoint(x: 3, y: 12))
        XCTAssertTrue(cell.contains(4))
    }

    func testNextGymUsesAmberIndex() {
        let khyp = makeAirport(id: "KHYP", x: 3, y: 12, gymID: .humanFactors, role: .gym)
        let region = RegionMap(airports: [khyp], airways: [])
        let frame = RegionMapRenderer.frame(region: region, save: makeSave(), nextGym: .humanFactors, selected: nil)
        let cell = cellPixels(frame, cell: GridPoint(x: 3, y: 12))
        XCTAssertTrue(cell.contains(7))
    }

    func testAirwaysDrawnBetweenAirportCellCentres() {
        let khyp = makeAirport(id: "KHYP", x: 3, y: 12, gymID: .humanFactors, role: .gym)
        let kgyr = makeAirport(id: "KGYR", x: 9, y: 10, gymID: .instrumentsAndSystems, role: .gym)
        let airway = Airway(id: "V1", from: "KHYP", to: "KGYR")
        let region = RegionMap(airports: [khyp, kgyr], airways: [airway])
        let frame = RegionMapRenderer.frame(region: region, save: makeSave(), nextGym: nil, selected: nil)
        XCTAssertEqual(pixel(frame, 52, 92), 11)
    }

    func testCellContainingPointDividesByEight() {
        XCTAssertEqual(RegionMapRenderer.cell(containing: GridPoint(x: 20, y: 12)), GridPoint(x: 2, y: 1))
        XCTAssertEqual(RegionMapRenderer.cell(containing: GridPoint(x: 7, y: 7)), GridPoint(x: 0, y: 0))
        XCTAssertEqual(RegionMapRenderer.cell(containing: GridPoint(x: 239, y: 111)), GridPoint(x: 29, y: 13))
    }
}
