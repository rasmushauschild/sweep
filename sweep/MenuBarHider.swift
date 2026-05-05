import AppKit

@MainActor
final class MenuBarHider {
    private(set) var isHiding = false

    var onStateChange: (() -> Void)?

    func toggle(spacerItem: NSStatusItem, relativeTo statusView: NSView) {
        if isHiding {
            reveal(spacerItem: spacerItem)
            return
        }

        guard spacerItem.view != nil,
              let hiddenWidth = hiddenWidth(relativeTo: statusView)
        else {
            NSSound.beep()
            return
        }

        setSpacer(spacerItem, length: hiddenWidth)
        isHiding = true
        onStateChange?()
        verifyVisibleAfterSet(spacerItem: spacerItem, statusView: statusView)
    }

    func reveal(spacerItem: NSStatusItem) {
        setSpacer(spacerItem, length: 0)
        let wasHiding = isHiding
        isHiding = false
        if wasHiding {
            onStateChange?()
        }
    }

    private func setSpacer(_ spacerItem: NSStatusItem, length: CGFloat) {
        spacerItem.length = length
        (spacerItem.view as? MenuBarSpacerView)?.updateLength(length)
    }

    // After expanding the spacer, the visible Sweep icon must still be on-screen.
    // If macOS culled it for space, auto-reveal so the user can recover without
    // having to quit and relaunch.
    private func verifyVisibleAfterSet(spacerItem: NSStatusItem, statusView: NSView) {
        DispatchQueue.main.async { [weak self] in
            guard
                let self,
                let frame = statusView.window?.frame,
                let screen = statusView.window?.screen,
                !screen.frame.contains(frame)
            else {
                return
            }
            self.reveal(spacerItem: spacerItem)
            NSSound.beep()
        }
    }

    private func hiddenWidth(relativeTo statusView: NSView) -> CGFloat? {
        guard
            let statusViewFrame = screenFrame(for: statusView),
            let screen = statusView.window?.screen
                ?? NSScreen.screens.first(where: {
                    $0.frame.contains(CGPoint(x: statusViewFrame.midX, y: statusViewFrame.midY))
                })
        else {
            return nil
        }

        // Same idea as Hidden Bar (https://github.com/dwarvesf/hidden): the “separator”
        // status item grows to a large, screen-derived length — not a tight width from
        // window bounds. CGWindowList misses or mis-sizes some menu-bar hosts (fused
        // rows, padding), which left icons only partly pushed; a bounded collapse length
        // matches what works in production there.
        let screenWidth = screen.visibleFrame.width
        let boundedCollapseLength = max(800, min(screenWidth + 200, 4000))
        return boundedCollapseLength
    }

    private func screenFrame(for statusView: NSView) -> CGRect? {
        guard let window = statusView.window else {
            return nil
        }

        let frameInWindow = statusView.convert(statusView.bounds, to: nil)
        return window.convertToScreen(frameInWindow)
    }
}
