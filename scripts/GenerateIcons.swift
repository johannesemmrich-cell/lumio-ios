#!/usr/bin/swift
// Run from project root: swift scripts/GenerateIcons.swift
import Foundation
import CoreGraphics
import ImageIO

let SIZE: Int = 1024
let F = CGFloat(SIZE)

func makeContext() -> CGContext {
    CGContext(data: nil, width: SIZE, height: SIZE,
              bitsPerComponent: 8, bytesPerRow: 0,
              space: CGColorSpaceCreateDeviceRGB(),
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

func cgColor(r: CGFloat, g: CGFloat, b: CGFloat) -> CGColor {
    CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [r, g, b, 1.0])!
}

func fromHex(_ hex: UInt32) -> CGColor {
    cgColor(r: CGFloat((hex >> 16) & 0xFF) / 255.0,
            g: CGFloat((hex >> 8)  & 0xFF) / 255.0,
            b: CGFloat(hex         & 0xFF) / 255.0)
}

func fillGradient(_ ctx: CGContext, top: CGColor, bottom: CGColor) {
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [top, bottom] as CFArray,
        locations: [0.0, 1.0])!
    // y=F is top in CG (y-up), y=0 is bottom
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: F/2, y: F),
                           end:   CGPoint(x: F/2, y: 0),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

let white = cgColor(r: 1, g: 1, b: 1)

// MARK: — Sun symbol
func drawSun(_ ctx: CGContext) {
    let cx = F / 2, cy = F / 2
    let coreR: CGFloat   = 158
    let rayInner: CGFloat = 192
    let rayOuter: CGFloat = 314
    let rayH: CGFloat     = 20

    ctx.setFillColor(white)

    // Central circle
    ctx.fillEllipse(in: CGRect(x: cx - coreR, y: cy - coreR, width: coreR * 2, height: coreR * 2))

    // 8 rounded rays
    for i in 0..<8 {
        let angle = CGFloat(i) * .pi / 4.0
        ctx.saveGState()
        ctx.translateBy(x: cx, y: cy)
        ctx.rotate(by: angle)
        let ray = CGPath(roundedRect: CGRect(x: rayInner, y: -rayH / 2,
                                             width: rayOuter - rayInner, height: rayH),
                         cornerWidth: rayH / 2, cornerHeight: rayH / 2, transform: nil)
        ctx.addPath(ray)
        ctx.fillPath()
        ctx.restoreGState()
    }
}

// MARK: — Moon + stars symbol
func drawMoon(_ ctx: CGContext) {
    let cx: CGFloat = 450, cy: CGFloat = 470
    let moonR: CGFloat = 210
    let cutR: CGFloat  = 192
    let cutDX: CGFloat = 100  // offset right
    let cutDY: CGFloat = 80   // offset up (CG y-up)

    ctx.setFillColor(white)
    // Even-odd crescent: subtract the cut circle from the moon circle
    ctx.addEllipse(in: CGRect(x: cx - moonR, y: cy - moonR, width: moonR * 2, height: moonR * 2))
    ctx.addEllipse(in: CGRect(x: cx - cutR + cutDX, y: cy - cutR + cutDY, width: cutR * 2, height: cutR * 2))
    ctx.fillPath(using: .evenOdd)

    // Stars (x, y, radius) — in CG coords (y-up)
    let stars: [(CGFloat, CGFloat, CGFloat)] = [
        (680, 710, 11), (740, 610, 7), (660, 760, 8), (720, 670, 5), (770, 690, 6)
    ]
    for (x, y, r) in stars {
        ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }
}

// MARK: — Save PNG
func savePNG(_ ctx: CGContext, to path: String) {
    guard let image = ctx.makeImage() else { print("❌ makeImage failed: \(path)"); return }
    let url = URL(fileURLWithPath: path)
    do {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
    } catch { print("❌ mkdir: \(error)") }
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        print("❌ CGImageDestination failed: \(path)"); return
    }
    CGImageDestinationAddImage(dest, image, nil)
    if CGImageDestinationFinalize(dest) {
        print("✓ \(path)")
    } else {
        print("❌ Finalize failed: \(path)")
    }
}

// MARK: — Icon definitions
struct IconSpec {
    let name: String
    let topHex: UInt32
    let bottomHex: UInt32
    let style: String  // "sun" or "moon"
}

let specs: [IconSpec] = [
    IconSpec(name: "AppIcon",          topHex: 0xFF9500, bottomHex: 0xFF3B30, style: "sun"),   // Golden sunrise
    IconSpec(name: "AppIcon-Dawn",     topHex: 0xFF2D78, bottomHex: 0xFF9A3C, style: "sun"),   // Rose / coral
    IconSpec(name: "AppIcon-Midnight", topHex: 0x0D1B2A, bottomHex: 0x1A237E, style: "moon"),  // Navy / indigo
    IconSpec(name: "AppIcon-Forest",   topHex: 0x1B5E20, bottomHex: 0x43A047, style: "sun"),   // Deep forest green
    IconSpec(name: "AppIcon-Ocean",    topHex: 0x01579B, bottomHex: 0x039BE5, style: "sun"),   // Ocean blue
]

let base = "Sunwake/Resources/Assets.xcassets"

for spec in specs {
    let ctx = makeContext()
    fillGradient(ctx, top: fromHex(spec.topHex), bottom: fromHex(spec.bottomHex))
    if spec.style == "sun" { drawSun(ctx) } else { drawMoon(ctx) }

    let dir = "\(base)/\(spec.name).appiconset"
    savePNG(ctx, to: "\(dir)/\(spec.name)-1024.png")
}

print("\nAll \(specs.count) icons generated.")
