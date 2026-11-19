// Draws the app icon: make-icon.swift <output.iconset> [preview.png]
//
// Siliconium's mark is a periodic-table tile: "Si", silicon's symbol, with its
// atomic number 14, on graphite with the faint grid of a silicon wafer. The
// symbol carries a cool iridescent gradient (the sheen of a polished wafer).
import AppKit
import CoreText

let out = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func textPath(_ string: String, font: CTFont) -> CGPath {
    let line = CTLineCreateWithAttributedString(
        NSAttributedString(string: string, attributes: [.font: font]))
    let path = CGMutablePath()
    for run in CTLineGetGlyphRuns(line) as! [CTRun] {
        let count = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: count)
        var positions = [CGPoint](repeating: .zero, count: count)
        CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
        CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
        for i in 0..<count {
            if let g = CTFontCreatePathForGlyph(font, glyphs[i], nil) {
                path.addPath(g, transform: CGAffineTransform(translationX: positions[i].x, y: positions[i].y))
            }
        }
    }
    return path
}

func draw(_ px: Int) -> Data {
    let s = CGFloat(px)
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // macOS icon grid: an 824/1024 squircle, centred
    let inset = s * 100 / 1024
    let rect = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let radius = rect.width * 0.2237
    let shape = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    // soft drop shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.012), blur: s * 0.03,
                  color: CGColor(gray: 0, alpha: 0.45))
    ctx.addPath(shape); ctx.setFillColor(CGColor(gray: 0.05, alpha: 1)); ctx.fillPath()
    ctx.restoreGState()

    // graphite body
    ctx.saveGState()
    ctx.addPath(shape); ctx.clip()
    let body = CGGradient(colorsSpace: cs, colors: [
        CGColor(red: 0.15, green: 0.16, blue: 0.19, alpha: 1),
        CGColor(red: 0.05, green: 0.055, blue: 0.07, alpha: 1)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(body, start: CGPoint(x: rect.minX, y: rect.maxY),
                           end: CGPoint(x: rect.maxX, y: rect.minY), options: [])
    // wafer grid (only where it can be seen)
    if px >= 128 {
        ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.045))
        ctx.setLineWidth(max(1, s / 1024))
        let step = rect.width / 12
        var x = rect.minX + step
        while x < rect.maxX - 1 { ctx.move(to: CGPoint(x: x, y: rect.minY)); ctx.addLine(to: CGPoint(x: x, y: rect.maxY)); x += step }
        var y = rect.minY + step
        while y < rect.maxY - 1 { ctx.move(to: CGPoint(x: rect.minX, y: y)); ctx.addLine(to: CGPoint(x: rect.maxX, y: y)); y += step }
        ctx.strokePath()
    }
    // a faint light from the top
    let glow = CGGradient(colorsSpace: cs, colors: [
        CGColor(gray: 1, alpha: 0.10), CGColor(gray: 1, alpha: 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: rect.midX, y: rect.maxY), startRadius: 0,
                           endCenter: CGPoint(x: rect.midX, y: rect.maxY), endRadius: rect.height * 0.8, options: [])
    ctx.restoreGState()

    // hairline rim
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: rect.insetBy(dx: s / 1024, dy: s / 1024),
                       cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.10)); ctx.setLineWidth(max(1, s * 2 / 1024)); ctx.strokePath()
    ctx.restoreGState()

    // "Si" with the wafer's iridescent sheen
    let symbolFont = NSFont.systemFont(ofSize: rect.width * 0.48, weight: .semibold) as CTFont
    let symbol = textPath("Si", font: symbolFont)
    let box = symbol.boundingBoxOfPath
    // the glyphs' ink centred in the tile, both ways
    let origin = CGPoint(x: rect.midX - box.width / 2 - box.minX,
                         y: rect.midY - box.height / 2 - box.minY)
    var move = CGAffineTransform(translationX: origin.x, y: origin.y)
    let placed = symbol.copy(using: &move)!
    ctx.saveGState()
    ctx.addPath(placed); ctx.clip()
    let sheen = CGGradient(colorsSpace: cs, colors: [
        CGColor(red: 0.62, green: 0.86, blue: 1.00, alpha: 1),
        CGColor(red: 0.74, green: 0.68, blue: 1.00, alpha: 1),
        CGColor(red: 0.95, green: 0.97, blue: 1.00, alpha: 1)] as CFArray, locations: [0, 0.55, 1])!
    let b = placed.boundingBoxOfPath
    ctx.drawLinearGradient(sheen, start: CGPoint(x: b.minX, y: b.minY), end: CGPoint(x: b.maxX, y: b.maxY), options: [])
    ctx.restoreGState()

    // atomic number, top left, where the tile can show it
    if px >= 64 {
        let numberFont = NSFont.monospacedDigitSystemFont(ofSize: rect.width * 0.095, weight: .medium) as CTFont
        let number = textPath("14", font: numberFont)
        var at = CGAffineTransform(translationX: rect.minX + rect.width * 0.14,
                                   y: rect.maxY - rect.height * 0.14 - number.boundingBoxOfPath.maxY)
        ctx.addPath(number.copy(using: &at)!)
        ctx.setFillColor(CGColor(gray: 1, alpha: 0.55)); ctx.fillPath()
    }

    let image = ctx.makeImage()!
    return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
}

for (name, px) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128),
                   ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)] {
    try! draw(px).write(to: out.appendingPathComponent("icon_\(name).png"))
}
if CommandLine.arguments.count > 2 {
    try! draw(1024).write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
}
