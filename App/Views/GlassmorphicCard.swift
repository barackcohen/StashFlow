import SwiftUI

public struct GlassmorphicCard<Content: View>: View {
    public var gradientColors: [Color]
    public var content: () -> Content
    
    public init(
        gradientColors: [Color] = [Color.white.opacity(0.07), Color.white.opacity(0.02)],
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.gradientColors = gradientColors
        self.content = content
    }
    
    public var body: some View {
        content()
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            )
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.black.opacity(0.15))
                    .blur(radius: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.02),
                                Color.black.opacity(0.1),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.25), radius: 15, x: 0, y: 10)
    }
}

// Visual helper extension to easily apply a glass background
extension View {
    public func glassBackground(
        colors: [Color] = [Color.white.opacity(0.07), Color.white.opacity(0.02)]
    ) -> some View {
        modifier(GlassmorphicBackgroundModifier(colors: colors))
    }
}

struct GlassmorphicBackgroundModifier: ViewModifier {
    var colors: [Color]
    
    func body(content: Content) -> some View {
        content
            .background(
                Blur(style: .systemThinMaterialDark)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 8)
    }
}

// SwiftUI integration for UIKit UIVisualEffectView blur
struct Blur: UIViewRepresentable {
    var style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}
