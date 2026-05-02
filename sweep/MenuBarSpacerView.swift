import AppKit

@MainActor
final class MenuBarSpacerView: NSView {
    init(length: CGFloat) {
        super.init(frame: NSRect(x: 0, y: 0, width: length, height: NSStatusBar.system.thickness))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateLength(_ length: CGFloat) {
        frame.size.width = length
        needsLayout = true
        needsDisplay = true
    }

    override var isOpaque: Bool {
        false
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
