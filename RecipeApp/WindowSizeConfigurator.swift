// WindowSizeConfigurator.swift
// Adds macOS window min/max content size constraints for SwiftUI windows, clamping during live resize.

#if os(macOS)
import SwiftUI
import AppKit

// A lightweight NSView that notifies when it attaches to a window
final class _WindowSizeHostingView: NSView {
    var onWindowAvailable: ((NSWindow?) -> Void)?
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowAvailable?(self.window)
    }
}

struct WindowSizeConfigurator: NSViewRepresentable {
    var minSize: CGSize? = nil
    var maxSize: CGSize? = nil

    class Coordinator: NSObject, NSWindowDelegate {
        var minSize: NSSize?
        var maxSize: NSSize?
        weak var window: NSWindow?

        func attach(to window: NSWindow?) {
            guard let window else { return }
            self.window = window
            if let minSize { window.contentMinSize = minSize }
            if let maxSize { window.contentMaxSize = maxSize }
            window.delegate = self
            enforceMaxIfNeeded()
        }

        func enforceMaxIfNeeded() {
            guard let window, let max = maxSize else { return }
            let current = window.contentView?.frame.size ?? .zero
            let clamped = NSSize(width: min(current.width, max.width), height: min(current.height, max.height))
            if clamped != current {
                window.setContentSize(clamped)
            }
        }

        // Clamp size while the user resizes the window
        func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
            var size = frameSize
            if let min = minSize {
                size.width = max(size.width, min.width)
                size.height = max(size.height, min.height)
            }
            if let max = maxSize {
                size.width = min(size.width, max.width)
                size.height = min(size.height, max.height)
            }
            return size
        }
    }

    func makeCoordinator() -> Coordinator {
        let c = Coordinator()
        c.minSize = minSize.map { NSSize(width: $0.width, height: $0.height) }
        c.maxSize = maxSize.map { NSSize(width: $0.width, height: $0.height) }
        return c
    }

    func makeNSView(context: Context) -> _WindowSizeHostingView {
        let view = _WindowSizeHostingView(frame: .zero)
        view.onWindowAvailable = { window in
            context.coordinator.attach(to: window)
        }
        // In case the window is already available
        context.coordinator.attach(to: view.window)
        return view
    }

    func updateNSView(_ nsView: _WindowSizeHostingView, context: Context) {
        context.coordinator.minSize = minSize.map { NSSize(width: $0.width, height: $0.height) }
        context.coordinator.maxSize = maxSize.map { NSSize(width: $0.width, height: $0.height) }
        if let window = nsView.window {
            context.coordinator.attach(to: window)
        } else {
            context.coordinator.enforceMaxIfNeeded()
        }
    }
}
#endif
