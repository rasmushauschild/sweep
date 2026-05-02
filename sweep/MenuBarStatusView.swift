import AppKit

@MainActor
final class MenuBarStatusView: NSView {
    static let compactLength: CGFloat = 28

    var onActivate: ((NSEvent) -> Void)?

    private let imageView = NSImageView()

    override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(x: 0, y: 0, width: Self.compactLength, height: NSStatusBar.system.thickness))

        autoresizesSubviews = true

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyDown
        addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            imageView.widthAnchor.constraint(equalToConstant: 18),
            imageView.heightAnchor.constraint(equalToConstant: 18)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateAppearance(isHiding: Bool) {
        let symbolName = isHiding
            ? "line.3.horizontal.decrease.circle.fill"
            : "line.3.horizontal.decrease.circle"

        imageView.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: "Toggle hidden menu bar items"
        )
        imageView.image?.isTemplate = true
    }

    override func mouseUp(with event: NSEvent) {
        onActivate?(event)
    }

    override func rightMouseUp(with event: NSEvent) {
        onActivate?(event)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }
}
