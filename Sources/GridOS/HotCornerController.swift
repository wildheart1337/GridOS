import AppKit

/// Opens GridOS when the pointer rests briefly in the configured screen corner.
///
/// Polling `NSEvent.mouseLocation` needs no Accessibility or Input Monitoring permission and costs
/// almost nothing at this rate. The action fires once per visit; the pointer must leave the
/// corner before it can fire again.
@MainActor
final class HotCornerController {
    private static let pollInterval: TimeInterval = 0.05
    private static let dwell: TimeInterval = 0.15
    private static let cornerSize: CGFloat = 4

    private let action: () -> Void
    private var corner: HotCorner = .none
    private var timer: Timer?
    private var enteredAt: TimeInterval?
    private var hasFiredForCurrentVisit = false

    init(action: @escaping () -> Void) {
        self.action = action
    }

    func setCorner(_ newCorner: HotCorner) {
        corner = newCorner
        enteredAt = nil
        hasFiredForCurrentVisit = false
        if newCorner == .none {
            timer?.invalidate()
            timer = nil
        } else if timer == nil {
            let timer = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
                // Scheduled on the main run loop below.
                MainActor.assumeIsolated {
                    self?.poll()
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
    }

    private func poll() {
        let location = NSEvent.mouseLocation
        guard isInCorner(location) else {
            enteredAt = nil
            hasFiredForCurrentVisit = false
            return
        }
        guard !hasFiredForCurrentVisit else { return }

        let now = ProcessInfo.processInfo.systemUptime
        guard let enteredAt else {
            self.enteredAt = now
            return
        }
        if now - enteredAt >= Self.dwell {
            hasFiredForCurrentVisit = true
            action()
        }
    }

    private func isInCorner(_ point: NSPoint) -> Bool {
        // Inclusive bounds: the pointer can rest exactly on a screen's top or right edge.
        guard let screen = NSScreen.screens.first(where: {
            point.x >= $0.frame.minX && point.x <= $0.frame.maxX
                && point.y >= $0.frame.minY && point.y <= $0.frame.maxY
        }) else {
            return false
        }
        let frame = screen.frame
        let size = Self.cornerSize
        let nearLeft = point.x <= frame.minX + size
        let nearRight = point.x >= frame.maxX - size - 1
        let nearBottom = point.y <= frame.minY + size
        let nearTop = point.y >= frame.maxY - size - 1

        switch corner {
        case .none: return false
        case .topLeft: return nearTop && nearLeft
        case .topRight: return nearTop && nearRight
        case .bottomLeft: return nearBottom && nearLeft
        case .bottomRight: return nearBottom && nearRight
        }
    }
}
