import SwiftUI

struct VelocitySineWaveView: View {
    var velocity: Double // 0...127
    var animationPhase: Double
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let centerY = height / 2
            let amplitude = velocity / 127.0 * (height * 0.4)
            let yAxisX = width / 2
            let line50YPos = centerY - (height * 0.4) * 0.5
            let line100YPos = centerY - (height * 0.4)
            let line50YNeg = centerY + (height * 0.4) * 0.5
            let line100YNeg = centerY + (height * 0.4)
            ZStack {
                // Coordinate grid
                Path { path in
                    // Vertical y-axis
                    path.move(to: CGPoint(x: yAxisX, y: 0))
                    path.addLine(to: CGPoint(x: yAxisX, y: height))
                }
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundColor(.gray.opacity(0.5))
                // Horizontal dotted lines at +50%, +100%, -50%, -100% amplitude
                Path { path in
                    // Positive side
                    path.move(to: CGPoint(x: 0, y: line50YPos))
                    path.addLine(to: CGPoint(x: width, y: line50YPos))
                    path.move(to: CGPoint(x: 0, y: line100YPos))
                    path.addLine(to: CGPoint(x: width, y: line100YPos))
                    // Negative side
                    path.move(to: CGPoint(x: 0, y: line50YNeg))
                    path.addLine(to: CGPoint(x: width, y: line50YNeg))
                    path.move(to: CGPoint(x: 0, y: line100YNeg))
                    path.addLine(to: CGPoint(x: width, y: line100YNeg))
                }
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
                .foregroundColor(.gray.opacity(0.4))
                
                // Sine wave
                Path { path in
                    let points = 200
                    let stepX = width / CGFloat(points)
                    for i in 0...points {
                        let x = CGFloat(i) * stepX
                        let normalizedX = Double(i) / Double(points) * 4 * .pi // 2 complete cycles
                        let y = centerY + CGFloat(sin(normalizedX + animationPhase) * amplitude)
                        if i == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: velocityColor(),
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 2
                )
                .animation(.easeInOut(duration: 0.3), value: velocity)
                // Center line
                Rectangle()
                    .fill(.gray.opacity(0.3))
                    .frame(width: width, height: 1)
                    .position(x: width/2, y: centerY)
            }
        }
    }
    
    private func velocityColor() -> [Color] {
        let intensity = velocity / 127.0
        if intensity < 0.3 {
            return [.blue, .cyan]
        } else if intensity < 0.7 {
            return [.green, .yellow]
        } else {
            return [.orange, .red]
        }
    }
}

#Preview {
    VelocitySineWaveView(velocity: 80, animationPhase: 0)
        .frame(height: 150)
}
