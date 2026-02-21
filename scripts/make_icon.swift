#!/usr/bin/swift
import AppKit
import Foundation

let fm = FileManager.default
let iconPath = "dist/AppIcon.png"
try fm.createDirectory(atPath: "dist", withIntermediateDirectories: true)
guard let image = drawIcon(size: 1024) else {
    fputs("failed to draw icon\n", stderr)
    exit(1)
}
try save(image: image, to: iconPath)
print("Created \(iconPath)")

func drawIcon(size: CGFloat) -> NSImage? {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { return nil }
    let rect = CGRect(x: 0, y: 0, width: size, height: size)

    let bg = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor(calibratedRed: 0.02, green: 0.02, blue: 0.03, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.12, alpha: 1).cgColor
        ] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])

    let halo = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor(calibratedRed: 0.95, green: 0.97, blue: 1.0, alpha: 0.28).cgColor,
            NSColor(calibratedRed: 0.1, green: 0.12, blue: 0.16, alpha: 0.0).cgColor
        ] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawRadialGradient(
        halo,
        startCenter: p(size, 0.5, 0.74),
        startRadius: size * 0.02,
        endCenter: p(size, 0.5, 0.74),
        endRadius: size * 0.56,
        options: []
    )

    let frame = rect.insetBy(dx: size * 0.036, dy: size * 0.036)
    ctx.setStrokeColor(NSColor(white: 1, alpha: 0.12).cgColor)
    ctx.setLineWidth(size * 0.008)
    ctx.stroke(frame, width: size * 0.008)

    let outline = elephantOutline(size: size)
    ctx.saveGState()
    ctx.addPath(outline)
    ctx.clip()

    let bodyGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor(white: 0.88, alpha: 1).cgColor,
            NSColor(white: 0.58, alpha: 1).cgColor,
            NSColor(white: 0.32, alpha: 1).cgColor
        ] as CFArray,
        locations: [0, 0.46, 1]
    )!
    ctx.drawLinearGradient(bodyGradient, start: p(size, 0.5, 0.8), end: p(size, 0.5, 0.08), options: [])

    let facets = elephantIconFacets(size: size)
    let shades: [CGFloat] = [0.76, 0.68, 0.62, 0.55, 0.48]
    for (i, facet) in facets.enumerated() {
        let shade = shades[i % shades.count]
        ctx.setFillColor(NSColor(white: shade, alpha: 0.42).cgColor)
        ctx.addPath(facet)
        ctx.fillPath()
        ctx.setStrokeColor(NSColor(white: 1, alpha: 0.18).cgColor)
        ctx.setLineWidth(size * 0.0028)
        ctx.addPath(facet)
        ctx.strokePath()
    }
    ctx.restoreGState()

    ctx.setStrokeColor(NSColor(white: 1, alpha: 0.66).cgColor)
    ctx.setLineWidth(size * 0.007)
    ctx.addPath(outline)
    ctx.strokePath()

    let leftTusk = polygonPath([
        p(size, 0.445, 0.43),
        p(size, 0.33, 0.29),
        p(size, 0.39, 0.24),
        p(size, 0.47, 0.35)
    ])
    let rightTusk = polygonPath([
        p(size, 0.555, 0.43),
        p(size, 0.67, 0.29),
        p(size, 0.61, 0.24),
        p(size, 0.53, 0.35)
    ])
    for tusk in [leftTusk, rightTusk] {
        ctx.setFillColor(NSColor(white: 0.98, alpha: 0.95).cgColor)
        ctx.addPath(tusk)
        ctx.fillPath()
        ctx.setStrokeColor(NSColor(white: 0, alpha: 0.22).cgColor)
        ctx.setLineWidth(size * 0.003)
        ctx.addPath(tusk)
        ctx.strokePath()
    }

    ctx.setStrokeColor(NSColor(white: 1, alpha: 0.42).cgColor)
    ctx.setLineWidth(size * 0.009)
    ctx.setLineCap(.round)
    ctx.addPath(quad(start: p(size, 0.5, 0.57), control: p(size, 0.53, 0.34), end: p(size, 0.5, 0.09)))
    ctx.strokePath()

    let eyeL = polygon(center: p(size, 0.375, 0.57), radius: size * 0.028, sides: 6, rotation: .pi / 6)
    let eyeR = polygon(center: p(size, 0.625, 0.57), radius: size * 0.028, sides: 6, rotation: .pi / 6)
    for eye in [eyeL, eyeR] {
        ctx.setFillColor(NSColor(white: 0.03, alpha: 0.96).cgColor)
        ctx.addPath(eye)
        ctx.fillPath()
        ctx.setStrokeColor(NSColor(white: 1, alpha: 0.45).cgColor)
        ctx.setLineWidth(size * 0.0035)
        ctx.addPath(eye)
        ctx.strokePath()
    }

    image.unlockFocus()
    return image
}

