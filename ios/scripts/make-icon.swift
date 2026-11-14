// Draws the Ball Knowledge app icon with CoreGraphics and writes the three
// 1024 x 1024 PNGs the asset catalog expects (any, dark, tinted).
//
//   xcrun swift ios/scripts/make-icon.swift [output-folder]
//
// With no argument it writes into App/Resources/Assets.xcassets/AppIcon.appiconset
// next to this script's folder.
//
// The picture is the broadcast view of the brand: a chalk O (offense) and a
// chalk X (defense) facing each other across the blue line of scrimmage, with
// the yellow line to gain behind the defense, on turf. No text, no league or
// team marks.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct RGB {
    let r: CGFloat, g: CGFloat, b: CGFloat
    init(_ hex: UInt32) {
        r = CGFloat((hex >> 16) & 0xFF) / 255
        g = CGFloat((hex >> 8) & 0xFF) / 255
        b = CGFloat(hex & 0xFF) / 255
    }
    init(gray: CGFloat) { r = gray; g = gray; b = gray }
    func cg(_ alpha: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: r, green: g, blue: b, alpha: alpha)
    }
}

struct Palette {
    let turf: RGB        // field
    let band: RGB        // every other five-yard band
    let chalk: RGB       // the O, the X, the yard lines
    let scrimmage: RGB   // line of scrimmage
    let gain: RGB        // line to gain
    let well: RGB        // the darker inside of the O
    let yardLineAlpha: CGFloat
    let hashAlpha: CGFloat
    let wellAlpha: CGFloat
}

// The web page's own field colors (src/page.html, :root).
let light = Palette(
    turf: RGB(0x1D4634), band: RGB(0x21503B), chalk: RGB(0xF3F5EF),
    scrimmage: RGB(0x5E9DFF), gain: RGB(0xFFD84A), well: RGB(0x08140E),
    yardLineAlpha: 0.34, hashAlpha: 0.26, wellAlpha: 0.38)

// The same field under the lights off: darker turf, same paint.
let dark = Palette(
    turf: RGB(0x10271D), band: RGB(0x132E22), chalk: RGB(0xF3F5EF),
    scrimmage: RGB(0x5E9DFF), gain: RGB(0xFFD84A), well: RGB(0x040A07),
    yardLineAlpha: 0.28, hashAlpha: 0.24, wellAlpha: 0.45)

// Grayscale for the tinted home screen: the system colors it by brightness.
let tinted = Palette(
    turf: RGB(gray: 0.10), band: RGB(gray: 0.13), chalk: RGB(gray: 1.0),
    scrimmage: RGB(gray: 0.62), gain: RGB(gray: 0.86), well: RGB(gray: 0.0),
    yardLineAlpha: 0.24, hashAlpha: 0.20, wellAlpha: 0.45)

let side: CGFloat = 1024

// Layout, in pixels of the 1024 square. The field runs left to right, the way
// it does on television: the O five yards (one band) left of the line of
// scrimmage, the X five yards right of it, the line to gain ten yards on. A
// faint chalk line ten yards back mirrors it. Two rows of hash marks, one
// tick a yard, frame the marks the way the hashes frame the ball.
let bandWidth: CGFloat = 205
let scrimmageX: CGFloat = 512
let gainX: CGFloat = scrimmageX + 2 * bandWidth
let backX: CGFloat = scrimmageX - 2 * bandWidth
let markY: CGFloat = 512
let oCenterX: CGFloat = scrimmageX - bandWidth
let xCenterX: CGFloat = scrimmageX + bandWidth
let oRadius: CGFloat = 126      // to the middle of the stroke
let oStroke: CGFloat = 66
let xReach: CGFloat = 120       // half the X's width and height, to the stroke's end point
let xStroke: CGFloat = 70
let paintWidth: CGFloat = 32    // the blue and yellow lines
let backLineWidth: CGFloat = 12
let hashOffset: CGFloat = 318   // hash rows sit this far above and below the marks
let hashLength: CGFloat = 46
let hashWidth: CGFloat = 9

func draw(_ p: Palette) -> CGImage {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(
        data: nil, width: Int(side), height: Int(side), bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high

    // Turf, then every other ten-yard stretch a shade lighter. The seams sit under
    // the painted lines, so no seam crosses the O or the X.
    ctx.setFillColor(p.turf.cg())
    ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
    ctx.setFillColor(p.band.cg())
    ctx.fill(CGRect(x: backX, y: 0, width: scrimmageX - backX, height: side))
    ctx.fill(CGRect(x: gainX, y: 0, width: side - gainX, height: side))

    // Hash marks: a tick every yard (a fifth of a band), skipping the painted lines.
    ctx.setFillColor(p.chalk.cg(p.hashAlpha))
    let yard = bandWidth / 5
    for k in -12...12 {
        let x = scrimmageX + CGFloat(k) * yard
        if k % 10 == 0 { continue }
        for y in [markY - hashOffset, markY + hashOffset] {
            ctx.fill(CGRect(x: x - hashWidth / 2, y: y - hashLength / 2, width: hashWidth, height: hashLength))
        }
    }

    // The chalk line ten yards back, the line to gain, then the line of scrimmage.
    ctx.setFillColor(p.chalk.cg(p.yardLineAlpha))
    ctx.fill(CGRect(x: backX - backLineWidth / 2, y: 0, width: backLineWidth, height: side))
    ctx.setFillColor(p.gain.cg())
    ctx.fill(CGRect(x: gainX - paintWidth / 2, y: 0, width: paintWidth, height: side))
    ctx.setFillColor(p.scrimmage.cg())
    ctx.fill(CGRect(x: scrimmageX - paintWidth / 2, y: 0, width: paintWidth, height: side))

    // The O: a darker well with a chalk ring, as the web field draws an open offensive spot.
    let oRect = CGRect(x: oCenterX - oRadius, y: markY - oRadius, width: oRadius * 2, height: oRadius * 2)
    ctx.setFillColor(p.well.cg(p.wellAlpha))
    ctx.fillEllipse(in: oRect)
    ctx.setStrokeColor(p.chalk.cg())
    ctx.setLineWidth(oStroke)
    ctx.strokeEllipse(in: oRect)

    // The X: two chalk strokes with round ends.
    ctx.setLineCap(.round)
    ctx.setLineWidth(xStroke)
    ctx.move(to: CGPoint(x: xCenterX - xReach, y: markY - xReach))
    ctx.addLine(to: CGPoint(x: xCenterX + xReach, y: markY + xReach))
    ctx.move(to: CGPoint(x: xCenterX - xReach, y: markY + xReach))
    ctx.addLine(to: CGPoint(x: xCenterX + xReach, y: markY - xReach))
    ctx.strokePath()

    return ctx.makeImage()!
}

func write(_ image: CGImage, to url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("cannot create \(url.path)")
    }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { fatalError("cannot write \(url.path)") }
    print("wrote \(url.path)")
}

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let defaultOut = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("App/Resources/Assets.xcassets/AppIcon.appiconset")
let outDir = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    : defaultOut
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

write(draw(light), to: outDir.appendingPathComponent("AppIcon.png"))
write(draw(dark), to: outDir.appendingPathComponent("AppIcon-Dark.png"))
write(draw(tinted), to: outDir.appendingPathComponent("AppIcon-Tinted.png"))
