import SwiftUI

@main
struct BasselefantiOSApp: App {
    @StateObject private var model = IOSAppModel()

    var body: some Scene {
        WindowGroup {
            IOSContentView()
                .environmentObject(model)
        }
    }
}
