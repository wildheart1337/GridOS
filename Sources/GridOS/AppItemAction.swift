import Foundation

/// Commands offered by an application's context menu in the launcher.
enum AppItemAction: Int {
    case open = 1
    case showInFinder
    case rename
    case hide
    case addToDock
    case uninstall
}
