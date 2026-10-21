import SwiftUI

struct LaunchView: View {
    let animated: Bool
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(red: 0.02, green: 0.09, blue: 0.065)
                VStack(spacing: 18) {
                    BrainCircuit(animated: animated)
                    Text("Revia")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(Color(red: 0.81, green: 0.97, blue: 0.86))
                }
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2 - 5.5)
            }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .combine)
    }
}
