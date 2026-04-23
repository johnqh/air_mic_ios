import SwiftUI

struct ContentView: View {
    @StateObject private var engineManager = AudioEngineManager()
    @StateObject private var deviceManager = AudioDeviceManager()
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 24) {
            Text("AirMic")
                .font(.largeTitle.bold())
                .padding(.top, 20)

            // Route display
            routeDisplay

            Divider()

            // Input picker
            InputPickerView(deviceManager: deviceManager)

            // Output picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Output Device")
                    .font(.headline)
                OutputRouteButton()
                    .frame(height: 44)
                Text(deviceManager.currentOutputName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // Level meter
            VStack(alignment: .leading, spacing: 8) {
                Text("Audio Level")
                    .font(.headline)
                LevelMeterView(level: engineManager.audioLevel)
                    .frame(height: 20)
            }

            // Gain slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Gain")
                        .font(.headline)
                    Spacer()
                    Text("\(Int(engineManager.gain * 100))%")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $engineManager.gain, in: 0...2, step: 0.05)
            }

            Spacer()

            // Start/Stop button
            Button(action: toggleAudio) {
                Text(engineManager.isRunning ? "Stop" : "Start")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(engineManager.isRunning ? Color.red : Color.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 24)
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    private var routeDisplay: some View {
        HStack {
            VStack {
                Image(systemName: "mic.fill")
                    .font(.title3)
                Text(deviceManager.selectedInput?.portName ?? "None")
                    .font(.caption)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)

            Image(systemName: "arrow.right")
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.title3)
                Text(deviceManager.currentOutputName)
                    .font(.caption)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func toggleAudio() {
        if engineManager.isRunning {
            engineManager.stop()
        } else {
            do {
                try engineManager.start()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
