import AppKit

let destination = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "FinderGitHelper/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
var images = [[String: String]]()
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { fatalError("Could not create icon bitmap") }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        let unit = CGFloat(pixels) / 1024
        let transform = NSAffineTransform()
        transform.scale(by: unit)
        transform.concat()
        NSColor(calibratedRed: 0.08, green: 0.20, blue: 0.24, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 60, y: 60, width: 904, height: 904), xRadius: 200, yRadius: 200).fill()
        NSColor(calibratedRed: 0.55, green: 0.94, blue: 0.77, alpha: 1).setStroke()
        let prompt = NSBezierPath()
        prompt.lineWidth = 64
        prompt.lineCapStyle = .round
        prompt.lineJoinStyle = .round
        prompt.move(to: NSPoint(x: 260, y: 650))
        prompt.line(to: NSPoint(x: 430, y: 512))
        prompt.line(to: NSPoint(x: 260, y: 374))
        prompt.move(to: NSPoint(x: 535, y: 374))
        prompt.line(to: NSPoint(x: 760, y: 374))
        prompt.stroke()
        NSGraphicsContext.restoreGraphicsState()
        guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Could not encode icon") }
        let name = "icon-\(size)@\(scale)x.png"
        try png.write(to: destination.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(size)x\(size)", "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys]).write(to: destination.appendingPathComponent("Contents.json"))
