import AppKit

// Get the desktop path and load the lettuce image
let desktopPath = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
let lettucePath = desktopPath.appendingPathComponent("lettuce.png")

guard let lettuceImage = NSImage(contentsOf: lettucePath) else {
    print("Error: Could not load lettuce.png from desktop")
    exit(1)
}

// Create a 1024x1024 bitmap representation
let size = CGSize(width: 1024, height: 1024)
guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
                             pixelsWide: Int(size.width),
                             pixelsHigh: Int(size.height),
                             bitsPerSample: 8,
                             samplesPerPixel: 4,
                             hasAlpha: true,
                             isPlanar: false,
                             colorSpaceName: .deviceRGB,
                             bytesPerRow: 0,
                             bitsPerPixel: 0) else {
    print("Error: Could not create bitmap representation")
    exit(1)
}

// Set up graphics context
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

// Draw background
NSColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0).setFill()
NSRect(origin: .zero, size: size).fill()

// Calculate scaling to fit the lettuce image while maintaining aspect ratio
let lettuceSize = lettuceImage.size
let scale = min(size.width / lettuceSize.width, size.height / lettuceSize.height)
let scaledSize = CGSize(width: lettuceSize.width * scale, height: lettuceSize.height * scale)
let x = (size.width - scaledSize.width) / 2
let y = (size.height - scaledSize.height) / 2

// Draw the lettuce image centered
lettuceImage.draw(in: NSRect(x: x, y: y, width: scaledSize.width, height: scaledSize.height),
                 from: NSRect(origin: .zero, size: lettuceImage.size),
                 operation: .sourceOver,
                 fraction: 1.0)

// Restore graphics state
NSGraphicsContext.restoreGraphicsState()

// Save as PNG
if let pngData = bitmap.representation(using: .png, properties: [:]) {
    let fileManager = FileManager.default
    let currentDirectory = fileManager.currentDirectoryPath
    let iconPath = "\(currentDirectory)/Image2List/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
    
    do {
        try pngData.write(to: URL(fileURLWithPath: iconPath))
        // Set file permissions to 644
        try fileManager.setAttributes([.posixPermissions: 0o644], ofItemAtPath: iconPath)
        print("Icon saved to: \(iconPath)")
        print("File size: \(pngData.count) bytes")
        
        // Verify image dimensions
        if let savedImage = NSImage(contentsOfFile: iconPath) {
            print("Image dimensions: \(savedImage.size.width)x\(savedImage.size.height)")
        }
    } catch {
        print("Error saving icon: \(error)")
    }
} else {
    print("Failed to create PNG data")
} 