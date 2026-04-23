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

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.processAudioLevel(buffer: buffer)
        }

        try engine.start()
    }

    private func stopEngine() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        engine.reset()
    }

    /// Restart the engine to pick up new audio formats after a route change
    /// (e.g., switching to/from Bluetooth changes sample rate and channel count).
    private func restartEngine() {
        guard isRunning else { return }
        stopEngine()
        do {
            try startEngine()
        } catch {
            print("Failed to restart audio engine after route change: \(error)")
            isRunning = false
            audioLevel = 0.0
        }
    }

    // MARK: - Session configuration

    private func configureSession() throws {
        try session.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
        )
        try session.setPreferredIOBufferDuration(0.005)
        try session.setActive(true)
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

            switch changeReason {
            case .newDeviceAvailable, .oldDeviceUnavailable, .override, .categoryChange:
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
