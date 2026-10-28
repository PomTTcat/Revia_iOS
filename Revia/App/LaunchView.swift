import SwiftUI

struct LaunchView: View {
    let animated: Bool
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LaunchAppearance.background
                VStack(spacing: 18) {
                    BrainCircuit(animated: animated)
                    Text("Revia")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(LaunchAppearance.foreground)
                }
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2 - 5.5)
            }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .combine)
    }
}


/// The static launch screen uses the same neutral background and logo in every theme.
enum LaunchAppearance {
    static let background = Color(red: 21.0 / 255, green: 23.0 / 255, blue: 26.0 / 255)
    static let foreground = Color(red: 0.95, green: 0.95, blue: 0.96)
    static let fadeDuration = 0.35
}
