import SwiftUI

struct ExternalDisplayView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
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
