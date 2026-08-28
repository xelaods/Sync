import SwiftUI

enum Theme {
    static let primary = Color(red: 0.31, green: 0.27, blue: 0.90)
    static let primaryLight = Color(red: 0.23, green: 0.51, blue: 0.96)
    static let background = Color(red: 0.96, green: 0.97, blue: 0.99)
    static let card = Color.white
    static let textPrimary = Color(red: 0.12, green: 0.14, blue: 0.25)
    static let textSecondary = Color(red: 0.45, green: 0.48, blue: 0.58)

    static let normal = Color(red: 0.23, green: 0.51, blue: 0.96)
    static let holiday = Color(red: 0.93, green: 0.35, blue: 0.35)
    static let night = Color(red: 0.45, green: 0.30, blue: 0.80)

    static var gradient: LinearGradient {
        LinearGradient(colors: [primary, primaryLight],
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing)
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.card)
                    .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
            )
    }
}

extension View {
    func card() -> some View { modifier(CardModifier()) }
}
