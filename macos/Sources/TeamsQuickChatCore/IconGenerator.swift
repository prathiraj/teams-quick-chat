import AppKit
import CoreGraphics
import Foundation

public enum IconGeneratorError: LocalizedError {
    case graphicsContextCreationFailed
    case pngEncodingFailed

    public var errorDescription: String? {
        switch self {
        case .graphicsContextCreationFailed:
            return "Could not create graphics bitmap context for icon generation."
        case .pngEncodingFailed:
            return "Could not encode icon bitmap as PNG."
        }
    }
}

public enum IconGenerator {
    private static let icnsTypes: [(type: String, pixelSize: Int)] = [
        ("icp4", 16),
        ("icp5", 32),
        ("ic11", 32),
        ("ic12", 64),
        ("ic07", 128),
        ("ic13", 256),
        ("ic08", 256),
        ("ic14", 512),
        ("ic09", 512),
        ("ic10", 1024)
    ]

    public static func generateAppIconICNS(to destinationURL: URL) throws {
        var cache: [Int: Data] = [:]
        let data = try buildICNSData { pixelSize in
            if let cached = cache[pixelSize] { return cached }
            let rendered = try renderAppIconPNG(size: pixelSize)
            cache[pixelSize] = rendered
            return rendered
        }
        try FileManager.default.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: destinationURL, options: [.atomic])
    }

    public static func generateContactShortcutICNS(
        initials: String,
        isGroupChat: Bool,
        to destinationURL: URL
    ) throws {
        var cache: [Int: Data] = [:]
        let data = try buildICNSData { pixelSize in
            if let cached = cache[pixelSize] { return cached }
            let rendered = try renderContactIconPNG(initials: initials, isGroupChat: isGroupChat, size: pixelSize)
            cache[pixelSize] = rendered
            return rendered
        }
        try FileManager.default.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: destinationURL, options: [.atomic])
    }

    public static func buildICNSData(pngProvider: (Int) throws -> Data) throws -> Data {
        var chunksData = Data()
        for entry in icnsTypes {
            let png = try pngProvider(entry.pixelSize)
            guard let typeBytes = entry.type.data(using: .ascii), typeBytes.count == 4 else {
                continue
            }
            var chunkLength = UInt32(8 + png.count).bigEndian
            chunksData.append(typeBytes)
            chunksData.append(Data(bytes: &chunkLength, count: 4))
            chunksData.append(png)
        }

        var icns = Data()
        icns.append(contentsOf: [0x69, 0x63, 0x6E, 0x73]) // "icns"
        var totalLength = UInt32(8 + chunksData.count).bigEndian
        icns.append(Data(bytes: &totalLength, count: 4))
        icns.append(chunksData)
        return icns
    }

    public static func renderAppIconPNG(size: Int) throws -> Data {
        try renderCanvas(size: size) { ctx, s in
            let inset = s * 0.095
            let rect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
            let cornerRadius = rect.width * 0.225

            // Subtle macOS squircle drop shadow
            ctx.saveGState()
            ctx.setShadow(
                offset: CGSize(width: 0, height: -s * 0.018),
                blur: s * 0.045,
                color: CGColor(red: 0.12, green: 0.10, blue: 0.35, alpha: 0.34)
            )
            let squircle = CGPath(
                roundedRect: rect,
                cornerWidth: cornerRadius,
                cornerHeight: cornerRadius,
                transform: nil
            )
            ctx.addPath(squircle)
            ctx.setFillColor(CGColor(red: 0.35, green: 0.35, blue: 0.90, alpha: 1.0))
            ctx.fillPath()
            ctx.restoreGState()

            // Gradient fill inside squircle
            ctx.saveGState()
            ctx.addPath(squircle)
            ctx.clip()
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let colors = [
                CGColor(red: 0.48, green: 0.47, blue: 0.98, alpha: 1.0),
                CGColor(red: 0.31, green: 0.29, blue: 0.86, alpha: 1.0)
            ] as CFArray
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) {
                ctx.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: rect.minX, y: rect.maxY),
                    end: CGPoint(x: rect.maxX, y: rect.minY),
                    options: []
                )
            }

            // Inner border highlight
            ctx.addPath(squircle)
            ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.22))
            ctx.setLineWidth(max(1.0, s * 0.012))
            ctx.strokePath()

            // Secondary back chat bubble
            let backBubble = CGRect(
                x: s * 0.43,
                y: s * 0.44,
                width: s * 0.33,
                height: s * 0.25
            )
            let backPath = CGPath(
                roundedRect: backBubble,
                cornerWidth: backBubble.height * 0.38,
                cornerHeight: backBubble.height * 0.38,
                transform: nil
            )
            ctx.addPath(backPath)
            ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.34))
            ctx.fillPath()

            // Primary foreground chat bubble with tail
            let mainBubble = CGRect(
                x: s * 0.23,
                y: s * 0.30,
                width: s * 0.44,
                height: s * 0.34
            )
            let bubblePath = CGMutablePath()
            bubblePath.addRoundedRect(
                in: mainBubble,
                cornerWidth: mainBubble.height * 0.36,
                cornerHeight: mainBubble.height * 0.36
            )
            bubblePath.move(to: CGPoint(x: mainBubble.minX + mainBubble.width * 0.20, y: mainBubble.minY + mainBubble.height * 0.08))
            bubblePath.addLine(to: CGPoint(x: mainBubble.minX + mainBubble.width * 0.10, y: mainBubble.minY - mainBubble.height * 0.20))
            bubblePath.addLine(to: CGPoint(x: mainBubble.minX + mainBubble.width * 0.38, y: mainBubble.minY + mainBubble.height * 0.04))
            bubblePath.closeSubpath()

            ctx.addPath(bubblePath)
            ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.97))
            ctx.fillPath()

            // Subtle chat lines inside primary bubble
            if size >= 32 {
                let lineH = max(1.5, s * 0.032)
                let line1 = CGRect(
                    x: mainBubble.minX + mainBubble.width * 0.20,
                    y: mainBubble.midY + s * 0.025,
                    width: mainBubble.width * 0.60,
                    height: lineH
                )
                let line2 = CGRect(
                    x: mainBubble.minX + mainBubble.width * 0.20,
                    y: mainBubble.midY - s * 0.055,
                    width: mainBubble.width * 0.42,
                    height: lineH
                )
                for line in [line1, line2] {
                    let lp = CGPath(roundedRect: line, cornerWidth: lineH / 2, cornerHeight: lineH / 2, transform: nil)
                    ctx.addPath(lp)
                    ctx.setFillColor(CGColor(red: 0.35, green: 0.34, blue: 0.89, alpha: 1.0))
                    ctx.fillPath()
                }
            }

            ctx.restoreGState()
        }
    }

    public static func renderContactIconPNG(initials: String, isGroupChat: Bool, size: Int) throws -> Data {
        try renderCanvas(size: size) { ctx, s in
            let inset = s * 0.095
            let rect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
            let cornerRadius = rect.width * 0.225
            let squircle = CGPath(
                roundedRect: rect,
                cornerWidth: cornerRadius,
                cornerHeight: cornerRadius,
                transform: nil
            )

            ctx.saveGState()
            ctx.setShadow(
                offset: CGSize(width: 0, height: -s * 0.016),
                blur: s * 0.04,
                color: CGColor(red: 0.12, green: 0.10, blue: 0.35, alpha: 0.25)
            )
            ctx.addPath(squircle)
            ctx.setFillColor(CGColor(red: 0.93, green: 0.93, blue: 1.0, alpha: 1.0))
            ctx.fillPath()
            ctx.restoreGState()

            ctx.saveGState()
            ctx.addPath(squircle)
            ctx.clip()
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bgColors = [
                CGColor(red: 0.96, green: 0.96, blue: 1.0, alpha: 1.0),
                CGColor(red: 0.88, green: 0.88, blue: 0.99, alpha: 1.0)
            ] as CFArray
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0]) {
                ctx.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: rect.minX, y: rect.maxY),
                    end: CGPoint(x: rect.maxX, y: rect.minY),
                    options: []
                )
            }

            ctx.addPath(squircle)
            ctx.setStrokeColor(CGColor(red: 0.35, green: 0.35, blue: 0.90, alpha: 0.22))
            ctx.setLineWidth(max(1.0, s * 0.015))
            ctx.strokePath()
            ctx.restoreGState()

            // Centered contact initials
            let label = initials.isEmpty ? "TC" : String(initials.prefix(2)).uppercased()
            let fontSize = s * (label.count == 1 ? 0.42 : 0.35)
            let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor(calibratedRed: 0.33, green: 0.32, blue: 0.88, alpha: 1.0),
                .paragraphStyle: paragraph
            ]
            let attrStr = NSAttributedString(string: label, attributes: attrs)
            let textSize = attrStr.size()
            let textRect = CGRect(
                x: (s - textSize.width) / 2.0,
                y: (s - textSize.height) / 2.0,
                width: textSize.width,
                height: textSize.height
            )
            attrStr.draw(in: textRect)

            // Corner Teams-indigo badge so Dock shortcut is clearly identifiable as a Quick Chat
            if size >= 32 {
                let badgeDiameter = s * 0.26
                let badgeRect = CGRect(
                    x: rect.maxX - badgeDiameter * 0.88,
                    y: rect.minY - badgeDiameter * 0.10,
                    width: badgeDiameter,
                    height: badgeDiameter
                )
                ctx.saveGState()
                ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
                ctx.fillEllipse(in: badgeRect.insetBy(dx: -s * 0.018, dy: -s * 0.018))

                let badgeColor = isGroupChat
                    ? CGColor(red: 0.28, green: 0.42, blue: 0.92, alpha: 1.0)
                    : CGColor(red: 0.35, green: 0.35, blue: 0.90, alpha: 1.0)
                ctx.setFillColor(badgeColor)
                ctx.fillEllipse(in: badgeRect)

                let miniBubble = badgeRect.insetBy(dx: badgeDiameter * 0.26, dy: badgeDiameter * 0.30)
                let miniPath = CGPath(
                    roundedRect: miniBubble,
                    cornerWidth: miniBubble.height * 0.4,
                    cornerHeight: miniBubble.height * 0.4,
                    transform: nil
                )
                ctx.addPath(miniPath)
                ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.96))
                ctx.fillPath()
                ctx.restoreGState()
            }
        }
    }

    private static func renderCanvas(size: Int, draw: (CGContext, CGFloat) -> Void) throws -> Data {
        guard let rep = NSBitmapImageRep(
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
        ),
        let graphicsContext = NSGraphicsContext(bitmapImageRep: rep) else {
            throw IconGeneratorError.graphicsContextCreationFailed
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        let ctx = graphicsContext.cgContext
        ctx.clear(CGRect(x: 0, y: 0, width: size, height: size))
        ctx.interpolationQuality = .high
        draw(ctx, CGFloat(size))
        graphicsContext.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        guard let pngData = rep.representation(using: .png, properties: [:]) else {
            throw IconGeneratorError.pngEncodingFailed
        }
        return pngData
    }
}
