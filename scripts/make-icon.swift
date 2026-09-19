import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let sizes = [(16, "16x16"), (32, "16x16@2x"), (32, "32x32"), (64, "32x32@2x"), (128, "128x128"), (256, "128x128@2x"), (256, "256x256"), (512, "256x256@2x"), (512, "512x512"), (1024, "512x512@2x")]
for (pixels, name) in sizes {
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                       bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                       isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let context = NSGraphicsContext(bitmapImageRep: bitmap) else { fatalError("无法创建图像上下文") }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let scale = CGFloat(pixels) / 1024
    let transform = NSAffineTransform()
    transform.scale(by: scale)
    transform.concat()
    NSColor(calibratedRed: 0.12, green: 0.38, blue: 0.29, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 70, y: 70, width: 884, height: 884), xRadius: 200, yRadius: 200).fill()
    let leaf = NSBezierPath()
    leaf.move(to: NSPoint(x: 290, y: 290))
    leaf.curve(to: NSPoint(x: 772, y: 774), controlPoint1: NSPoint(x: 215, y: 570), controlPoint2: NSPoint(x: 450, y: 820))
    leaf.curve(to: NSPoint(x: 290, y: 290), controlPoint1: NSPoint(x: 832, y: 465), controlPoint2: NSPoint(x: 580, y: 242))
    NSColor(calibratedRed: 0.79, green: 0.92, blue: 0.65, alpha: 1).setFill()
    leaf.fill()
    let stem = NSBezierPath()
    stem.move(to: NSPoint(x: 240, y: 242))
    stem.line(to: NSPoint(x: 640, y: 640))
    stem.lineWidth = 44
    stem.lineCapStyle = .round
    NSColor.white.setStroke()
    stem.stroke()
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("无法生成图标")
    }
    try png.write(to: output.appendingPathComponent("icon_\(name).png"))
}
