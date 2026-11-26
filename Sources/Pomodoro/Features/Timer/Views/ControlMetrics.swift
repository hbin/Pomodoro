import SwiftUI

/// Fixed control-row geometry. The primary keeps one width in every state so
/// showing or hiding the trailing end control never reflows it.
enum ControlMetrics {
    static let rowHeight: CGFloat = 49
    static let primaryWidth: CGFloat = 190
    static let endHitWidth: CGFloat = 48
    static let endIconSize: CGFloat = 20
    static let hoverDiscSize: CGFloat = 36
}
