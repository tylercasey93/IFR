import Foundation

public enum SpriteCatalog {
    public static let all: [String: PixelSprite] = UISprites.all
        .merging(PlayerSprites.all) { _, new in new }
        .merging(LeaderSprites.all) { _, new in new }
        .merging(EliteSprites.all) { _, new in new }

    public static func sprite(named name: String) -> PixelSprite? {
        all[name]
    }
}
