// AppIconGenerator.swift — renders the Labelscope app icon (light / dark / tinted variants)
// as 1024x1024 PNGs with CoreGraphics, so the icon can be tweaked in code and regenerated.
//
// Regenerate (from the repo root):
//   swiftc -O Design/AppIconGenerator.swift -o /tmp/icongen && /tmp/icongen AllergyScanner/Assets.xcassets/AppIcon.appiconset
//
// This file is NOT part of the Xcode target (it lives outside the AllergyScanner/ folder
// that the target syncs), so it never ships in the app.

import AppKit
import CoreGraphics

let S: CGFloat = 1024

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: a)
}
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
func gradient(_ stops: [(CGColor, CGFloat)]) -> CGGradient {
    CGGradient(colorsSpace: cs, colors: stops.map(\.0) as CFArray, locations: stops.map(\.1))!
}

enum Variant { case light, dark, tinted }

func render(_ v: Variant, to path: String) {
    let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                        space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // Top-left origin, like every design tool.
    ctx.translateBy(x: 0, y: S); ctx.scaleBy(x: 1, y: -1)
    // CG shadow offsets are in the un-flipped space, so negate y to get "down".
    func shadow(_ dy: CGFloat, _ blur: CGFloat, _ color: CGColor) {
        ctx.setShadow(offset: CGSize(width: 0, height: -dy), blur: blur, color: color)
    }

    // ---------- Background: blue gradient, light bloom top-left ----------
    let bg: CGGradient
    switch v {
    case .light:  bg = gradient([(rgb(0x6A8CF7), 0), (rgb(0x4A5FE6), 0.5), (rgb(0x3A3BCF), 1)])
    case .dark:   bg = gradient([(rgb(0x2C3A7A), 0), (rgb(0x1B2158), 0.55), (rgb(0x0E1036), 1)])
    case .tinted: bg = gradient([(rgb(0x3C3C3C), 0), (rgb(0x202020), 0.55), (rgb(0x0B0B0B), 1)])
    }
    ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: 0), end: CGPoint(x: S, y: S), options: [])
    let bloom = gradient([(rgb(0xFFFFFF, 0.18), 0), (rgb(0xFFFFFF, 0), 1)])
    ctx.drawRadialGradient(bloom, startCenter: CGPoint(x: 300, y: 220), startRadius: 0,
                           endCenter: CGPoint(x: 300, y: 220), endRadius: 700, options: [])

    // ---------- Magnifying glass ----------
    let lensC = CGPoint(x: 470, y: 440)
    let lensR: CGFloat = 282           // glass radius
    let bezelW: CGFloat = 16           // light inner bevel between glass and dark ring
    let ringW: CGFloat = 64            // dark ring
    let bezelR = lensR + bezelW
    let outerR = bezelR + ringW
    func circle(_ r: CGFloat) -> CGRect { CGRect(x: lensC.x - r, y: lensC.y - r, width: r * 2, height: r * 2) }

    // Handle (drawn first so the ring sits on top of it).
    let angle: CGFloat = 45 * .pi / 180
    let handleLen: CGFloat = 300, handleW: CGFloat = 140
    ctx.saveGState()
    ctx.translateBy(x: lensC.x, y: lensC.y); ctx.rotate(by: angle)
    let handleRect = CGRect(x: outerR - 40, y: -handleW / 2, width: handleLen, height: handleW)
    let handlePath = CGPath(roundedRect: handleRect, cornerWidth: handleW / 2, cornerHeight: handleW / 2, transform: nil)
    ctx.saveGState(); shadow(30, 50, rgb(0x000000, 0.45))
    ctx.setFillColor(rgb(0x1B1F3F)); ctx.addPath(handlePath); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState(); ctx.addPath(handlePath); ctx.clip()
    let handleG = v == .tinted ? gradient([(rgb(0x7A7A7A), 0), (rgb(0x303030), 0.55), (rgb(0x121212), 1)])
                               : gradient([(rgb(0x4E5486), 0), (rgb(0x262B55), 0.55), (rgb(0x12142F), 1)])
    ctx.drawLinearGradient(handleG, start: CGPoint(x: 0, y: -handleW / 2), end: CGPoint(x: 0, y: handleW / 2), options: [])
    ctx.setFillColor(rgb(0xFFFFFF, 0.20))   // specular stripe
    ctx.addPath(CGPath(roundedRect: CGRect(x: outerR + 20, y: -handleW / 2 + 14, width: handleLen - 90, height: 16),
                       cornerWidth: 8, cornerHeight: 8, transform: nil)); ctx.fillPath()
    ctx.restoreGState()
    // Collar where the handle meets the ring.
    let collar = CGRect(x: outerR - 34, y: -handleW / 2 - 8, width: 48, height: handleW + 16)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: collar, cornerWidth: 14, cornerHeight: 14, transform: nil)); ctx.clip()
    let collarG = v == .tinted ? gradient([(rgb(0xDADADA), 0), (rgb(0x7C7C7C), 1)])
                               : gradient([(rgb(0xD9DEF2), 0), (rgb(0x7F88AE), 1)])
    ctx.drawLinearGradient(collarG, start: CGPoint(x: 0, y: collar.minY), end: CGPoint(x: 0, y: collar.maxY), options: [])
    ctx.restoreGState()
    ctx.restoreGState()

    // Drop shadow of the whole head onto the background.
    ctx.saveGState(); shadow(36, 64, rgb(0x000000, 0.45))
    ctx.setFillColor(rgb(0x20232E)); ctx.addEllipse(in: circle(outerR)); ctx.fillPath()
    ctx.restoreGState()

    // Dark ring: charcoal with a top-left sheen.
    ctx.saveGState()
    let ringPath = CGMutablePath(); ringPath.addEllipse(in: circle(outerR)); ringPath.addEllipse(in: circle(bezelR))
    ctx.addPath(ringPath); ctx.clip(using: .evenOdd)
    let ringG = gradient([(rgb(0x6B7184), 0), (rgb(0x3A3F4E), 0.35), (rgb(0x1E212B), 0.75), (rgb(0x2E3240), 1)])
    ctx.drawLinearGradient(ringG, start: CGPoint(x: lensC.x - outerR, y: lensC.y - outerR),
                           end: CGPoint(x: lensC.x + outerR, y: lensC.y + outerR), options: [])
    ctx.restoreGState()
    // Outer rim highlight + dark outline for crispness.
    ctx.setStrokeColor(rgb(0xFFFFFF, 0.35)); ctx.setLineWidth(5)
    ctx.addEllipse(in: circle(outerR - 4)); ctx.strokePath()
    ctx.setStrokeColor(rgb(0x0E1018, 0.6)); ctx.setLineWidth(3)
    ctx.addEllipse(in: circle(outerR - 1)); ctx.strokePath()

    // Light bevel between the ring and the glass.
    ctx.saveGState()
    let bezelPath = CGMutablePath(); bezelPath.addEllipse(in: circle(bezelR)); bezelPath.addEllipse(in: circle(lensR))
    ctx.addPath(bezelPath); ctx.clip(using: .evenOdd)
    let bezelG = gradient([(rgb(0xF6F7FB), 0), (rgb(0xC3C8DA), 0.5), (rgb(0x8E95AD), 1)])
    ctx.drawLinearGradient(bezelG, start: CGPoint(x: lensC.x - bezelR, y: lensC.y - bezelR),
                           end: CGPoint(x: lensC.x + bezelR, y: lensC.y + bezelR), options: [])
    ctx.restoreGState()

    // Glass: white with a faint cool tint at the bottom, and the label lines inside.
    ctx.saveGState(); ctx.addEllipse(in: circle(lensR)); ctx.clip()
    let glassBase = v == .tinted ? gradient([(rgb(0xFFFFFF), 0), (rgb(0xE4E4E4), 1)])
                                 : gradient([(rgb(0xFFFFFF), 0), (rgb(0xE6EAFB), 1)])
    ctx.drawLinearGradient(glassBase, start: CGPoint(x: 0, y: lensC.y - lensR), end: CGPoint(x: 0, y: lensC.y + lensR), options: [])

    let lineColor = v == .tinted ? rgb(0x9C9C9C) : rgb(0xB9C0DE)
    let hit = v == .tinted ? rgb(0x2A2A2A) : rgb(0xE5484D)
    let h: CGFloat = 54
    // (centre-y offset, x start, width) — the middle one is the matched word.
    let rows: [(CGFloat, CGFloat, CGFloat)] = [
        (-208, -166, 332), (-104, -236, 344), (0, -210, 420), (104, -196, 390), (208, -140, 280)
    ]
    for (i, row) in rows.enumerated() {
        let r = CGRect(x: lensC.x + row.1, y: lensC.y + row.0 - h / 2, width: row.2, height: h)
        if i == 2 {
            ctx.setFillColor(hit)
            ctx.addPath(CGPath(roundedRect: r, cornerWidth: h / 2, cornerHeight: h / 2, transform: nil)); ctx.fillPath()
            let frame = r.insetBy(dx: -28, dy: -26)
            ctx.setStrokeColor(hit); ctx.setLineWidth(13)
            ctx.addPath(CGPath(roundedRect: frame, cornerWidth: 36, cornerHeight: 36, transform: nil)); ctx.strokePath()
        } else {
            ctx.setFillColor(lineColor)
            ctx.addPath(CGPath(roundedRect: r, cornerWidth: h / 2, cornerHeight: h / 2, transform: nil)); ctx.fillPath()
        }
    }
    // Lens edge darkening + a soft specular crescent top-left.
    let edge = gradient([(rgb(0x2A2F55, 0), 0.8), (rgb(0x2A2F55, 0.18), 1)])
    ctx.drawRadialGradient(edge, startCenter: lensC, startRadius: 0, endCenter: lensC, endRadius: lensR, options: [])
    ctx.saveGState()
    ctx.translateBy(x: lensC.x - 110, y: lensC.y - 150); ctx.rotate(by: -35 * .pi / 180)
    ctx.addEllipse(in: CGRect(x: -110, y: -40, width: 220, height: 80)); ctx.clip()
    let spec = gradient([(rgb(0xFFFFFF, 0.9), 0), (rgb(0xFFFFFF, 0), 1)])
    ctx.drawLinearGradient(spec, start: CGPoint(x: 0, y: -34), end: CGPoint(x: 0, y: 34), options: [])
    ctx.restoreGState()
    ctx.restoreGState()

    let img = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: img)
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: path))
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
render(.light, to: "\(out)/AppIcon.png")
render(.dark, to: "\(out)/AppIcon-Dark.png")
render(.tinted, to: "\(out)/AppIcon-Tinted.png")
print("rendered")
