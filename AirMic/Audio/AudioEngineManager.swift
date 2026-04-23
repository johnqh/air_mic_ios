import AVFoundation
import Combine
import UIKit

@MainActor
final class AudioEngineManager: ObservableObject {
    private let engine = AVAudioEngine()
    private let session = AVAudioSession.sharedInstance()

    @Published var isRunning = false
    @Published var audioLevel: Float = 0.0
    @Published var gain: Float = 1.0 {
        didSet { engine.mainMixerNode.outputVolume = gain }
    }

    private var routeChangeObserver: NSObjectProtocol?

    func start() throws {
        try configureSession()
        updateOutputRoute()
        try startEngine()
        observeRouteChanges()
        isRunning = true
    }

    func stop(openBluetoothSettings: Bool = false) {
        let currentOutputIsBluetooth = session.currentRoute.outputs.contains { port in
            port.portType == .bluetoothA2DP || port.portType == .bluetoothHFP || port.portType == .bluetoothLE
        }

        stopEngine()
        removeRouteChangeObserver()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        isRunning = false
        audioLevel = 0.0

        if openBluetoothSettings && currentOutputIsBluetooth {
            openBluetoothSettingsPage()
        }
    }

    // MARK: - Engine lifecycle

    private func startEngine() throws {
        let inputNode = engine.inputNode
        let mixer = engine.mainMixerNode
        let format = inputNode.outputFormat(forBus: 0)

        engine.connect(inputNode, to: mixer, format: format)
        mixer.outputVolume = gain

        inputNode.installTap(onBus: 0, bufferSize: 256, format: format) { [weak self] buffer, _ in
            self?.processAudioLevel(buffer: buffer)
        }

        try engine.start()
    }

    private func stopEngine() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        engine.reset()
    }

    private func restartEngine() {
        guard isRunning else { return }
        stopEngine()
        do {
            updateOutputRoute()
            try startEngine()
        } catch {
            print("Failed to restart audio engine after route change: \(error)")
            isRunning = false
            audioLevel = 0.0
        }
    }

    // MARK: - Session & routing

    private func configureSession() throws {
        try session.setCategory(
            .playAndRecord,
            mode: .measurement, // No AGC/noise suppression — prevents interference
            options: [.allowBluetooth, .allowBluetoothA2DP]
        )
        try session.setPreferredIOBufferDuration(0.002)
        try session.setActive(true)
    }

    /// Route to loudspeaker when no external output is connected.
    /// .measurement mode ignores .defaultToSpeaker, so we override manually.
    private func updateOutputRoute() {
        let hasExternalOutput = session.currentRoute.outputs.contains { port in
            port.portType == .bluetoothA2DP || port.portType == .bluetoothHFP ||
            port.portType == .bluetoothLE || port.portType == .headphones ||
            port.portType == .airPlay
        }

        if hasExternalOutput {
            try? session.overrideOutputAudioPort(.none)
        } else {
            try? session.overrideOutputAudioPort(.speaker)
        }
    }

    // MARK: - Route change handling

    private func observeRouteChanges() {
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            guard let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let changeReason = AVAudioSession.RouteChangeReason(rawValue: reason) else {
                return
            }

            // Don't handle .override — that's triggered by our own overrideOutputAudioPort calls
            switch changeReason {
            case .newDeviceAvailable, .oldDeviceUnavailable, .categoryChange:
                Task { @MainActor [weak self] in
                    self?.restartEngine()
                }
            default:
                break
            }
        }
    }

    private func removeRouteChangeObserver() {
        if let observer = routeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            routeChangeObserver = nil
        }
    }

    // MARK: - Metering

    private nonisolated func processAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frames = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        var sumSquares: Float = 0
        for ch in 0..<channelCount {
            let data = channelData[ch]
            for i in 0..<frames {
                let sample = data[i]
                sumSquares += sample * sample
            }
        }
        let rms = sqrtf(sumSquares / Float(frames * channelCount))
        let db = 20 * log10f(max(rms, 1e-6))
        let normalized = max(0, min(1, (db + 50) / 50))

        Task { @MainActor [weak self] in
            self?.audioLevel = normalized
        }
    }

    // MARK: - Bluetooth settings

    private func openBluetoothSettingsPage() {
        if let btURL = URL(string: "App-prefs:Bluetooth"),
           UIApplication.shared.canOpenURL(btURL) {
            UIApplication.shared.open(btURL)
        } else if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
}
