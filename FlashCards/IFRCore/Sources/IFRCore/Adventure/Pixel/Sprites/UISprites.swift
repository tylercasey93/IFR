import Foundation

public enum UISprites {
    public static let all: [String: PixelSprite] = [
        "cursor": cursor,
        "airport": airport,
        "badge-humanFactors": badgeHumanFactors,
        "badge-instrumentsAndSystems": badgeInstrumentsAndSystems,
        "badge-regulations": badgeRegulations,
        "badge-navigation": badgeNavigation,
        "badge-chartsAndPlanning": badgeChartsAndPlanning,
        "badge-weather": badgeWeather,
        "badge-emergencies": badgeEmergencies,
        "badge-approaches": badgeApproaches,
    ]

    private static let cursor = try! PixelSprite(rows: [
        "6.......",
        "66......",
        "666.....",
        "6666....",
        "666.....",
        "66......",
        "6.......",
        "........",
    ])

    private static let airport = try! PixelSprite(rows: [
        "...44...",
        "...44...",
        "...44...",
        "..4444..",
        ".444444.",
        "44444444",
        "...11...",
        "...11...",
    ])

    private static let badgeDiamond = try! PixelSprite(rows: [
        "........",
        "...99...",
        "..9779..",
        ".977779.",
        ".977779.",
        "..9779..",
        "...99...",
        "........",
    ])

    private static let badgeHumanFactors = badgeDiamond.recoloured([9: 2, 7: 5])
    private static let badgeInstrumentsAndSystems = badgeDiamond.recoloured([9: 4, 7: 6])
    private static let badgeRegulations = badgeDiamond.recoloured([9: 8, 7: 9])
    private static let badgeNavigation = badgeDiamond.recoloured([9: 10, 7: 12])
    private static let badgeChartsAndPlanning = badgeDiamond.recoloured([9: 13, 7: 15])
    private static let badgeWeather = badgeDiamond.recoloured([9: 0, 7: 2])
    private static let badgeEmergencies = badgeDiamond.recoloured([9: 1, 7: 3])
    private static let badgeApproaches = badgeDiamond.recoloured([9: 6, 7: 8])
}
