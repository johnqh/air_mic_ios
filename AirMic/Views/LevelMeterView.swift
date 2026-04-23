import SwiftUI

struct LevelMeterView: View {
    let level: Float

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))

                // Active level bar
                RoundedRectangle(cornerRadius: 6)
                    .fill(barColor)
                    .frame(width: max(0, geometry.size.width * CGFloat(level)))
                    .animation(.linear(duration: 0.05), value: level)
            }
        }
    }

    private var barColor: Color {
        if level > 0.8 {
            return .red
        } else if level > 0.6 {
            return .yellow
        } else {
            return .green
        }
    }
}
