import AppKit

@MainActor
final class MenuBarHider {
    private(set) var isHiding = false

    func toggle(spacerItem: NSStatusItem, relativeTo statusView: NSView) {
        if isHiding {
            reveal(spacerItem: spacerItem)
            return
        }

        guard let hiddenWidth = hiddenWidth(relativeTo: statusView) else {
            NSSound.beep()
            return
        }

        setSpacer(spacerItem, length: hiddenWidth)
        isHiding = true
        verifyVisibleAfterSet(spacerItem: spacerItem, statusView: statusView)
    }

    func reveal(spacerItem: NSStatusItem) {
        setSpacer(spacerItem, length: 0)
        isHiding = false
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
                let frame = statusView.window?.frame,
                let screen = statusView.window?.screen,
                !screen.frame.contains(frame)
            else { return }
            self?.reveal(spacerItem: spacerItem)
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

        let leftFrames = menuBarItemFrames(onScreen: screen)
            .filter { $0.maxX <= statusViewFrame.minX - 1 }

        guard let minX = leftFrames.map(\.minX).min() else {
            return nil
        }

        let maxX = statusViewFrame.minX - 2
        guard maxX > minX else {
            return nil
        }

        // Belt-and-suspenders: refuse a width that would push Sweep itself or the
        // active app's menus off-screen.
        let safetyFloor: CGFloat = 200
        let raw = maxX - minX
        let cap = max(0, statusViewFrame.minX - screen.frame.minX - safetyFloor)
        return min(raw, cap)
    }

    private func menuBarItemFrames(onScreen screen: NSScreen) -> [CGRect] {
        guard
            let infoList = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID
            ) as? [[String: Any]]
        else {
            return []
        }

        // CG Y = 0 is the top of the main screen; convert to the top edge of
        // `screen` in CG coords.
        let mainScreenMaxY = NSScreen.screens.first?.frame.maxY ?? screen.frame.maxY
        let screenTopCGY = mainScreenMaxY - screen.frame.maxY

        let result = infoList.compactMap { dict -> CGRect? in
            guard
                let boundsDict = dict[kCGWindowBounds as String] as? NSDictionary,
                let cgRect = CGRect(dictionaryRepresentation: boundsDict)
            else { return nil }

            // Anchored at the top of the menu bar.
            guard cgRect.minY <= screenTopCGY + 2 else { return nil }
            // Shape of a menu bar item, not a giant overlay or floating panel.
            // macOS 26's menu bar is ~39pt tall; older macOS is ~22pt.
            guard cgRect.height >= 18, cgRect.height <= 50 else { return nil }
            guard cgRect.width >= 10, cgRect.width <= 300 else { return nil }
            // X is shared between CG and NSScreen, so we can compare directly.
            guard
                cgRect.midX >= screen.frame.minX,
                cgRect.midX <= screen.frame.maxX
            else { return nil }

            return cgRect
        }

        return result
    }

    private func screenFrame(for statusView: NSView) -> CGRect? {
        guard let window = statusView.window else {
            return nil
        }

        let frameInWindow = statusView.convert(statusView.bounds, to: nil)
        return window.convertToScreen(frameInWindow)
    }
}
