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

        guard let spacerView = spacerItem.view,
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
                }),
            let infoList = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID
            ) as? [[String: Any]]
        else {
            return nil
        }

        let ourPID = Int32(ProcessInfo.processInfo.processIdentifier)
        // Anchor to the Sweep window's CG bounds so X matches neighbor rects (AppKit's
        // convertToScreen can sit tens of points off from CGWindowList for status items).
        let sweepLeft: CGFloat = {
            if let n = statusView.window?.windowNumber,
               let r = cgBounds(forWindowNumber: n, in: infoList)
            {
                return r.minX
            }
            return statusViewFrame.minX
        }()

        let edgeSlop: CGFloat = 28
        let seamReach: CGFloat = 56
        let inclusionRight = sweepLeft + edgeSlop
        let seamLo = sweepLeft - seamReach
        let seamHi = sweepLeft + edgeSlop

        let leftFrames = menuBarItemRects(onScreen: screen, infoList: infoList, excludingOwnerPID: ourPID)
            .filter { rect in
                rect.minX < inclusionRight
                    || (rect.maxX > seamLo && rect.minX < seamHi)
            }

        guard let minX = leftFrames.map(\.minX).min() else {
            return nil
        }

        guard sweepLeft > minX else {
            return nil
        }

        // Belt-and-suspenders: refuse a width that would push Sweep itself or the
        // active app's menus off-screen.
        let safetyFloor: CGFloat = 200
        // Extra pt absorb menu-bar layout slack so the item flush with our cluster still clears.
        let layoutFudge: CGFloat = 12
        let raw = sweepLeft - minX + layoutFudge
        let cap = max(0, sweepLeft - screen.frame.minX - safetyFloor)
        return min(raw, cap)
    }

    private func cgBounds(forWindowNumber windowNumber: Int, in infoList: [[String: Any]]) -> CGRect? {
        for dict in infoList {
            let num: Int? = (dict[kCGWindowNumber as String] as? NSNumber).map(\.intValue)
                ?? (dict[kCGWindowNumber as String] as? Int)
            guard num == windowNumber else { continue }

            guard
                let boundsDict = dict[kCGWindowBounds as String] as? NSDictionary,
                let cgRect = CGRect(dictionaryRepresentation: boundsDict)
            else { continue }

            return cgRect
        }
        return nil
    }

    private func menuBarItemRects(
        onScreen screen: NSScreen,
        infoList: [[String: Any]],
        excludingOwnerPID ourPID: Int32?
    ) -> [CGRect] {
        // CG Y = 0 is the top of the main screen; convert to the top edge of
        // `screen` in CG coords.
        let mainScreenMaxY = NSScreen.screens.first?.frame.maxY ?? screen.frame.maxY
        let screenTopCGY = mainScreenMaxY - screen.frame.maxY

        return infoList.compactMap { dict -> CGRect? in
            if let ourPID {
                let owner = (dict[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value
                    ?? (dict[kCGWindowOwnerPID as String] as? Int32)
                if owner == ourPID {
                    return nil
                }
            }

            guard
                let boundsDict = dict[kCGWindowBounds as String] as? NSDictionary,
                let cgRect = CGRect(dictionaryRepresentation: boundsDict)
            else { return nil }

            // Anchored at the top of the menu bar.
            guard cgRect.minY <= screenTopCGY + 2 else { return nil }
            // Shape of a menu bar item, not a giant overlay or floating panel.
            // macOS 26's menu bar is ~39pt tall; older macOS is ~22pt.
            guard cgRect.height >= 14, cgRect.height <= 50 else { return nil }
            guard cgRect.width >= 8, cgRect.width <= 300 else { return nil }
            // X is shared between CG and NSScreen, so we can compare directly.
            guard
                cgRect.midX >= screen.frame.minX,
                cgRect.midX <= screen.frame.maxX
            else { return nil }

            return cgRect
        }
    }

    private func screenFrame(for statusView: NSView) -> CGRect? {
        guard let window = statusView.window else {
            return nil
        }

        let frameInWindow = statusView.convert(statusView.bounds, to: nil)
        return window.convertToScreen(frameInWindow)
    }
}
