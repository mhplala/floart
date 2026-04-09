#!/usr/bin/env swift
// CursorInsight App Icon Generator
// Draws a 1024x1024 icon: gradient background, stylized eye with cursor overlay

import AppKit
import CoreGraphics

let size = 1024
let projectDir: String = {
    let scriptPath = CommandLine.arguments[0]
    let url = URL(fileURLWithPath: scriptPath)
    // Go up: script -> scripts -> project
    return url.deletingLastPathComponent().deletingLastPathComponent().path
}()
let buildDir = projectDir + "/build"
let iconsetDir = buildDir + "/CursorInsight.iconset"
let outputPNG = buildDir + "/icon_1024.png"
let outputICNS = buildDir + "/CursorInsight.icns"

// MARK: - Drawing

func drawIcon(in context: CGContext, size: CGFloat) {
    let s = size

    // --- Background: rounded rect with gradient ---
    let cornerRadius = s * 0.22
    let bgRect = CGRect(x: 0, y: 0, width: s, height: s)
    let path = CGPath(roundedRect: bgRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    context.addPath(path)
    context.clip()

    // Gradient: deep purple (#6B2FA0) -> blue (#2D7DD2), top-left to bottom-right
    let colors = [
        CGColor(red: 0.42, green: 0.184, blue: 0.627, alpha: 1.0),  // #6B2FA0
        CGColor(red: 0.176, green: 0.49, blue: 0.824, alpha: 1.0),  // #2D7DD2
    ]
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0.0, 1.0])!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: s),
        end: CGPoint(x: s, y: 0),
        options: []
    )
    context.resetClip()

    // Re-clip to rounded rect for all subsequent drawing
    context.addPath(path)
    context.clip()

    // --- Stylized Eye (large, centered, representing "insight") ---
    // Eye outline: almond/vesica shape centered at (s*0.5, s*0.48)
    let cx = s * 0.5
    let cy = s * 0.48
    let eyeW = s * 0.54   // half-width of eye
    let eyeH = s * 0.30   // half-height of eye

    // Draw subtle glow behind eye
    let glowColors = [
        CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.18),
        CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.0),
    ]
    let glowGradient = CGGradient(colorsSpace: colorSpace, colors: glowColors as CFArray, locations: [0.0, 1.0])!
    context.saveGState()
    context.drawRadialGradient(
        glowGradient,
        startCenter: CGPoint(x: cx, y: cy), startRadius: 0,
        endCenter: CGPoint(x: cx, y: cy), endRadius: eyeW * 0.85,
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )
    context.restoreGState()

    // Build eye path (almond shape using two arcs)
    let eyePath = CGMutablePath()
    // Left tip
    eyePath.move(to: CGPoint(x: cx - eyeW, y: cy))
    // Top arc from left to right tip
    eyePath.addCurve(
        to: CGPoint(x: cx + eyeW, y: cy),
        control1: CGPoint(x: cx - eyeW * 0.3, y: cy + eyeH),
        control2: CGPoint(x: cx + eyeW * 0.3, y: cy + eyeH)
    )
    // Bottom arc from right to left tip
    eyePath.addCurve(
        to: CGPoint(x: cx - eyeW, y: cy),
        control1: CGPoint(x: cx + eyeW * 0.3, y: cy - eyeH),
        control2: CGPoint(x: cx - eyeW * 0.3, y: cy - eyeH)
    )
    eyePath.closeSubpath()

    // Fill eye white with slight transparency
    context.saveGState()
    context.addPath(eyePath)
    context.clip()

    // Eye white fill
    context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.15))
    context.fill(CGRect(x: 0, y: 0, width: s, height: s))

    context.restoreGState()

    // Eye outline stroke
    context.addPath(eyePath)
    context.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.92))
    context.setLineWidth(s * 0.028)
    context.setLineCap(.round)
    context.strokePath()

    // --- Iris: circle inside eye ---
    let irisR = eyeH * 0.72
    let irisCX = cx
    let irisCY = cy

    // Iris gradient fill (purple center to blue edge)
    let irisColors = [
        CGColor(red: 0.55, green: 0.22, blue: 0.82, alpha: 1.0),
        CGColor(red: 0.18, green: 0.50, blue: 0.85, alpha: 1.0),
    ]
    let irisGradient = CGGradient(colorsSpace: colorSpace, colors: irisColors as CFArray, locations: [0.0, 1.0])!

    context.saveGState()
    let irisPath = CGPath(ellipseIn: CGRect(x: irisCX - irisR, y: irisCY - irisR, width: irisR * 2, height: irisR * 2), transform: nil)
    context.addPath(irisPath)
    context.clip()
    context.drawRadialGradient(
        irisGradient,
        startCenter: CGPoint(x: irisCX, y: irisCY), startRadius: 0,
        endCenter: CGPoint(x: irisCX, y: irisCY), endRadius: irisR,
        options: [.drawsAfterEndLocation]
    )
    context.restoreGState()

    // Iris ring
    context.addPath(irisPath)
    context.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.75))
    context.setLineWidth(s * 0.018)
    context.strokePath()

    // --- Pupil ---
    let pupilR = irisR * 0.42
    let pupilPath = CGPath(ellipseIn: CGRect(x: irisCX - pupilR, y: irisCY - pupilR, width: pupilR * 2, height: pupilR * 2), transform: nil)
    context.addPath(pupilPath)
    context.setFillColor(CGColor(red: 0.05, green: 0.04, blue: 0.12, alpha: 0.9))
    context.fillPath()

    // Pupil highlight (small white dot)
    let highlightR = pupilR * 0.35
    let highlightPath = CGPath(ellipseIn: CGRect(
        x: irisCX - pupilR * 0.3 - highlightR,
        y: irisCY + pupilR * 0.2 - highlightR,
        width: highlightR * 2, height: highlightR * 2), transform: nil)
    context.addPath(highlightPath)
    context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.85))
    context.fillPath()

    // --- Cursor Arrow (bottom-right of eye area) ---
    // Arrow tip at roughly (cx + eyeW*0.52, cy - eyeH*0.72)
    let arrowTipX = cx + eyeW * 0.50
    let arrowTipY = cy - eyeH * 0.68
    let arrowScale = s * 0.14

    drawCursorArrow(in: context, tipX: arrowTipX, tipY: arrowTipY, scale: arrowScale)
}

