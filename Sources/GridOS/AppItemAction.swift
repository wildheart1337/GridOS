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

/// Where "Move to" sends an application.
enum AppMoveDestination: Equatable {
    /// Out of its folder, back to the main grid.
    case root
    /// Into an existing folder, by identifier.
    case folder(String)
    /// Into a new folder created for it.
    case newFolder
}

/// A menu item's payload for a move command.
final class AppMoveRequest: NSObject {
    let appIdentifier: String
    let destination: AppMoveDestination

    init(appIdentifier: String, destination: AppMoveDestination) {
        self.appIdentifier = appIdentifier
        self.destination = destination
    }
}
