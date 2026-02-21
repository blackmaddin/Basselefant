import AppKit
import SwiftUI

@main
struct BasselefantApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("Basselefant Visualizer", id: "visualizer") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 980, minHeight: 680)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .toolbar) {
                VisualizerMenuCommand()
            }
            CommandMenu("Settings") {
                ForEach(VisualDynamicsPreset.allCases) { preset in
                    Button {
                        model.setDynamicsPreset(preset)
                    } label: {
                        if model.dynamicsPreset == preset {
                            Label("Dynamics: \(preset.title)", systemImage: "checkmark")
                        } else {
                            Text("Dynamics: \(preset.title)")
                        }
                    }
                }
                Divider()
                ForEach(VisualAudioMapProfile.allCases) { map in
                    Button {
                        model.setAudioMapProfile(map)
                    } label: {
                        if model.audioMapProfile == map {
                            Label("Audio Map: \(map.title)", systemImage: "checkmark")
                        } else {
                            Text("Audio Map: \(map.title)")
                        }
                    }
                }
                Divider()
                Button(model.autoGainEnabled ? "Auto Gain: On" : "Auto Gain: Off") {
                    model.autoGainEnabled.toggle()
                }
                Button("Reset Auto Gain Profiles") {
                    model.resetAutoGainProfiles()
                }
                Divider()
                Button("Reset Dynamics Fine Tuning") {
                    model.resetDynamicsTuning()
                }
                Divider()
                Button(model.updateInProgress ? "Update laeuft..." : "Update jetzt installieren") {
                    model.runUpdateNowForDummies()
                }
                .disabled(model.updateInProgress)
                Button(model.autoUpdateEnabled ? "Auto Update: On" : "Auto Update: Off") {
                    model.setAutoUpdateEnabledForDummies(!model.autoUpdateEnabled)
                }
            }
            CommandMenu("Audio") {
                ForEach(RecognitionSourceMode.allCases) { mode in
                    Button {
                        model.setSourceMode(mode)
                    } label: {
                        if model.sourceMode == mode {
                            Label(mode.title, systemImage: "checkmark")
                        } else {
                            Text(mode.title)
                        }
                    }
                }

                Divider()
                Button("Refresh Microphones") { model.refreshAudioInputs() }
                if model.audioInputs.isEmpty {
                    Button("No microphones found") {}
                        .disabled(true)
                } else {
                    ForEach(model.audioInputs) { input in
                        Button {
                            model.selectAudioInput(id: input.id)
                        } label: {
                            let label = input.isDefault ? "\(input.name) (System)" : input.name
                            if model.selectedAudioInputID == input.id {
                                Label(label, systemImage: "checkmark")
                            } else {
                                Text(label)
                            }
                        }
                    }
                }

                Divider()
                Button("Track: \(model.track.title)") {}
                    .disabled(true)
                Button("Artist: \(model.track.artist)") {}
                    .disabled(true)
                Button("Detected: \(model.track.source.rawValue)") {}
                    .disabled(true)
                if model.directDiagnosticText.isEmpty == false {
                    Button("Direct Diagnostic: \(model.directDiagnosticText)") {}
                        .disabled(true)
                }
                Divider()
                Button("Request Spotify/Music Access") { model.requestDirectAccessPrompt() }
                Button("Open Automation Settings") { model.openAutomationSettings() }
            }
            CommandMenu("Displays") {
                Button("Refresh Displays") { model.refreshDisplays() }
                Button("Open Display Settings") { model.openDisplaySettings() }

                Divider()

                if model.displayTargets.isEmpty {
                    Button("No Display Targets Found") {}
                        .disabled(true)
                } else {
                    ForEach(model.displayTargets) { target in
                        Button("\(target.name) (\(target.size))\(target.isAirPlay ? " • AirPlay" : "")") {
                            model.presentOnDisplay(id: target.id)
                        }
                    }
                }

                if model.activeDisplayID != nil {
                    Divider()
                    Button("Stop External Output") { model.stopExternalPresentation() }
                }
            }
        }

        MenuBarExtra {
            MenuBarControls()
                .environmentObject(model)
        } label: {
            MenuBarElephantIcon()
                .frame(width: 20, height: 16)
                .accessibilityLabel("Basselefant")
        }
        .menuBarExtraStyle(.window)

        Settings {
            AppSettingsView()
                .environmentObject(model)
                .frame(width: 520, height: 420)
        }
    }
}

