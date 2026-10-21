import SwiftUI
import UIKit

/// Observe background taps without stealing buttons, scrolling or text-field focus.
struct KeyboardDismiss: UIViewRepresentable {
    func makeUIView(context: Context) -> TapView { TapView() }
    func updateUIView(_ uiView: TapView, context: Context) {}
    static func dismantleUIView(_ uiView: TapView, coordinator: ()) { uiView.detach() }

    final class TapView: UIView, UIGestureRecognizerDelegate {
        private weak var attachedWindow: UIWindow?
        private lazy var tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        override func didMoveToWindow() {
            super.didMoveToWindow()
            detach()
            guard let window else { return }
            tap.cancelsTouchesInView = false
            tap.delegate = self
            window.addGestureRecognizer(tap)
            attachedWindow = window
        }
        func detach() { attachedWindow?.removeGestureRecognizer(tap); attachedWindow = nil }
        @objc private func dismissKeyboard() { attachedWindow?.endEditing(true) }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard !isHidden, bounds.contains(touch.location(in: self)) else { return false }
            var view = touch.view
            while let current = view {
                if current is UITextField || current is UITextView { return false }
                view = current.superview
            }
            return true
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }
    }
}
