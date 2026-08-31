import AtelierCore
import SwiftUI

public enum AtelierPalette {
    public static let paper = Color(red: 0.98, green: 0.96, blue: 0.91)
    public static let ink = Color(red: 0.16, green: 0.15, blue: 0.14)
    public static let coral = Color(red: 0.91, green: 0.35, blue: 0.31)
    public static let cyan = Color(red: 0.20, green: 0.66, blue: 0.72)
    public static let yellow = Color(red: 0.96, green: 0.76, blue: 0.25)

    public static func accent(for product: AppProduct) -> Color {
        switch product {
        case .atelier, .mail: coral
        case .notes: yellow
        case .calendar: cyan
        case .tasks: Color(red: 0.35, green: 0.59, blue: 0.35)
        }
    }
}

public struct AtelierCardModifier: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content
            .padding()
            .background(.regularMaterial, in: .rect(cornerRadius: 16))
    }
}

public extension View {
    func atelierCard() -> some View {
        modifier(AtelierCardModifier())
    }
}