private struct MenuBarControls: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Show Visualizer") {
            openWindow(id: "visualizer")
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut("0", modifiers: [.command])

        Divider()

        Section("Visual Style") {
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
        }

        Section("Settings") {
            ForEach(VisualDynamicsPreset.allCases) { preset in
                Button {
                    model.setDynamicsPreset(preset)
                } label: {
                    if model.dynamicsPreset == preset {
                        Label("Dynamics: \(preset.title)", systemImage: "checkmark")
                    } else {
                        Text("Dynamics: \(preset.title)")
                    }
                }
            }
            Divider()
            ForEach(VisualAudioMapProfile.allCases) { map in
                Button {
                    model.setAudioMapProfile(map)
                } label: {
                    if model.audioMapProfile == map {
                        Label("Audio Map: \(map.title)", systemImage: "checkmark")
                    } else {
                        Text("Audio Map: \(map.title)")
                    }
                }
            }
            Button(model.autoGainEnabled ? "Auto Gain: On" : "Auto Gain: Off") {
                model.autoGainEnabled.toggle()
            }
            Button("Reset Auto Gain Profiles") { model.resetAutoGainProfiles() }
            Button("Reset Fine Tuning") { model.resetDynamicsTuning() }
            Divider()
            Button(model.updateInProgress ? "Update laeuft..." : "Update jetzt installieren") {
                model.runUpdateNowForDummies()
            }
            .disabled(model.updateInProgress)
            Button(model.autoUpdateEnabled ? "Auto Update: On" : "Auto Update: Off") {
                model.setAutoUpdateEnabledForDummies(!model.autoUpdateEnabled)
            }
        }

        Section("Audio Source") {
            ForEach(RecognitionSourceMode.allCases) { mode in
                Button {
                    model.setSourceMode(mode)
                } label: {
                    if model.sourceMode == mode {
                        Label(mode.title, systemImage: "checkmark")
                    } else {
                        Text(mode.title)
                    }
                }
            }
        }

        Section("Microphones") {
            Button("Refresh Microphones") { model.refreshAudioInputs() }
            if model.audioInputs.isEmpty {
                Text("Keine Mikrofone gefunden")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.audioInputs) { input in
                    Button {
                        model.selectAudioInput(id: input.id)
                    } label: {
                        let label = input.isDefault ? "\(input.name) (System)" : input.name
                        if model.selectedAudioInputID == input.id {
                            Label(label, systemImage: "checkmark")
                        } else {
                            Text(label)
                        }
                    }
                }
            }
        }

        Section("Recognition") {
            Text(model.track.title)
            Text(model.track.artist)
                .foregroundStyle(.secondary)
            Text("Quelle: \(model.track.source.rawValue)")
                .foregroundStyle(.secondary)
            if model.directDiagnosticText.isEmpty == false {
                Text(model.directDiagnosticText)
                    .foregroundStyle(.secondary)
            }
            Button("Request Spotify/Music Access") {
                model.requestDirectAccessPrompt()
            }
            Button("Open Automation Settings") {
                model.openAutomationSettings()
            }
        }

        Section("Displays / AirPlay") {
            Button("Refresh Displays") { model.refreshDisplays() }
            Button("Open Display Settings") { model.openDisplaySettings() }
            Divider()
            ForEach(model.displayTargets) { target in
                Button("\(target.name) (\(target.size))\(target.isAirPlay ? " • AirPlay" : "")") {
                    model.presentOnDisplay(id: target.id)
                }
            }
            if model.activeDisplayID != nil {
                Divider()
                Button("Stop External Output") { model.stopExternalPresentation() }
            }
        }

        Divider()
        Button("Quit") { NSApplication.shared.terminate(nil) }
    }
}

