# AirMic — iOS Audio Router

## Context

For presentations, a speaker often needs to route audio from a wired microphone to a Bluetooth speaker. iOS doesn't natively allow choosing independent input/output audio devices. AirMic bridges this gap: pick any input, pick any output, and route audio in real-time with minimal latency.

## Requirements

- **Input selection**: List available inputs (built-in mic, wired earphone mic, Bluetooth mic) — user picks one
- **Output selection**: List available outputs (built-in speaker, wired headphones, Bluetooth speaker) — user picks one via system route picker
- **Real-time routing**: Ultra-low latency audio pass-through from selected input to selected output
- **Background audio**: Keeps routing when app is backgrounded or screen locked
- **Volume control**: Gain slider to boost/reduce routed audio
- **Level meter**: Visual audio level indicator
- **Stop behavior**: Stop audio engine, deactivate session, then deep-link to iOS Bluetooth Settings so user can forget the device
- **Target**: iOS 16+, SwiftUI

## iOS Audio Routing Constraints

| Capability | iOS API | Notes |
|---|---|---|
| List inputs | `AVAudioSession.availableInputs` | Works — returns all connected input ports |
| Select input | `AVAudioSession.setPreferredInput()` | Works programmatically |
| Select output | `AVRoutePickerView` | iOS does **not** allow programmatic output selection for Bluetooth audio. Must use the system route picker UI. |
| Forget BT device | None | No public API. Deep-link to `App-prefs:Bluetooth` as workaround. |

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌──────────────┐
│  inputNode   │────▶│  mixerNode   │────▶│  outputNode  │
│ (selected    │     │ (gain/volume │     │ (selected    │
│  mic input)  │     │  + metering) │     │  BT/wired    │
└─────────────┘     └──────────────┘     │  output)     │
                                          └──────────────┘
```

- `AVAudioEngine` handles the real-time audio graph
- `inputNode` is configured via `AVAudioSession.setPreferredInput()`
- `mixerNode` (mainMixerNode) provides gain control and metering tap
- `outputNode` routes to whatever the system audio route is (controlled via `AVRoutePickerView`)

## Project Structure

```
AirMic/
├── AirMicApp.swift              # App entry point
├── Info.plist                    # Background audio mode
├── Audio/
│   ├── AudioEngineManager.swift  # AVAudioEngine lifecycle, start/stop/routing
│   └── AudioDeviceManager.swift  # Device discovery, input selection, route monitoring
├── Views/
│   ├── ContentView.swift         # Main screen: input picker, output picker, controls
│   ├── InputPickerView.swift     # List of available input devices
│   ├── OutputRouteButton.swift   # Wraps AVRoutePickerView for output selection
│   └── LevelMeterView.swift      # Audio level visualization bar
└── AirMic.entitlements           # Background modes
```

## Implementation Steps

### Step 1: Xcode Project Setup
- Create new Xcode project (iOS App, SwiftUI, Swift)
- Add background mode: `audio` in Info.plist (`UIBackgroundModes = [audio]`)
- Add microphone usage description: `NSMicrophoneUsageDescription`

### Step 2: AudioEngineManager
Core audio routing engine using `AVAudioEngine`:

```swift
class AudioEngineManager: ObservableObject {
    private let engine = AVAudioEngine()
    @Published var isRunning = false
    @Published var audioLevel: Float = 0.0
    @Published var gain: Float = 1.0  // 0.0 to 2.0

    func start()   // Configure session, start engine, install metering tap
    func stop()    // Stop engine, deactivate session, optionally open BT settings
}
```

Key implementation details:
- Configure `AVAudioSession` with category `.playAndRecord`, mode `.default`, options `[.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]`
- The engine graph is simple: `inputNode → mainMixerNode → outputNode`
- Install tap on `mainMixerNode` for level metering (read RMS from buffer)
- Set `mainMixerNode.outputVolume` for gain control
- Use buffer size of 256 frames for low latency (`session.setPreferredIOBufferDuration(0.005)`)

### Step 3: AudioDeviceManager
Device discovery and selection:

```swift
class AudioDeviceManager: ObservableObject {
    @Published var availableInputs: [AVAudioSessionPortDescription] = []
    @Published var currentInput: AVAudioSessionPortDescription?
    @Published var currentOutputName: String = "Default"

