import SwiftUI

enum Theme {
    static let primary = Color(red: 0.45, green: 0.40, blue: 1.0)
    static let primaryLight = Color(red: 0.35, green: 0.65, blue: 1.0)
    
    // ダークモード用背景・カード
    static let background = Color(red: 0.05, green: 0.05, blue: 0.07) // ほぼ黒
    static let card = Color(red: 0.12, green: 0.12, blue: 0.15)       // ダークグレー
    
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 0.65, green: 0.68, blue: 0.75)

    static let normal = Color(red: 0.35, green: 0.65, blue: 1.0)
    static let holiday = Color(red: 1.0, green: 0.45, blue: 0.45)
    static let night = Color(red: 0.65, green: 0.45, blue: 1.0)

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
                    .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 4)
            )
    }
}

extension View {
    func card() -> some View { modifier(CardModifier()) }
}
