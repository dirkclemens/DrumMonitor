import SwiftUI

struct VUMeterView: View {
    var level: Double // 0.0 ... 1.0
    
    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let fillHeight = CGFloat(level.clamped(to: 0...1)) * height
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                RoundedRectangle(cornerRadius: 6)
                    .fill(gradientColor())
                    .frame(height: fillHeight)
            }
        }
    }
    
    private func gradientColor() -> LinearGradient {
        let color: Color
        switch level {
        case ..<0.3: color = .green
        case ..<0.7: color = .yellow
        default: color = .red
        }
        return LinearGradient(
            gradient: Gradient(colors: [color.opacity(0.7), color]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

#Preview {
    VUMeterView(level: 0.75)
        .frame(width: 30, height: 150)
}
