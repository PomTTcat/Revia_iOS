import SwiftUI

struct LaunchView: View {
    @EnvironmentObject private var theme: ThemeManager
    let animated: Bool
    var body: some View {
        let _ = theme.selected
        GeometryReader { geometry in
            ZStack {
                Palette.brandBackground
                VStack(spacing: 18) {
                    BrainCircuit(animated: animated)
                    Text("Revia")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(Palette.glow)
                }
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2 - 5.5)
            }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .combine)
    }
}
