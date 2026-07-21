import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var desk: DeskBluetoothManager
    @EnvironmentObject private var preferences: DeskPreferences
    @StateObject private var launchAtLogin = LaunchAtLoginManager()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        styledText(heightLabel, monospaced: true)
        statusText
        if desk.connectionState == .scanning {
            hintText("Ensure your desk is not connected to\nanother device, then enter pairing mode.")
        }

        Divider()

        Button {
            desk.moveTo(heightCM: preferences.sitHeightCM)
        } label: {
            sitStandLabel("Sit", valueCM: preferences.sitHeightCM)
        }
        .keyboardShortcut("1", modifiers: .command)
        .disabled(desk.connectionState != .connected)

        Button {
            desk.moveTo(heightCM: preferences.standHeightCM)
        } label: {
            sitStandLabel("Stand", valueCM: preferences.standHeightCM)
        }
        .keyboardShortcut("2", modifiers: .command)
        .disabled(desk.connectionState != .connected)

        Divider()

        Button("Save Current Height as Sit") {
            if let height = desk.currentHeightCM { preferences.sitHeightCM = height }
        }
        .disabled(desk.currentHeightCM == nil)

        Button("Save Current Height as Stand") {
            if let height = desk.currentHeightCM { preferences.standHeightCM = height }
        }
        .disabled(desk.currentHeightCM == nil)

        Divider()

        Toggle(
            "Launch at Login",
            isOn: Binding(
                get: { launchAtLogin.isEnabled },
                set: { launchAtLogin.setEnabled($0) }
            )
        )

        Divider()

        Button("Quit Skrivbord") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }

    private var heightLabel: String {
        desk.currentHeightCM.map { "\(fmt($0)) cm" } ?? "-- cm"
    }

    @ViewBuilder
    private var statusText: some View {
        switch desk.connectionState {
        case .connected:
            styledText("Connected", color: statusColor(light: Color(red: 0.0, green: 0.45, blue: 0.0), dark: .green))
        case .connecting:
            styledText("Connecting…", color: statusColor(light: Color(red: 0.55, green: 0.42, blue: 0.0), dark: .yellow))
        case .scanning:
            styledText("Searching…", color: statusColor(light: Color(red: 0.55, green: 0.42, blue: 0.0), dark: .yellow))
        case .disconnected:
            styledText("Disconnected", color: statusColor(light: Color(red: 0.7, green: 0.0, blue: 0.0), dark: .red))
        case .bluetoothUnavailable(let message):
            styledText(message, color: statusColor(light: Color(red: 0.7, green: 0.0, blue: 0.0), dark: .red))
        }
    }

    private func statusColor(light: Color, dark: Color) -> Color {
        colorScheme == .light ? light : dark
    }

    private func fmt(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    /// Builds Text from an AttributedString rather than applying view modifiers
    /// (.foregroundStyle/.fontDesign) directly to Text. MenuBarExtra's `.menu`
    /// style bridges menu item titles to NSMenuItem.attributedTitle, which only
    /// reliably picks up styling carried on the AttributedString itself.
    private func styledText(_ string: String, color: Color? = nil, monospaced: Bool = false) -> Text {
        var attributed = AttributedString(string)
        if let color {
            attributed.foregroundColor = color
        }
        if monospaced {
            attributed.font = .system(.body, design: .monospaced)
        }
        return Text(attributed)
    }

    private func hintText(_ string: String) -> Text {
        var attributed = AttributedString(string)
        attributed.foregroundColor = .secondary
        attributed.font = .system(size: 11)
        return Text(attributed)
    }

    private func sitStandLabel(_ prefix: String, valueCM: Double) -> Text {
        let prefixPart = AttributedString("\(prefix)  ")
        var valuePart = AttributedString("\(fmt(valueCM)) cm")
        valuePart.font = .system(size: 12, design: .monospaced)
        valuePart.foregroundColor = .secondary
        return Text(prefixPart + valuePart)
    }
}
