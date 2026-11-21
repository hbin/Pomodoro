import AppKit

enum MenuBarIconFactory {
    private static let pointSize = NSSize(width: 22, height: 22)

    static func image(
        progress: Double,
        isPaused: Bool,
        showsRemainingTime: Bool = false
    ) -> NSImage {
        let image = NSImage(size: pointSize)
        for scale in [CGFloat(1), CGFloat(2)] {
            image.addRepresentation(
                bitmapRepresentation(
                    scale: scale,
                    progress: progress,
                    isPaused: isPaused,
                    showsRemainingTime: showsRemainingTime
                )
            )
        }
        image.isTemplate = true
        return image
    }

    private static func bitmapRepresentation(
        scale: CGFloat,
        progress: Double,
        isPaused: Bool,
        showsRemainingTime: Bool
    ) -> NSBitmapImageRep {
        let pixelWidth = Int(pointSize.width * scale)
        let pixelHeight = Int(pointSize.height * scale)
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        rep.size = pointSize

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.cgContext.setShouldAntialias(true)
        draw(
            progress: progress,
            isPaused: isPaused,
            showsRemainingTime: showsRemainingTime
        )
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    private static func draw(
        progress: Double,
        isPaused: Bool,
        showsRemainingTime: Bool
    ) {
        let center = CGPoint(x: 11, y: 11)
        let radius: CGFloat = 8.4
        let elapsedProgress = min(max(progress, 0), 1)
        let dialProgress = if showsRemainingTime {
            elapsedProgress >= 1 ? 1 : 1 - elapsedProgress
        } else {
            elapsedProgress
        }
        let darkInk = NSColor.black.withAlphaComponent(0.96)
        let faintInk = NSColor.black.withAlphaComponent(0.55)

        let dialRect = NSRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        let track = NSBezierPath(ovalIn: dialRect)
        faintInk.setStroke()
        track.lineWidth = 1.5
        track.stroke()

        if dialProgress > 0 {
            let startAngle = CGFloat(60)
            let endAngle = startAngle - CGFloat(dialProgress) * 360
            let arc = NSBezierPath()
            arc.appendArc(
                withCenter: center,
                radius: radius,
                startAngle: startAngle,
                endAngle: endAngle,
                clockwise: true
            )
            arc.lineWidth = 2.15
            arc.lineCapStyle = .round
            darkInk.setStroke()
            arc.stroke()
        }

        if isPaused {
            darkInk.setFill()
            for x in [center.x - 1.8, center.x + 0.45] {
                let bar = NSBezierPath(
                    roundedRect: NSRect(
                        x: x,
                        y: center.y - 3.2,
                        width: 1.35,
                        height: 6.4
                    ),
                    xRadius: 0.45,
                    yRadius: 0.45
                )
                bar.fill()
            }
        } else {
            let degrees = showsRemainingTime
                ? 60 + CGFloat(elapsedProgress) * 360
                : 60 - CGFloat(elapsedProgress) * 360
            let angle = degrees * .pi / 180
            let hand = NSBezierPath()
            hand.move(to: center)
            hand.line(to: CGPoint(
                x: center.x + cos(angle) * radius * 0.74,
                y: center.y + sin(angle) * radius * 0.74
            ))
            hand.lineWidth = 2.15
            hand.lineCapStyle = .round
            darkInk.setStroke()
            hand.stroke()

            let pivot = NSBezierPath(ovalIn: NSRect(
                x: center.x - 1.35,
                y: center.y - 1.35,
                width: 2.7,
                height: 2.7
            ))
            NSColor.black.withAlphaComponent(0.98).setFill()
            pivot.fill()
        }
    }
}