private struct VisualizerMenuCommand: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Show Visualizer") {
            openWindow(id: "visualizer")
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut("0", modifiers: [.command])
    }
}

private struct AppSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section("Dynamics Preset") {
                Picker("Preset", selection: Binding(
                    get: { model.dynamicsPreset },
                    set: { model.setDynamicsPreset($0) }
                )) {
                    ForEach(VisualDynamicsPreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Audio Mapping") {
                Picker("Audio Map", selection: Binding(
                    get: { model.audioMapProfile },
                    set: { model.setAudioMapProfile($0) }
                )) {
                    ForEach(VisualAudioMapProfile.allCases) { map in
                        Text(map.title).tag(map)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Auto Gain per Source", isOn: $model.autoGainEnabled)

                Button("Reset Auto Gain Profiles") {
                    model.resetAutoGainProfiles()
                }
            }

            Section("Updates (Dummy Mode)") {
                Toggle("Auto Update (alle 6h)", isOn: Binding(
                    get: { model.autoUpdateEnabled },
                    set: { model.setAutoUpdateEnabledForDummies($0) }
                ))
                Button(model.updateInProgress ? "Update laeuft..." : "Jetzt updaten und neu starten") {
                    model.runUpdateNowForDummies()
                }
                .disabled(model.updateInProgress)
            }

            Section("Fine Tuning (0-100, 50 = neutral)") {
                sliderRow(title: "Camera Drift", value: binding(\.cameraDrift))
                sliderRow(title: "Camera Beat", value: binding(\.cameraBeat))
                sliderRow(title: "Elephant Dance", value: binding(\.elephantDance))
                sliderRow(title: "Breath Speed", value: binding(\.breathSpeed))
                sliderRow(title: "Layer 2 Depth", value: binding(\.layer2Depth))
            }

            Section("Actions") {
                Button("Reset Fine Tuning") {
                    model.resetDynamicsTuning()
                }
            }
        }
        .padding(14)
    }

    private func binding(_ keyPath: WritableKeyPath<VisualDynamicsTuning, Double>) -> Binding<Double> {
        Binding<Double>(
            get: { model.dynamicsTuning[keyPath: keyPath] },
            set: { model.dynamicsTuning[keyPath: keyPath] = $0 }
        )
    }

    @ViewBuilder
    private func sliderRow(title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
                .frame(width: 140, alignment: .leading)
            Slider(value: value, in: 0...100, step: 1)
            Text("\(Int(value.wrappedValue))")
                .monospacedDigit()
                .frame(width: 36, alignment: .trailing)
        }
    }
}

private struct MenuBarElephantIcon: View {
    var body: some View {
        ZStack {
            MenuBarElephantShape()
                .fill(.primary)
            MenuBarElephantShape()
                .stroke(.primary.opacity(0.95), style: StrokeStyle(lineWidth: 0.8, lineJoin: .round))
        }
    }
}

private struct MenuBarElephantShape: Shape {
    func path(in rect: CGRect) -> Path {
        func p(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }

        let points: [CGPoint] = [
            p(0.5, 0.84), p(0.34, 0.72), p(0.17, 0.78), p(0.04, 0.62), p(0.08, 0.38), p(0.24, 0.24),
            p(0.39, 0.28), p(0.45, 0.42), p(0.44, 0.26), p(0.39, 0.08), p(0.5, 0.03), p(0.61, 0.08),
            p(0.56, 0.26), p(0.55, 0.42), p(0.61, 0.28), p(0.76, 0.24), p(0.92, 0.38), p(0.96, 0.62),
            p(0.83, 0.78), p(0.66, 0.72)
        ]

        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}
