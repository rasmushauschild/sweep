import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let hider = MenuBarHider()
    private let statusMenu = NSMenu()
    private var spacerItem: NSStatusItem?
    private var statusItem: NSStatusItem?
    private var statusView: MenuBarStatusView?

    func applicationDidFinishLaunching(_ notification: Notification) {
        hider.onStateChange = { [weak self] in
            self?.updateStatusItemAppearance()
        }
        configureMenu()
        configureStatusItem()
        // NSStatusBar grows left as items are added, so the spacer must be
        // created after the visible Sweep icon to sit on its left.
        configureSpacerItem()
        updateStatusItemAppearance()
    }

    private func configureMenu() {
        let quitItem = statusMenu.addItem(
            withTitle: "Quit Sweep",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
    }

    private func configureSpacerItem() {
        let item = NSStatusBar.system.statusItem(withLength: 0)
        // Empty behavior: the invisible spacer must never silently quit Sweep
        // if macOS culls it for space, and the user can't intentionally cmd-drag
        // an item they can't see.
        item.behavior = []
        item.view = MenuBarSpacerView(length: 0)
        spacerItem = item
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.behavior = [.terminationOnRemoval]
        // Bumped when menu-bar chrome changes so macOS doesn't restore stale Control Center state.
        item.autosaveName = "com.xolo.sweep.status-item.circle"
        statusItem = item

        let view = MenuBarStatusView()
        view.onActivate = { [weak self] event in
            self?.handleStatusItemClick(event)
        }
        item.view = view
        statusView = view
    }

    private func updateStatusItemAppearance() {
        guard let view = statusView else {
            return
        }

        view.updateAppearance(isHiding: hider.isHiding)
        view.toolTip = hider.isHiding
            ? "Show the menu bar items to the left"
            : "Hide the menu bar items to the left"
    }

    private func handleStatusItemClick(_ event: NSEvent) {
        let isSecondaryClick = event.type == .rightMouseUp
            || event.modifierFlags.contains(.control)

        if isSecondaryClick {
            guard let statusView else {
                return
            }

            statusMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: statusView.bounds.height), in: statusView)
            return
        }

        guard let spacerItem, let statusView else {
            return
        }

        hider.toggle(spacerItem: spacerItem, relativeTo: statusView)
    }

    @objc
    private func quit() {
        NSApp.terminate(nil)
    }
}
