import AVFoundation
import Combine

@MainActor
final class AudioDeviceManager: ObservableObject {
    private let session = AVAudioSession.sharedInstance()

    @Published var availableInputs: [AVAudioSessionPortDescription] = []
    @Published var selectedInput: AVAudioSessionPortDescription?
    @Published var currentOutputName: String = "Default"

    private var cancellables = Set<AnyCancellable>()

    init() {
        observeRouteChanges()
        refreshDevices()
        // Auto-select first input on launch
        if selectedInput == nil, let first = availableInputs.first {
            selectInput(first)
        }
    }

    func refreshDevices() {
        let inputs = session.availableInputs ?? []
        // When session is inactive (e.g., after stop), availableInputs is empty.
        // Preserve the previous state instead of clearing it.
        if !inputs.isEmpty {
            availableInputs = inputs
            selectedInput = session.preferredInput ?? session.currentRoute.inputs.first ?? selectedInput
        }
        updateOutputName()
    }

    func selectInput(_ port: AVAudioSessionPortDescription) {
        do {
            try session.setPreferredInput(port)
            selectedInput = port
        } catch {
            print("Failed to set preferred input: \(error)")
        }
    }

    private func updateOutputName() {
        if let output = session.currentRoute.outputs.first {
            currentOutputName = output.portName
        }
        // If no output (session inactive), keep the previous name
    }

    private func observeRouteChanges() {
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshDevices()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                self?.handleInterruption(notification)
            }
            .store(in: &cancellables)
    }

    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            // Audio session interrupted (e.g., phone call)
            break
        case .ended:
            // Interruption ended — session needs to be reactivated by AudioEngineManager
            refreshDevices()
        @unknown default:
            break
        }
    }
}