func drawCursorArrow(in context: CGContext, tipX: CGFloat, tipY: CGFloat, scale: CGFloat) {
    // Classic Mac cursor arrow pointing up-left, scaled
    // Tip at (tipX, tipY), arrow points up-left
    let arrow = CGMutablePath()

    // Cursor shape: arrow pointing top-left
    // Define points relative to tip
    let dx = scale
    let dy = scale
    let shaftW = dx * 0.28   // shaft width
    let notch  = dy * 0.62   // where shaft starts on right side

    arrow.move(to: CGPoint(x: tipX, y: tipY))                                    // tip
    arrow.addLine(to: CGPoint(x: tipX, y: tipY - dy))                            // left edge bottom
    arrow.addLine(to: CGPoint(x: tipX + shaftW * 0.7, y: tipY - dy * 0.68))     // notch inner-left
    arrow.addLine(to: CGPoint(x: tipX + shaftW * 1.4, y: tipY - dy * 1.12))     // shaft bottom-right
    arrow.addLine(to: CGPoint(x: tipX + shaftW * 1.85, y: tipY - dy * 0.95))    // shaft bottom-right outer
    arrow.addLine(to: CGPoint(x: tipX + shaftW, y: tipY - notch))               // notch right
    arrow.addLine(to: CGPoint(x: tipX + dx, y: tipY - notch))                   // right edge
    arrow.addLine(to: CGPoint(x: tipX + dx, y: tipY))                           // right edge top -> goes to tip
    arrow.closeSubpath()

    // Shadow/glow for cursor
    context.saveGState()
    context.setShadow(offset: CGSize(width: 1.5, height: -1.5), blur: scale * 0.18,
                      color: CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.55))
    context.addPath(arrow)
    context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.97))
    context.fillPath()
    context.restoreGState()

    // Stroke outline
    context.addPath(arrow)
    context.setStrokeColor(CGColor(red: 0.35, green: 0.18, blue: 0.55, alpha: 0.7))
    context.setLineWidth(scale * 0.045)
    context.setLineJoin(.round)
    context.strokePath()
}

// MARK: - Render to NSImage / CGContext

func renderIcon(size: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    let gc = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = gc
    let ctx = gc.cgContext
    // Flip coordinate system so (0,0) is bottom-left (CoreGraphics default)
    ctx.translateBy(x: 0, y: CGFloat(size))
    ctx.scaleBy(x: 1, y: -1)
    drawIcon(in: ctx, size: CGFloat(size))
    NSGraphicsContext.restoreGraphicsState()

    return rep
}

func savePNG(_ rep: NSBitmapImageRep, to path: String) {
    guard let data = rep.representation(using: .png, properties: [:]) else {
        print("Failed to encode PNG")
        exit(1)
    }
    do {
        try data.write(to: URL(fileURLWithPath: path))
    } catch {
        print("Failed to write PNG to \(path): \(error)")
        exit(1)
    }
}

// MARK: - Main

// Ensure build dir exists
let fm = FileManager.default
try! fm.createDirectory(atPath: buildDir, withIntermediateDirectories: true)
try! fm.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

// Render 1024x1024
print("Rendering 1024x1024 icon...")
let rep1024 = renderIcon(size: 1024)
savePNG(rep1024, to: outputPNG)
print("Saved: \(outputPNG)")

// Iconset sizes: [size, scale] -> filename
let iconSizes: [(Int, Int)] = [
    (16, 1), (16, 2),
    (32, 1), (32, 2),
    (64, 1), (64, 2),   // not standard but harmless
    (128, 1), (128, 2),
    (256, 1), (256, 2),
    (512, 1), (512, 2),
]

// Cache rendered sizes to avoid re-rendering same pixel size twice
var rendered: [Int: NSBitmapImageRep] = [1024: rep1024]

print("Generating iconset...")
for (pts, scale) in iconSizes {
    let px = pts * scale
    if rendered[px] == nil {
        rendered[px] = renderIcon(size: px)
    }
    let rep = rendered[px]!
    let filename: String
    if scale == 1 {
        filename = "icon_\(pts)x\(pts).png"
    } else {
        filename = "icon_\(pts)x\(pts)@2x.png"
    }
    let dest = iconsetDir + "/" + filename
    savePNG(rep, to: dest)
    print("  \(filename)")
}

// Copy 1024x1024 as icon_512x512@2x.png (required by iconutil)
let dest512x2 = iconsetDir + "/icon_512x512@2x.png"
savePNG(rep1024, to: dest512x2)
print("  icon_512x512@2x.png")

print("Running iconutil...")
let task = Process()
task.launchPath = "/usr/bin/iconutil"
task.arguments = ["-c", "icns", iconsetDir, "-o", outputICNS]
task.launch()
task.waitUntilExit()

if task.terminationStatus == 0 {
    print("Generated: \(outputICNS)")
} else {
    print("iconutil failed with status \(task.terminationStatus)")
    exit(1)
}

print("\nDone! Icon files:")
print("  PNG: \(outputPNG)")
print("  ICNS: \(outputICNS)")
