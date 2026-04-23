import SwiftUI
import AVKit

struct OutputRouteButton: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        let picker = AVRoutePickerView()
        picker.activeTintColor = .systemBlue
        picker.tintColor = .label
        picker.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(picker)
        NSLayoutConstraint.activate([
            picker.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            picker.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            picker.topAnchor.constraint(equalTo: container.topAnchor),
            picker.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
