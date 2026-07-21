import SwiftUI

@main
struct SkrivbordApp: App {
    @NSApplicationDelegateAdaptor(SkrivbordAppDelegate.self) private var appDelegate
    @StateObject private var preferences: DeskPreferences
    @StateObject private var desk: DeskBluetoothManager

    init() {
        _preferences = StateObject(wrappedValue: AppEnvironment.shared.preferences)
        _desk = StateObject(wrappedValue: AppEnvironment.shared.desk)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(desk)
                .environmentObject(preferences)
        } label: {
            StatusBarIcon.templateImage()
        }
        .menuBarExtraStyle(.menu)
    }
}
