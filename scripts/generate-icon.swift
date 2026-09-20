#!/usr/bin/env swift
// Generates a placeholder AppIcon.icns for RecordIt.
// Runs as part of package-release.sh.

import AppKit
import Foundation

let rootDir = URL(fileURLWithPath: ProcessInfo.processInfo.environment["ROOT_DIR"]
    ?? FileManager.default.currentDirectoryPath)
let iconsetDir = rootDir.appendingPathComponent("packaging/AppIcon.iconset", isDirectory: true)
let icnsPath = rootDir.appendingPathComponent("packaging/AppIcon.icns")

try? FileManager.default.removeItem(at: iconsetDir)
try FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

func renderIcon(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let bgRect = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.systemGray.setFill()
    NSBezierPath(roundedRect: bgRect, xRadius: CGFloat(size) * 0.22, yRadius: CGFloat(size) * 0.22).fill()

    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: CGFloat(size) * 0.5, weight: .semibold),
        .foregroundColor: NSColor.white,
    ]
    let text = "R" as NSString
    let textSize = text.size(withAttributes: attrs)
    let textRect = NSRect(
        x: (CGFloat(size) - textSize.width) / 2,
        y: (CGFloat(size) - textSize.height) / 2,
        width: textSize.width,
        height: textSize.height
    )
    text.draw(in: textRect, withAttributes: attrs)

    image.unlockFocus()
    return image
}

for size in [16, 32, 64, 128, 256, 512, 1024] {
    let icon = renderIcon(size: size)
    let tiff = icon.tiffRepresentation!
    let rep = NSBitmapImageRep(data: tiff)!
    let png = rep.representation(using: .png, properties: [:])!
    let name = size <= 512 ? "icon_\(size)x\(size).png" : "icon_\(size / 2)x\(size / 2)@2x.png"
    try png.write(to: iconsetDir.appendingPathComponent(name))
}

let task = Process()
task.launchPath = "/usr/bin/iconutil"
task.arguments = ["-c", "icns", iconsetDir.path, "-o", icnsPath.path]
try task.run()
task.waitUntilExit()

try? FileManager.default.removeItem(at: iconsetDir)

if task.terminationStatus == 0 {
    print("Generated AppIcon.icns")
} else {
    print("iconutil failed with status \(task.terminationStatus)")
    exit(task.terminationStatus)
}
