import Foundation

public enum UISprites {
    public static let all: [String: PixelSprite] = [
        "cursor": cursor,
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
}
