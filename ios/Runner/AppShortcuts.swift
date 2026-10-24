import AppIntents

@available(iOS 16.0, *)
struct LedgerLeafShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: IngestSmsIntent(),
            phrases: [
                "Log transaction in \(.applicationName)",
                "Record bank SMS in \(.applicationName)",
                "Parse transaction with \(.applicationName)"
            ],
            shortTitle: "Log SMS Transaction",
            systemImageName: "creditcard"
        )
    }
}
