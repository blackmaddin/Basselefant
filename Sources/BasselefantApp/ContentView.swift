import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            BasselefantVisualizer(
                feature: model.feature,
                style: model.visualStyle,
                dynamicsPreset: model.dynamicsPreset,
                dynamicsTuning: model.dynamicsTuning,
                audioMapProfile: model.audioMapProfile
            )
                .ignoresSafeArea()
        }
    }
}
