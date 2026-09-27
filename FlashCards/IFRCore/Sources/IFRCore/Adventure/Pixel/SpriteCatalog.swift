import Foundation

public enum SpriteCatalog {
    public static let all: [String: PixelSprite] = UISprites.all

    public static func sprite(named name: String) -> PixelSprite? {
        all[name]
    }
}
