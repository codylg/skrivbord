import AppIntents
import Foundation
import os

private let logger = Logger(subsystem: "name.clg.Skrivbord", category: "automation")

enum HeightTarget {
    case sit
    case stand
}

enum SkrivbordAutomationError: Error, CustomLocalizedStringResourceConvertible {
    case notConnected

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notConnected:
            return "Skrivbord couldn't connect to the desk in time."
        }
    }
}

/// Shared app state reachable from contexts outside the normal SwiftUI view
/// hierarchy — App Intents (Shortcuts/Siri) and skrivbord:// URL handling are
/// both dispatched independently of the MenuBarExtra scene, so they need a
/// stable place to reach the live DeskBluetoothManager instance.
@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    let preferences: DeskPreferences
    let desk: DeskBluetoothManager

    private init() {
        let preferences = DeskPreferences()
        self.preferences = preferences
        self.desk = DeskBluetoothManager(preferences: preferences)
    }

    func performMove(to target: HeightTarget, connectTimeout: TimeInterval = 8) async throws {
        logger.debug("performMove(to: \(String(describing: target))) requested")
        let heightCM = target == .sit ? preferences.sitHeightCM : preferences.standHeightCM
        do {
            try await waitForConnection(timeout: connectTimeout)
        } catch {
            logger.error("performMove(to: \(String(describing: target))) failed: not connected within \(connectTimeout, format: .fixed(precision: 0))s")
            throw error
        }
        logger.debug("performMove(to: \(String(describing: target))) issuing moveTo(\(heightCM, format: .fixed(precision: 1)))")
        desk.moveTo(heightCM: heightCM)
    }

    private func waitForConnection(timeout: TimeInterval) async throws {
        guard desk.connectionState != .connected else { return }
        let deadline = Date().addingTimeInterval(timeout)
        while desk.connectionState != .connected {
            if Date() >= deadline {
                throw SkrivbordAutomationError.notConnected
            }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
    }
}
