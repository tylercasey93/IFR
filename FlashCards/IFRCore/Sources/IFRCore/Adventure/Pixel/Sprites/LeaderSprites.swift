import Foundation

public enum LeaderSprites {
    public static let all: [String: PixelSprite] = [
        "leader-hypoxia": hypoxia,
        "leader-gyro": gyro,
        "leader-reg": reg,
        "leader-victor": victor,
        "leader-plotter": plotter,
        "leader-nimbus": nimbus,
        "leader-mayday": mayday,
        "leader-ilsa": ilsa,
    ]

    private static let hypoxia = PlayerSprites.battleSilhouette.recoloured([1: 2, 4: 3, 9: 5])
    private static let gyro = PlayerSprites.battleSilhouette.recoloured([1: 4, 4: 5, 9: 6])
    private static let reg = PlayerSprites.battleSilhouette.recoloured([1: 7, 4: 8, 9: 9])
    private static let victor = PlayerSprites.battleSilhouette.recoloured([1: 10, 4: 11, 9: 12])
    private static let plotter = PlayerSprites.battleSilhouette.recoloured([1: 13, 4: 14, 9: 15])
    private static let nimbus = PlayerSprites.battleSilhouette.recoloured([1: 0, 4: 2, 9: 4])
    private static let mayday = PlayerSprites.battleSilhouette.recoloured([1: 1, 4: 3, 9: 5])
    private static let ilsa = PlayerSprites.battleSilhouette.recoloured([1: 6, 4: 8, 9: 10])
}
