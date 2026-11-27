import AppKit
import SwiftUI
import XCTest
@testable import Pomodoro

final class PaletteContractTests: XCTestCase {
    func testLightMutedInkUsesApprovedTokenAndMeetsAA() throws {
        let palette = Palette.forScheme(.light)
        let mutedInk = try sRGB(palette.mutedInk)

        assertColor(mutedInk, red: 0x6B, green: 0x5E, blue: 0x4E)

        for surface in [palette.bone, palette.paper, palette.plaque] {
            XCTAssertGreaterThanOrEqual(
                contrastRatio(mutedInk, try sRGB(surface)),
                4.5
            )
        }
    }

    func testBlackMutedInkIsUnchanged() throws {
        let mutedInk = try sRGB(Palette.forScheme(.dark).mutedInk)

        assertColor(mutedInk, red: 0xA6, green: 0x97, blue: 0x82)
    }

    func testInkRemainsStrongerThanMutedInkOnPrimarySurfaces() throws {
        let palette = Palette.forScheme(.light)
        let ink = try sRGB(palette.ink)
        let mutedInk = try sRGB(palette.mutedInk)

        for surface in [palette.bone, palette.paper, palette.plaque] {
            let surface = try sRGB(surface)
            XCTAssertGreaterThan(
                contrastRatio(ink, surface),
                contrastRatio(mutedInk, surface)
            )
        }
    }

    private func assertColor(
        _ color: SRGB,
        red: UInt8,
        green: UInt8,
        blue: UInt8,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(color.red, Double(red) / 255, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(color.green, Double(green) / 255, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(color.blue, Double(blue) / 255, accuracy: 0.001, file: file, line: line)
    }

    private func sRGB(_ color: Color) throws -> SRGB {
        let color = try XCTUnwrap(NSColor(color).usingColorSpace(.sRGB))
        return SRGB(
            red: Double(color.redComponent),
            green: Double(color.greenComponent),
            blue: Double(color.blueComponent)
        )
    }

    private func contrastRatio(_ lhs: SRGB, _ rhs: SRGB) -> Double {
        let first = relativeLuminance(lhs)
        let second = relativeLuminance(rhs)
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }

    private func relativeLuminance(_ color: SRGB) -> Double {
        let red = linearize(color.red)
        let green = linearize(color.green)
        let blue = linearize(color.blue)
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue
    }

    private func linearize(_ component: Double) -> Double {
        component <= 0.04045
            ? component / 12.92
            : pow((component + 0.055) / 1.055, 2.4)
    }
}

private struct SRGB {
    let red: Double
    let green: Double
    let blue: Double
}
