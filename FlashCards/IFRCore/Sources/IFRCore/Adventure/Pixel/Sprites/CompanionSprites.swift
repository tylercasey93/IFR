import Foundation

public enum CompanionSprites {
    public static let all: [String: PixelSprite] = [
        "comp-hf-1": hf1, "comp-hf-2": hf2, "comp-hf-3": hf3,
        "comp-ins-1": ins1, "comp-ins-2": ins2, "comp-ins-3": ins3,
        "comp-reg-1": reg1, "comp-reg-2": reg2, "comp-reg-3": reg3,
        "comp-nav-1": nav1, "comp-nav-2": nav2, "comp-nav-3": nav3,
        "comp-cnp-1": cnp1, "comp-cnp-2": cnp2, "comp-cnp-3": cnp3,
        "comp-wx-1": wx1, "comp-wx-2": wx2, "comp-wx-3": wx3,
        "comp-emg-1": emg1, "comp-emg-2": emg2, "comp-emg-3": emg3,
        "comp-app-1": app1, "comp-app-2": app2, "comp-app-3": app3,
    ]

    private static let hf1 = PlayerSprites.battleSilhouette.recoloured([1: 2, 4: 3, 9: 5])
    private static let hf2 = PlayerSprites.battleSilhouette.recoloured([1: 3, 4: 5, 9: 6])
    private static let hf3 = PlayerSprites.battleSilhouette.recoloured([1: 5, 4: 6, 9: 7])

    private static let ins1 = PlayerSprites.battleSilhouette.recoloured([1: 4, 4: 5, 9: 6])
    private static let ins2 = PlayerSprites.battleSilhouette.recoloured([1: 5, 4: 6, 9: 7])
    private static let ins3 = PlayerSprites.battleSilhouette.recoloured([1: 6, 4: 7, 9: 8])

    private static let reg1 = PlayerSprites.battleSilhouette.recoloured([1: 7, 4: 8, 9: 9])
    private static let reg2 = PlayerSprites.battleSilhouette.recoloured([1: 8, 4: 9, 9: 10])
    private static let reg3 = PlayerSprites.battleSilhouette.recoloured([1: 9, 4: 10, 9: 11])

    private static let nav1 = PlayerSprites.battleSilhouette.recoloured([1: 10, 4: 11, 9: 12])
    private static let nav2 = PlayerSprites.battleSilhouette.recoloured([1: 11, 4: 12, 9: 13])
    private static let nav3 = PlayerSprites.battleSilhouette.recoloured([1: 12, 4: 13, 9: 14])

    private static let cnp1 = PlayerSprites.battleSilhouette.recoloured([1: 13, 4: 14, 9: 15])
    private static let cnp2 = PlayerSprites.battleSilhouette.recoloured([1: 14, 4: 15, 9: 6])
    private static let cnp3 = PlayerSprites.battleSilhouette.recoloured([1: 15, 4: 6, 9: 7])

    private static let wx1 = PlayerSprites.battleSilhouette.recoloured([1: 0, 4: 2, 9: 4])
    private static let wx2 = PlayerSprites.battleSilhouette.recoloured([1: 1, 4: 3, 9: 5])
    private static let wx3 = PlayerSprites.battleSilhouette.recoloured([1: 2, 4: 4, 9: 6])

    private static let emg1 = PlayerSprites.battleSilhouette.recoloured([1: 1, 4: 3, 9: 5])
    private static let emg2 = PlayerSprites.battleSilhouette.recoloured([1: 2, 4: 4, 9: 6])
    private static let emg3 = PlayerSprites.battleSilhouette.recoloured([1: 3, 4: 5, 9: 7])

    private static let app1 = PlayerSprites.battleSilhouette.recoloured([1: 6, 4: 8, 9: 10])
    private static let app2 = PlayerSprites.battleSilhouette.recoloured([1: 7, 4: 9, 9: 11])
    private static let app3 = PlayerSprites.battleSilhouette.recoloured([1: 8, 4: 10, 9: 12])
}
