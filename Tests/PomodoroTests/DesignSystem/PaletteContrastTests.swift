import AppKit
import SwiftUI
import XCTest
@testable import Pomodoro

final class PaletteContrastTests: XCTestCase {
    func testLightMutedInkMeetsContrastOnAllPrimarySurfaces() throws {
        let palette = Palette.forScheme(.light)
        let mutedInk = try sRGB(palette.mutedInk)

        XCTAssertEqual(mutedInk.redComponent, 0x6B / 255.0, accuracy: 0.001)
        XCTAssertEqual(mutedInk.greenComponent, 0x5E / 255.0, accuracy: 0.001)
        XCTAssertEqual(mutedInk.blueComponent, 0x4E / 255.0, accuracy: 0.001)

        for surface in [palette.bone, palette.paper, palette.plaque] {
            XCTAssertGreaterThanOrEqual(contrastRatio(mutedInk, try sRGB(surface)), 4.5)
        }
    }

    func testDarkMutedInkIsUnchanged() throws {
        let mutedInk = try sRGB(Palette.forScheme(.dark).mutedInk)

        XCTAssertEqual(mutedInk.redComponent, 0xA6 / 255.0, accuracy: 0.001)
        XCTAssertEqual(mutedInk.greenComponent, 0x97 / 255.0, accuracy: 0.001)
        XCTAssertEqual(mutedInk.blueComponent, 0x82 / 255.0, accuracy: 0.001)
    }

    private func sRGB(_ color: Color) throws -> NSColor {
        try XCTUnwrap(NSColor(color).usingColorSpace(.sRGB))
    }

    private func contrastRatio(_ lhs: NSColor, _ rhs: NSColor) -> Double {
        let first = relativeLuminance(lhs)
        let second = relativeLuminance(rhs)
        let lighter = max(first, second)
        let darker = min(first, second)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func relativeLuminance(_ color: NSColor) -> Double {
        let red = linearize(Double(color.redComponent))
        let green = linearize(Double(color.greenComponent))
        let blue = linearize(Double(color.blueComponent))
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue
    }

    private func linearize(_ component: Double) -> Double {
        component <= 0.04045
            ? component / 12.92
            : pow((component + 0.055) / 1.055, 2.4)
    }
}
