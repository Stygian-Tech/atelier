import AtelierAppUI
import AtelierCore
import SwiftUI

@main
struct AtelierMailApplication: App {
    var body: some Scene {
        WindowGroup {
            AtelierAppShell(product: .mail)
        }

        #if os(macOS)
        Settings {
            AtelierSettingsView(product: .mail)
        }
        #endif
    }
}
