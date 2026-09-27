import Foundation

public struct PaletteColor: Equatable, Sendable {
    public let r: UInt8
    public let g: UInt8
    public let b: UInt8

    public init(r: UInt8, g: UInt8, b: UInt8) {
        self.r = r
        self.g = g
        self.b = b
    }
}

public enum Palette {
    public static let transparent: UInt8 = 255

    public static let entries: [PaletteColor] = [
        PaletteColor(r: 0x0A, g: 0x0C, b: 0x0B),
        PaletteColor(r: 0x1A, g: 0x1F, b: 0x1C),
        PaletteColor(r: 0x2E, g: 0x3A, b: 0x33),
        PaletteColor(r: 0x47, g: 0x60, b: 0x4F),
        PaletteColor(r: 0x5C, g: 0xC7, b: 0x8C),
        PaletteColor(r: 0x9F, g: 0xE6, b: 0xBC),
        PaletteColor(r: 0xE8, g: 0xF5, b: 0xEC),
        PaletteColor(r: 0xF5, g: 0xBA, b: 0x3B),
        PaletteColor(r: 0xB8, g: 0x79, b: 0x1A),
        PaletteColor(r: 0x7A, g: 0x3A, b: 0x1E),
        PaletteColor(r: 0xE0, g: 0x5A, b: 0x4E),
        PaletteColor(r: 0x3E, g: 0x6F, b: 0xA8),
        PaletteColor(r: 0x8F, g: 0xB8, b: 0xE8),
        PaletteColor(r: 0x6B, g: 0x6F, b: 0x6C),
        PaletteColor(r: 0xC9, g: 0xCD, b: 0xCA),
        PaletteColor(r: 0xFF, g: 0xFF, b: 0xFF),
    ]
}
