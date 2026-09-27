import Foundation

public enum EliteSprites {
    public static let all: [String: PixelSprite] = [
        "elite-sierra": sierra,
        "elite-tango": tango,
        "elite-uniform": uniform,
        "elite-whiskey": whiskey,
        "champion": champion,
    ]

    private static let sierra = PlayerSprites.battleSilhouette.recoloured([1: 2, 4: 7, 9: 12])
    private static let tango = PlayerSprites.battleSilhouette.recoloured([1: 3, 4: 9, 9: 13])
    private static let uniform = PlayerSprites.battleSilhouette.recoloured([1: 5, 4: 10, 9: 14])
    private static let whiskey = PlayerSprites.battleSilhouette.recoloured([1: 1, 4: 6, 9: 11])
    private static let champion = PlayerSprites.battleSilhouette.recoloured([1: 7, 4: 11, 9: 15])
}