    func refreshDevices()
    func selectInput(_ port: AVAudioSessionPortDescription)
}
```

- Observe `AVAudioSession.routeChangeNotification` to refresh device lists on connect/disconnect
- Observe `AVAudioSession.interruptionNotification` to handle phone calls, etc.
- `selectInput()` calls `AVAudioSession.sharedInstance().setPreferredInput(port)`
- Output name read from `AVAudioSession.sharedInstance().currentRoute.outputs`

### Step 4: UI — ContentView
Main screen layout (top to bottom):
1. **Input Picker**: List/menu of available inputs from `AudioDeviceManager`
2. **Output Button**: `AVRoutePickerView` wrapped in `UIViewRepresentable` — tapping shows system Bluetooth/AirPlay picker
3. **Current route display**: Shows "Input: Wired Mic → Output: BT Speaker"
4. **Level Meter**: Horizontal bar showing real-time audio level
5. **Gain Slider**: 0% to 200% volume control
6. **Start/Stop Button**: Large toggle button

### Step 5: OutputRouteButton (AVRoutePickerView wrapper)
`AVRoutePickerView` is a UIKit view — wrap it in `UIViewRepresentable`:

```swift
struct OutputRouteButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.activeTintColor = .systemBlue
        picker.tintColor = .label
        return picker
    }
}
```

### Step 6: LevelMeterView
Simple horizontal bar that animates based on `audioLevel` (0.0–1.0):
- Green when level < 0.6
- Yellow when level 0.6–0.8
- Red when level > 0.8

### Step 7: Stop + Bluetooth Settings Deep-Link
When stop is pressed and current output is Bluetooth:
1. `engine.stop()`
2. `AVAudioSession.sharedInstance().setActive(false)`
3. Open `App-prefs:Bluetooth` via `UIApplication.shared.open(url)`
4. Show brief alert explaining "Forget the device in Bluetooth Settings to fully disconnect"

Note: `App-prefs:` URLs work but are technically private API — the app may be rejected by App Store review. Alternative: use `UIApplication.openSettingsURLString` to open app settings, or just show instructions. We'll implement both and can toggle.

### Step 8: Background Audio
- `UIBackgroundModes` = `[audio]` in Info.plist is sufficient
- The `AVAudioEngine` continues running in background as long as the audio session is active
- No additional code needed beyond the session configuration

## Verification

1. **Build**: Project compiles with no errors in Xcode
2. **Input discovery**: Connect wired earphones, verify they appear in input list
3. **Output selection**: Tap output button, verify Bluetooth speakers appear in system picker
4. **Audio routing**: Select wired mic input + BT speaker output, speak into mic, hear voice from BT speaker
5. **Low latency**: Verify <50ms perceptible delay
6. **Background**: Lock screen, verify audio continues routing
7. **Level meter**: Verify bar animates with voice
8. **Gain slider**: Verify volume changes when adjusting slider
9. **Stop + BT**: Press stop, verify iOS Bluetooth Settings opens

## Known Limitations

- **Output selection is system-controlled**: Cannot programmatically select a specific Bluetooth output device — must use `AVRoutePickerView` (system UI)
- **Cannot forget BT device programmatically**: `App-prefs:Bluetooth` deep link may be rejected by App Store review. Fallback: show user instructions
- **Audio interruptions**: Phone calls will interrupt the audio session. App handles this via interruption notifications and auto-resumes after
- **Feedback loop risk**: If input mic and output speaker are physically close, audio feedback can occur. The gain slider helps manage this, but no automatic feedback suppression in v1
