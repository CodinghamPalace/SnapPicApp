//  WindowAnchor.swift
//  SnapPic
//  Helper to provide a visible UIWindow for presentations from SwiftUI.

import SwiftUI
import UIKit

final class WindowProvider {
    static let shared = WindowProvider()
    private init() {}
    weak var window: UIWindow?
}

private final class WindowFinderView: UIView {
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let win = self.window {
            WindowProvider.shared.window = win
        }
    }
}

struct WindowReader: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        WindowFinderView(frame: .zero)
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}
