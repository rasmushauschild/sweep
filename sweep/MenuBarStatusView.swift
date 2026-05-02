import AppKit

@MainActor
final class MenuBarStatusView: NSView {
    private static let iconSide: CGFloat = 14
    private static let horizontalPadding: CGFloat = 3

    var onActivate: ((NSEvent) -> Void)?

    private let imageView = NSImageView()

    override var intrinsicContentSize: NSSize {
        NSSize(
            width: Self.horizontalPadding * 2 + Self.iconSide,
            height: NSStatusBar.system.thickness
        )
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        translatesAutoresizingMaskIntoConstraints = false
        autoresizesSubviews = true
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyDown
        imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: Self.iconSide),
            imageView.heightAnchor.constraint(equalToConstant: Self.iconSide)
        ])

        applySymbol(isHiding: false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateAppearance(isHiding: Bool) {
        applySymbol(isHiding: isHiding)
        invalidateIntrinsicContentSize()
    }

    private func applySymbol(isHiding: Bool) {
        let name = isHiding ? "circle.fill" : "circle"
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: "Toggle hidden menu bar items") else {
            return
        }
        image.isTemplate = true
        imageView.image = image
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
