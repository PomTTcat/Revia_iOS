import SwiftUI
import UIKit

/// Install once at the app root. The window recognizer also covers sheets and search UI.
struct KeyboardDismiss: UIViewRepresentable {
    var keepSearchFocused = false
    func makeUIView(context: Context) -> TapView { TapView() }
    func updateUIView(_ uiView: TapView, context: Context) { uiView.keepSearchFocused = keepSearchFocused }
    static func dismantleUIView(_ uiView: TapView, coordinator: ()) { uiView.detach() }

    final class TapView: UIView, UIGestureRecognizerDelegate {
        var keepSearchFocused = false
        private weak var attachedWindow: UIWindow?
        private lazy var tap: UITapGestureRecognizer = {
            let gesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
            gesture.cancelsTouchesInView = false
            gesture.delaysTouchesBegan = false
            gesture.delaysTouchesEnded = false
            gesture.numberOfTouchesRequired = 1
            gesture.delegate = self
            return gesture
        }()
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window !== attachedWindow else { return }
            detach()
            guard let window else { return }
            window.addGestureRecognizer(tap)
            attachedWindow = window
        }
        func detach() {
            attachedWindow?.removeGestureRecognizer(tap)
            attachedWindow = nil
        }
        @objc private func dismissKeyboard() { attachedWindow?.endEditing(true) }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            // Use the app window, not this root view's frame: modal content can extend beyond it.
            guard let attachedWindow, touch.view?.window === attachedWindow,
                  let input = focusedInput(in: attachedWindow) else { return false }
            if keepSearchFocused && input is UISearchTextField { return false }
            var view = touch.view
            while let current = view {
                // Preserve cursor movement, selection, focus transfer, search and native controls.
                if current is UITextInput || current is UISearchBar || current is UIControl { return false }
                view = current.superview
            }
            return true
        }
        private func focusedInput(in view: UIView) -> UIView? {
            if view.isFirstResponder && view is UITextInput { return view }
            for child in view.subviews {
                if let input = focusedInput(in: child) { return input }
            }
            return nil
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }
    }
}
