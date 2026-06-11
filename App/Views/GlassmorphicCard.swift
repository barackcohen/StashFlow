import SwiftUI

public struct GlassmorphicCard<Content: View>: View {
    public var content: () -> Content
    
    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    public var body: some View {
        content()
            .padding()
            .background(Color(hex: "#121212"))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

// Visual helper extension to easily apply a glass background
extension View {
    public func glassBackground() -> some View {
        modifier(GlassmorphicBackgroundModifier())
    }
}

struct GlassmorphicBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(hex: "#121212"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}
