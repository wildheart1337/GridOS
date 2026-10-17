import AppKit
import Darwin

/// Adjustable background blur for a window, through the WindowServer call that terminal apps
/// such as iTerm2 use for their blurred transparent backgrounds. AppKit has no public way to
/// change the blur radius. The symbols are looked up at run time, so a future macOS that drops
/// them simply reports failure and the caller falls back to the standard material.
enum WindowBlur {
    private typealias MainConnectionFunction = @convention(c) () -> UInt32
    private typealias SetBlurFunction = @convention(c) (UInt32, Int32, Int32) -> Int32

    /// Sets the blur radius behind `window` (0 turns it off). Returns false when unsupported.
    @MainActor
    @discardableResult
    static func setRadius(_ radius: Int, for window: NSWindow) -> Bool {
        guard window.windowNumber > 0,
              let handle = dlopen(nil, RTLD_LAZY),
              let mainSymbol = dlsym(handle, "CGSMainConnectionID"),
              let blurSymbol = dlsym(handle, "CGSSetWindowBackgroundBlurRadius") else {
            return false
        }
        let mainConnection = unsafeBitCast(mainSymbol, to: MainConnectionFunction.self)
        let setBlur = unsafeBitCast(blurSymbol, to: SetBlurFunction.self)
        return setBlur(mainConnection(), Int32(window.windowNumber), Int32(radius)) == 0
    }
}
