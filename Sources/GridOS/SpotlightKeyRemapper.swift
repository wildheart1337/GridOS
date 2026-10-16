import Foundation

/// Turns the Spotlight key on Apple keyboards (the magnifier on the F4 key) into a plain F4 key
/// press, which GridOS's F4 shortcut then receives.
///
/// The mapping goes through `hidutil`, the system's user key-remapping facility. It needs no
/// special permission, applies to the current login session, and is cleared on restart or when
/// GridOS quits, so the Spotlight key returns to normal whenever GridOS is not running.
enum SpotlightKeyRemapper {
    /// HID Consumer page, usage 0x221 (AC Search): what the Spotlight key sends.
    private static let spotlightKeyUsage: UInt64 = 0xC0000_0221
    /// HID Keyboard page, usage 0x3D: F4.
    private static let f4KeyUsage: UInt64 = 0x7_0000_003D

    static func apply(enabled: Bool) {
        let mapping = enabled
            ? "[{\"HIDKeyboardModifierMappingSrc\":\(spotlightKeyUsage),"
                + "\"HIDKeyboardModifierMappingDst\":\(f4KeyUsage)}]"
            : "[]"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        process.arguments = ["property", "--set", "{\"UserKeyMapping\":\(mapping)}"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            if !enabled {
                // Restore the Spotlight key before the process exits.
                process.waitUntilExit()
            }
        } catch {
            Log.hotKey.error("Could not update the Spotlight key mapping: \(error)")
        }
    }
}
