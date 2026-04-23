import SwiftUI
import AVFoundation

struct InputPickerView: View {
    @ObservedObject var deviceManager: AudioDeviceManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Input Device")
                .font(.headline)

            if deviceManager.availableInputs.isEmpty {
                Text("No input devices found")
                    .foregroundStyle(.secondary)
            } else {
                Menu {
                    ForEach(deviceManager.availableInputs, id: \.uid) { port in
                        Button {
                            deviceManager.selectInput(port)
                        } label: {
                            HStack {
                                Text(port.portName)
                                if port.uid == deviceManager.selectedInput?.uid {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: iconName(for: deviceManager.selectedInput))
                        Text(deviceManager.selectedInput?.portName ?? "Select Input")
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                    }
                    .padding(12)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .foregroundStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func iconName(for port: AVAudioSessionPortDescription?) -> String {
        guard let portType = port?.portType else { return "mic" }
        switch portType {
        case .builtInMic:
            return "iphone"
        case .headsetMic:
            return "headphones"
        case .bluetoothHFP, .bluetoothLE:
            return "wave.3.right"
        default:
            return "mic"
        }
    }
}
