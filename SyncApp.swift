import SwiftUI

@main
struct SyncApp: App {
    @StateObject private var store = ShiftStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
