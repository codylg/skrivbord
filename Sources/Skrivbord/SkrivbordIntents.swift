import AppIntents

struct MoveToSitHeightIntent: AppIntent {
    static var title: LocalizedStringResource = "Move to Sit Height"
    static var description = IntentDescription("Moves the desk to your saved sit height.")

    @MainActor
    func perform() async throws -> some IntentResult {
        try await AppEnvironment.shared.performMove(to: .sit)
        return .result()
    }
}

struct MoveToStandHeightIntent: AppIntent {
    static var title: LocalizedStringResource = "Move to Stand Height"
    static var description = IntentDescription("Moves the desk to your saved stand height.")

    @MainActor
    func perform() async throws -> some IntentResult {
        try await AppEnvironment.shared.performMove(to: .stand)
        return .result()
    }
}

struct SkrivbordShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: MoveToSitHeightIntent(),
            phrases: [
                "Sit with \(.applicationName)",
                "Move \(.applicationName) to sit height"
            ],
            shortTitle: "Sit",
            systemImageName: "chair"
        )
        AppShortcut(
            intent: MoveToStandHeightIntent(),
            phrases: [
                "Stand with \(.applicationName)",
                "Move \(.applicationName) to stand height"
            ],
            shortTitle: "Stand",
            systemImageName: "figure.stand"
        )
    }
}
