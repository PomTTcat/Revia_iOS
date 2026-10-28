import SwiftUI

/// A single circuit gradually decelerates as it returns to the first node.
struct BrainCircuit: View {
    @EnvironmentObject private var theme: ThemeManager
    static let duration: Double = 1.6
    let animated: Bool
    @State private var startedAt = Date()
    private let nodes = [CGPoint(x: 420, y: 300), CGPoint(x: 725, y: 448), CGPoint(x: 500, y: 596)]
    private var background: Color { Palette.brandBackground }
    private var mint: Color { Palette.glow }

    var body: some View {
        let _ = theme.selected
        ZStack {
            Image(theme.selected.previewName).resizable().scaledToFit()
            if animated {
                background.opacity(0.67)
                TimelineView(.animation(minimumInterval: 1.0 / 60)) { timeline in
                    let time = min(1, max(0, timeline.date.timeIntervalSince(startedAt) / Self.duration))
                    // Quadratic ease-out: fast at the start, smoothly slowing to a stop.
                    let elapsed = 1 - (1 - time) * (1 - time)
                    Canvas { context, size in
                        let scale = size.width / 1024
                        let transform = CGAffineTransform(scaleX: scale, y: scale)
                        for index in 0..<3 {
                            let start = Double(index) / 3
                            let head = min(1, max(0, (elapsed - start) * 3))
                            let tail = max(0, head - 0.42)
                            let fade = max(0, 1 - max(0, elapsed - (start + 1.0 / 3)) * 5)
                            if head > 0 && fade > 0 {
                                let path = route(index).applying(transform)
                                // A faint trail remains briefly after each node is reached.
                                context.stroke(path.trimmedPath(from: 0, to: head), with: .color(mint.opacity(0.25 * fade)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                                let light = path.trimmedPath(from: tail, to: head)
                                context.drawLayer { glow in
                                    glow.addFilter(.blur(radius: 3))
                                    glow.stroke(light, with: .color(mint.opacity(fade)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                                }
                                context.stroke(light, with: .color(Palette.glow.opacity(fade)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                            }
                        }
                        for index in nodes.indices {
                            let arrival = Double(index) / 3
                            let pulse = max(0, 1 - max(0, elapsed - arrival) / 0.28)
                            let reached = elapsed >= arrival
                            let returning = index == 0 ? max(0, (elapsed - 0.9) * 10) : 0
                            let brightness = max(reached ? pulse : 0, returning)
                            let point = CGPoint(x: nodes[index].x * scale, y: nodes[index].y * scale)
                            let radius = 4.6 + brightness * 1.5
                            context.drawLayer { glow in
                                glow.addFilter(.blur(radius: 4))
                                let halo = CGRect(x: point.x - 10, y: point.y - 10, width: 20, height: 20)
                                glow.fill(Path(ellipseIn: halo), with: .color(mint.opacity(brightness * 0.85)))
                            }
                            let dot = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
                            context.fill(Path(ellipseIn: dot), with: .color(mint.opacity(0.15 + brightness * 0.85)))
                            if brightness > 0 {
                                let core = CGRect(x: point.x - 2.3, y: point.y - 2.3, width: 4.6, height: 4.6)
                                context.fill(Path(ellipseIn: core), with: .color(.white.opacity(brightness)))
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 160, height: 160)
        .onAppear { startedAt = Date() }
        .accessibilityHidden(true)
    }
    private func route(_ index: Int) -> Path {
        Path { path in
            switch index {
            case 0:
                path.move(to: nodes[0])
                path.addCurve(to: nodes[1], control1: CGPoint(x: 552, y: 278), control2: CGPoint(x: 607, y: 372))
            case 1:
                path.move(to: nodes[1])
                path.addCurve(to: nodes[2], control1: CGPoint(x: 756, y: 566), control2: CGPoint(x: 632, y: 625))
            default:
                path.move(to: nodes[2])
                path.addCurve(to: CGPoint(x: 302, y: 477), control1: CGPoint(x: 444, y: 575), control2: CGPoint(x: 314, y: 538))
                path.addCurve(to: nodes[0], control1: CGPoint(x: 269, y: 394), control2: CGPoint(x: 338, y: 313))
            }
        }
    }
}
