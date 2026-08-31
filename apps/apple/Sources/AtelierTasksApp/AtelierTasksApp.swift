import AtelierAppUI
import AtelierCore
import SwiftUI

@main
struct AtelierTasksApplication: App {
    var body: some Scene {
        WindowGroup {
            AtelierAppShell(product: .tasks)
        }

        #if os(macOS)
        Settings {
            AtelierSettingsView(product: .tasks)
        }
        #endif
    }
}
