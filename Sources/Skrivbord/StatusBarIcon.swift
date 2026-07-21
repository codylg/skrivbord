import AppKit
import SwiftUI

enum StatusBarIcon {
    /// Loads the menu bar template image from the app bundle (Contents/Resources).
    /// Falls back to an SF Symbol when running via `swift run` without a real
    /// .app bundle (i.e. before Scripts/build-app.sh has been used).
    static func templateImage() -> Image {
        if let nsImage = Bundle.main.image(forResource: "MenuBarIcon") {
            nsImage.isTemplate = true
            return Image(nsImage: nsImage)
        }
        return Image(systemName: "chair.fill")
    }
}