func elephantOutline(size: CGFloat) -> CGPath {
    let points: [CGPoint] = [
        p(size, 0.35, 0.63), p(size, 0.2, 0.75), p(size, 0.08, 0.7), p(size, 0.04, 0.54),
        p(size, 0.1, 0.38), p(size, 0.22, 0.29), p(size, 0.35, 0.31), p(size, 0.42, 0.41),
        p(size, 0.45, 0.29), p(size, 0.42, 0.16), p(size, 0.38, 0.08), p(size, 0.5, 0.05),
        p(size, 0.62, 0.08), p(size, 0.58, 0.16), p(size, 0.55, 0.29), p(size, 0.58, 0.41),
        p(size, 0.65, 0.31), p(size, 0.78, 0.29), p(size, 0.9, 0.38), p(size, 0.96, 0.54),
        p(size, 0.92, 0.7), p(size, 0.8, 0.75), p(size, 0.65, 0.63), p(size, 0.5, 0.8)
    ]
    return polygonPath(points)
}

func elephantIconFacets(size: CGFloat) -> [CGPath] {
    let pts = [
        p(size, 0.5, 0.8),   // 0 crown
        p(size, 0.35, 0.63), // 1 foreheadL
        p(size, 0.65, 0.63), // 2 foreheadR
        p(size, 0.2, 0.75),  // 3 earTopInL
        p(size, 0.08, 0.7),  // 4 earTopOutL
        p(size, 0.04, 0.54), // 5 earMidL
        p(size, 0.1, 0.38),  // 6 earLowL
        p(size, 0.22, 0.29), // 7 earInLowL
        p(size, 0.35, 0.31), // 8 cheekL
        p(size, 0.42, 0.41), // 9 rootL
        p(size, 0.58, 0.41), // 10 rootR
        p(size, 0.65, 0.31), // 11 cheekR
        p(size, 0.78, 0.29), // 12 earInLowR
        p(size, 0.9, 0.38),  // 13 earLowR
        p(size, 0.96, 0.54), // 14 earMidR
        p(size, 0.92, 0.7),  // 15 earTopOutR
        p(size, 0.8, 0.75),  // 16 earTopInR
        p(size, 0.45, 0.29), // 17 trunkMidL
        p(size, 0.42, 0.16), // 18 trunkLowL
        p(size, 0.38, 0.08), // 19 tipL
        p(size, 0.5, 0.05),  // 20 tipM
        p(size, 0.62, 0.08), // 21 tipR
        p(size, 0.58, 0.16), // 22 trunkLowR
        p(size, 0.55, 0.29)  // 23 trunkMidR
    ]

    let tri: [[Int]] = [
        [0, 1, 2],
        [0, 3, 1], [3, 4, 1], [4, 5, 1], [5, 6, 8], [6, 7, 8], [1, 5, 8], [1, 8, 9],
        [0, 2, 16], [16, 15, 2], [15, 14, 2], [14, 13, 11], [13, 12, 11], [2, 14, 11], [2, 11, 10],
        [9, 10, 17], [10, 23, 17], [8, 9, 17], [11, 23, 10],
        [17, 18, 23], [18, 22, 23], [18, 19, 22], [19, 20, 21], [18, 19, 21], [18, 21, 22]
    ]

    return tri.map { t in
        polygonPath([pts[t[0]], pts[t[1]], pts[t[2]]])
    }
}

func polygonPath(_ points: [CGPoint]) -> CGPath {
    let path = CGMutablePath()
    guard let first = points.first else { return path }
    path.move(to: first)
    for point in points.dropFirst() {
        path.addLine(to: point)
    }
    path.closeSubpath()
    return path
}

func quad(start: CGPoint, control: CGPoint, end: CGPoint) -> CGPath {
    let path = CGMutablePath()
    path.move(to: start)
    path.addQuadCurve(to: end, control: control)
    return path
}

func polygon(center: CGPoint, radius: CGFloat, sides: Int, rotation: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let n = max(3, sides)
    for i in 0..<n {
        let a = rotation + CGFloat(i) / CGFloat(n) * .pi * 2
        let pt = CGPoint(x: center.x + cos(a) * radius, y: center.y + sin(a) * radius)
        if i == 0 {
            path.move(to: pt)
        } else {
            path.addLine(to: pt)
        }
    }
    path.closeSubpath()
    return path
}

func p(_ size: CGFloat, _ x: CGFloat, _ y: CGFloat) -> CGPoint {
    CGPoint(x: size * x, y: size * y)
}

func save(image: NSImage, to path: String) throws {
    guard
        let tiff = image.tiffRepresentation,
        let rep = NSBitmapImageRep(data: tiff),
        let data = rep.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "icon", code: 1, userInfo: nil)
    }
    try data.write(to: URL(fileURLWithPath: path))
}
