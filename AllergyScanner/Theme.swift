import SwiftUI
import UIKit

extension Color {
    /// Brand accent (indigo/violet) — pulled from the AccentColor asset so it's consistent
    /// everywhere (nav bars, tints) without hardcoding it more than once.
    static let brand = Color.accentColor
    /// Reserved for matched-keyword warnings only — kept distinct from `brand` so a real
    /// match always stands out from routine UI chrome.
    static let warning = Color(red: 0.88, green: 0.20, blue: 0.18)
    static let cardBackground = Color(.secondarySystemGroupedBackground)
    static let appBackground = Color(.systemGroupedBackground)
}

extension UIColor {
    /// UIKit equivalent of `Color.warning`, for CALayer-based drawing (e.g. the camera
    /// preview's match-highlight boxes) where SwiftUI `Color` isn't usable directly.
    static let warning = UIColor(red: 0.88, green: 0.20, blue: 0.18, alpha: 1)
}

extension LinearGradient {
    static let brandButton = LinearGradient(
        colors: [Color.brand, Color.brand.opacity(0.78)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// A rounded, shadowed card style used for list rows and input fields throughout the app.
struct CardBackground: ViewModifier {
    var cornerRadius: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.cardBackground)
                    .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
            )
    }
}

extension View {
    func cardBackground(cornerRadius: CGFloat = 16) -> some View {
        modifier(CardBackground(cornerRadius: cornerRadius))
    }
}
