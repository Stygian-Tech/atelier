import AtelierAppUI
import AtelierCore
import SwiftUI

@main
struct AtelierApplication: App {
    var body: some Scene {
        WindowGroup {
            AtelierAppShell(product: .atelier)
        }

        #if os(macOS)
        Settings {
            AtelierSettingsView(product: .atelier)
        }
        #endif
    }
}
