import SwiftUI
import AVKit

struct OutputRouteButton: UIViewRepresentable {
    let outputName: String
    let isDisabled: Bool

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.clipsToBounds = true

        // Styled label that mimics the input dropdown
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 17)
        label.textColor = .label

        let icon = UIImageView(image: UIImage(systemName: "speaker.wave.2.fill"))
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.tintColor = .label
        icon.contentMode = .scaleAspectFit

        let chevron = UIImageView(image: UIImage(systemName: "chevron.up.chevron.down"))
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.tintColor = .secondaryLabel
        chevron.contentMode = .scaleAspectFit

        let stack = UIStackView(arrangedSubviews: [icon, label, chevron])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.isUserInteractionEnabled = false

        let background = UIView()
        background.translatesAutoresizingMaskIntoConstraints = false
        background.backgroundColor = .tertiarySystemFill
        background.layer.cornerRadius = 10

        container.addSubview(background)
        container.addSubview(stack)

        // Invisible AVRoutePickerView on top to capture taps
        let picker = AVRoutePickerView()
        picker.translatesAutoresizingMaskIntoConstraints = false
        picker.alpha = 0.05 // Nearly invisible but tappable
        picker.activeTintColor = .clear
        picker.tintColor = .clear
        container.addSubview(picker)

        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            background.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            background.topAnchor.constraint(equalTo: container.topAnchor),
            background.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            icon.widthAnchor.constraint(equalToConstant: 20),
            chevron.widthAnchor.constraint(equalToConstant: 12),

            picker.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            picker.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            picker.topAnchor.constraint(equalTo: container.topAnchor),
            picker.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        // Store references for updates
        label.tag = 1001
        picker.tag = 1002
        container.tag = 0

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let label = uiView.findView(withTag: 1001) as? UILabel {
            label.text = outputName
        }
        // Block touches on the invisible picker when disabled
        if let picker = uiView.findView(withTag: 1002) {
            picker.isUserInteractionEnabled = !isDisabled
        }
    }
}

private extension UIView {
    func findView(withTag tag: Int) -> UIView? {
        if self.tag == tag { return self }
        for subview in subviews {
            if let found = subview.findView(withTag: tag) { return found }
        }
        return nil
    }
}
