#!/usr/bin/env swift
// scripts/make-icon.swift
// Generates a 1024x1024 app icon with radial gradient background and text

import AppKit
import CoreGraphics

let size: CGFloat = 1024

// Create a bitmap context directly for better control
let colorSpace = CGColorSpaceCreateDeviceRGB()
let bitmapContext = CGContext(
    data: nil,
    width: Int(size),
    height: Int(size),
    bitsPerComponent: 8,
    bytesPerRow: Int(size) * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!

// Fill with radial gradient background
let colors: [CGColor] = [
    CGColor(red: 0.1, green: 0.17, blue: 0.24, alpha: 1),    // #1a2b3c (outer)
    CGColor(red: 0.04, green: 0.08, blue: 0.125, alpha: 1)   // #0a1520 (inner)
]

if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: nil) {
    let center = CGPoint(x: size / 2, y: size / 2)
    bitmapContext.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: size * 0.7, options: .drawsAfterEndLocation)
}

// Create NSGraphicsContext from the CGContext to draw text
let nsGraphicsContext = NSGraphicsContext(cgContext: bitmapContext, flipped: false)
NSGraphicsContext.current = nsGraphicsContext

// Draw "IFR" text
let ifrAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.boldSystemFont(ofSize: 340),
    .foregroundColor: NSColor(red: 0.36, green: 0.78, blue: 0.55, alpha: 1)  // #5cc78d
]
let ifrString = NSAttributedString(string: "IFR", attributes: ifrAttributes)
let ifrSize = ifrString.size()
let ifrRect = CGRect(
    x: (size - ifrSize.width) / 2,
    y: (size - ifrSize.height) / 2 - 40,
    width: ifrSize.width,
    height: ifrSize.height
)
ifrString.draw(in: ifrRect)

// Draw "FLASHCARDS" text
let flashcardsAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.boldSystemFont(ofSize: 90),
    .foregroundColor: NSColor(red: 0.36, green: 0.78, blue: 0.55, alpha: 1)  // #5cc78d
]
let flashcardsString = NSAttributedString(string: "FLASHCARDS", attributes: flashcardsAttributes)
let flashcardsSize = flashcardsString.size()
let flashcardsRect = CGRect(
    x: (size - flashcardsSize.width) / 2,
    y: (size - flashcardsSize.height) / 2 + 180,
    width: flashcardsSize.width,
    height: flashcardsSize.height
)
flashcardsString.draw(in: flashcardsRect)

NSGraphicsContext.current = nil

// Create CGImage from bitmap context
guard let cgImage = bitmapContext.makeImage() else {
    print("Error creating CGImage")
    exit(1)
}

// Convert to NSImage and save
let nsImage = NSImage(cgImage: cgImage, size: NSZeroSize)

// Output path derived from this script's own location (repo-root-relative),
// so the icon can be regenerated from any checkout.
let outputPath = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()        // scripts/
    .deletingLastPathComponent()        // repo root
    .appendingPathComponent("App/Assets.xcassets/AppIcon.appiconset/icon.png")
    .path
let fileManager = FileManager.default

// Create directories if they don't exist
let dirPath = (outputPath as NSString).deletingLastPathComponent
do {
    try fileManager.createDirectory(atPath: dirPath, withIntermediateDirectories: true, attributes: nil)
} catch {
    print("Error creating directory: \(error)")
    exit(1)
}

// Save as PNG
let pngData = nsImage.tiffRepresentation.flatMap { tiffData in
    NSBitmapImageRep(data: tiffData)?.representation(using: .png, properties: [:])
}

if let data = pngData {
    do {
        try data.write(to: URL(fileURLWithPath: outputPath))
        print("Icon saved to \(outputPath) (1024x1024)")
    } catch {
        print("Error saving icon: \(error)")
        exit(1)
    }
} else {
    print("Error creating PNG representation")
    exit(1)
}
