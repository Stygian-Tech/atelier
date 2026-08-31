import AtelierAppUI
import AtelierCore
import SwiftUI

@main
struct AtelierNotesApplication: App {
    var body: some Scene {
        WindowGroup {
            AtelierAppShell(product: .notes)
        }

        #if os(macOS)
        Settings {
            AtelierSettingsView(product: .notes)
        }
        #endif
    }
}
