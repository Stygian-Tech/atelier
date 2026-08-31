import AtelierAppUI
import AtelierCore
import SwiftUI

@main
struct AtelierCalendarApplication: App {
    var body: some Scene {
        WindowGroup {
            AtelierAppShell(product: .calendar)
        }

        #if os(macOS)
        Settings {
            AtelierSettingsView(product: .calendar)
        }
        #endif
    }
}
