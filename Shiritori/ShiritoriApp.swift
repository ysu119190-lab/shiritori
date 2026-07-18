import SwiftUI

@main
struct ShiritoriApp: App {
    @StateObject private var game = ShiritoriGame()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(game)
        }
    }
}
