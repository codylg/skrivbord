import AppKit
import os

private let logger = Logger(subsystem: "name.clg.Skrivbord", category: "automation")

/// MenuBarExtra has no window content to attach a SwiftUI `.onOpenURL`
/// modifier to, so skrivbord:// URLs are handled via the standard AppKit
/// hook instead.
final class SkrivbordAppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            handle(url)
        }
    }

    private func handle(_ url: URL) {
        logger.debug("Received URL: \(url.absoluteString)")
        guard url.scheme?.lowercased() == "skrivbord" else { return }
        switch url.host?.lowercased() {
        case "sit":
            Task { try? await AppEnvironment.shared.performMove(to: .sit) }
        case "stand":
            Task { try? await AppEnvironment.shared.performMove(to: .stand) }
        default:
            logger.debug("Unrecognized URL host: \(url.host ?? "nil")")
        }
    }
}
