import SwiftUI

struct IOSContentView: View {
    @EnvironmentObject private var model: IOSAppModel
    @State private var controlsVisible = true

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                let landscape = proxy.size.width > proxy.size.height
                BasselefantVisualizer(
                    feature: model.feature,
                    style: model.visualStyle,
                    dynamicsPreset: model.dynamicsPreset,
                    dynamicsTuning: model.dynamicsTuning,
                    audioMapProfile: model.audioMapProfile
                )
                .ignoresSafeArea()

                VStack(spacing: 10) {
                    topBar
                    Spacer()
                    if controlsVisible {
                        controlsPanel(landscape: landscape)
                    }
                }
                .padding(12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(.black)
        .ignoresSafeArea(.container, edges: .all)
        .persistentSystemOverlays(.hidden)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Text(model.statusText)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.black.opacity(0.35), in: Capsule())
                .foregroundStyle(.white)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    controlsVisible.toggle()
                }
            } label: {
                Image(systemName: controlsVisible ? "slider.horizontal.3" : "slider.horizontal.below.rectangle")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.black.opacity(0.35), in: Circle())
            }
        }
    }

    @ViewBuilder
    private func controlsPanel(landscape: Bool) -> some View {
        Group {
            if landscape {
                HStack(spacing: 10) {
                    styleMenu
                    dynamicsMenu
                    mapMenu
                    Toggle("Auto Gain", isOn: $model.autoGainEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
            } else {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        styleMenu
                        dynamicsMenu
                    }
                    HStack(spacing: 10) {
                        mapMenu
                        Toggle("Auto Gain", isOn: $model.autoGainEnabled)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var styleMenu: some View {
        Menu {
            ForEach(VisualStyle.allCases) { style in
                Button {
                    model.visualStyle = style
                } label: {
                    if model.visualStyle == style {
                        Label(style.title, systemImage: "checkmark")
                    } else {
                        Text(style.title)
                    }
                }
            }
        } label: {
            Text("Style")
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.white.opacity(0.14), in: Capsule())
                .foregroundStyle(.white)
        }
    }

    private var dynamicsMenu: some View {
        Menu {
            ForEach(VisualDynamicsPreset.allCases) { preset in
                Button {
                    model.dynamicsPreset = preset
                } label: {
                    if model.dynamicsPreset == preset {
                        Label(preset.title, systemImage: "checkmark")
                    } else {
                        Text(preset.title)
                    }
                }
            }
        } label: {
            Text("Dynamics")
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.white.opacity(0.14), in: Capsule())
                .foregroundStyle(.white)
        }
    }

    private var mapMenu: some View {
        Menu {
            ForEach(VisualAudioMapProfile.allCases) { profile in
                Button {
                    model.audioMapProfile = profile
                } label: {
                    if model.audioMapProfile == profile {
                        Label(profile.title, systemImage: "checkmark")
                    } else {
                        Text(profile.title)
                    }
                }
            }
        } label: {
            Text("Audio Map")
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.white.opacity(0.14), in: Capsule())
                .foregroundStyle(.white)
        }
    }
}
