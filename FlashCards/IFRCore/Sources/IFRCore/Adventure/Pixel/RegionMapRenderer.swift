import Foundation

public enum RegionMapRenderer {
    public static let cellSize = 8
    public static let columns = 30
    public static let rows = 14

    private static let panelIndex: UInt8 = 1
    private static let airwayIndex: UInt8 = 11
    private static let lockedIndex: UInt8 = 13
    private static let badgedIndex: UInt8 = 4
    private static let nextGymIndex: UInt8 = 7
    private static let waypointIndex: UInt8 = 14
    private static let dialogueOuter: UInt8 = 6
    private static let dialogueInner: UInt8 = 0
    private static let dialogueBox = PixelRect(x: 0, y: 112, width: 240, height: 48)

    public static func frame(region: RegionMap, save: AdventureSave, nextGym: GymID?, selected: String?) -> PixelFrame {
        var canvas = PixelFrame(fill: panelIndex)
        drawAirways(&canvas, region: region)
        drawAirports(&canvas, region: region, save: save, nextGym: nextGym)
        canvas.frame(dialogueBox, outer: dialogueOuter, inner: dialogueInner)
        return canvas
    }

    public static func cell(containing point: GridPoint) -> GridPoint {
        GridPoint(x: point.x / cellSize, y: point.y / cellSize)
    }

    private static func drawAirways(_ canvas: inout PixelFrame, region: RegionMap) {
        let airportsByID = Dictionary(uniqueKeysWithValues: region.airports.map { ($0.id, $0) })
        for airway in region.airways {
            guard let from = airportsByID[airway.from], let to = airportsByID[airway.to] else { continue }
            canvas.line(from: cellCentre(of: from.position), to: cellCentre(of: to.position), index: airwayIndex)
        }
    }

    private static func drawAirports(
        _ canvas: inout PixelFrame, region: RegionMap, save: AdventureSave, nextGym: GymID?
    ) {
        guard let sprite = SpriteCatalog.sprite(named: "airport") else { return }
        for airport in region.airports {
            let colour = colourIndex(for: airport, save: save, nextGym: nextGym)
            let recoloured = sprite.recoloured([badgedIndex: colour])
            let origin = GridPoint(x: airport.position.x * cellSize, y: airport.position.y * cellSize)
            canvas.blit(recoloured, at: origin)
        }
    }

    private static func colourIndex(for airport: Airport, save: AdventureSave, nextGym: GymID?) -> UInt8 {
        switch airport.role {
        case .waypoint:
            return waypointIndex
        case .gym:
            return gymColourIndex(airport.gymID, save: save, nextGym: nextGym)
        case .eliteFour:
            return CircuitRules.isEliteFourUnlocked(save: save) ? nextGymIndex : lockedIndex
        case .champion:
            return CircuitRules.isChampionUnlocked(save: save) ? nextGymIndex : lockedIndex
        }
    }

    private static func gymColourIndex(_ gymID: GymID?, save: AdventureSave, nextGym: GymID?) -> UInt8 {
        guard let gymID else { return lockedIndex }
        if save.badges.contains(gymID) { return badgedIndex }
        if gymID == nextGym { return nextGymIndex }
        return lockedIndex
    }

    private static func cellCentre(of position: GridPoint) -> GridPoint {
        GridPoint(x: position.x * cellSize + cellSize / 2, y: position.y * cellSize + cellSize / 2)
    }
}
