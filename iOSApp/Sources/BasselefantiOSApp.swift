import SwiftUI

@main
struct BasselefantiOSApp: App {
    @StateObject private var model = IOSAppModel()

    var body: some Scene {
        WindowGroup {
            IOSFullscreenHost {
                IOSContentView()
                    .environmentObject(model)
                    .ignoresSafeArea(.all, edges: .all)
                    .persistentSystemOverlays(.hidden)
            }
            .ignoresSafeArea(.all, edges: .all)
        }
    }
}
