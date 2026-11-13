import SwiftUI

@main
struct WaterReminderApp: App {
    @StateObject private var store = WaterStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
        }
    }
}
