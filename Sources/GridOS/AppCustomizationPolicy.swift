import Foundation

/// Applies user customizations — hidden applications and custom names — to the catalog before it
/// is ordered and presented. The layout database is never changed: hidden applications keep
/// their stored position and reappear there when they are shown again.
enum AppCustomizationPolicy {
    static func apply(
        to items: [LunchpadItem],
        hiddenIdentifiers: Set<String>,
        customNames: [String: String]
    ) -> [LunchpadItem] {
        guard !hiddenIdentifiers.isEmpty || !customNames.isEmpty else { return items }

        func customized(_ app: AppItem) -> AppItem? {
            guard !hiddenIdentifiers.contains(app.identifier) else { return nil }
            guard let customName = customNames[app.identifier], customName != app.name else {
                return app
            }
            // The original name stays searchable after a rename.
            var aliases = app.searchAliases
            if !aliases.contains(where: { $0.caseInsensitiveCompare(app.name) == .orderedSame }) {
                aliases.insert(app.name, at: 0)
            }
            return AppItem(
                identifier: app.identifier,
                bundleIdentifier: app.bundleIdentifier,
                name: customName,
                url: app.url,
                creationDate: app.creationDate,
                modificationDate: app.modificationDate,
                searchAliases: aliases
            )
        }

        return items.compactMap { item -> LunchpadItem? in
            switch item {
            case .app(let app):
                return customized(app).map(LunchpadItem.app)
            case .folder(let folder):
                let apps = folder.apps.compactMap(customized)
                // A folder whose members are all hidden would open onto an empty page.
                guard !apps.isEmpty else { return nil }
                return .folder(AppFolder(
                    identifier: folder.identifier,
                    name: folder.name,
                    apps: apps,
                    isSystem: folder.isSystem
                ))
            }
        }
    }
}
