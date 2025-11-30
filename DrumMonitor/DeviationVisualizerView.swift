import SwiftUI

struct DeviationVisualizerView: View {
    @State private var lastMetronomeTick: Date? = nil
    @State private var lastMidiHit: Date? = nil
    @State private var deviationMs: Double = 0
    
    var body: some View {
        ViewContainer(title: "Deviation Visualizer", footer: "Shows the timing deviation between metronome ticks and MIDI drum hits.") {
            VStack(spacing: 10) {
                //            Text("Deviation Visualizer")
                //                .font(.headline)
                //                .bold()
                ZStack {
                    GeometryReader { geometry in
                        let width = geometry.size.width
                        let height = geometry.size.height
                        let centerY = height / 2
                        let tickX = width * 0.3
                        let hitX = width * 0.7
                        // Deviation bar color
                        let color: Color = {
                            let absDev = abs(deviationMs)
                            if absDev < 10 { return .green }
                            else if absDev < 25 { return .yellow }
                            else if absDev < 50 { return .orange }
                            else { return .red }
                        }()
                        // Metronome tick line
                        Path { path in
                            path.move(to: CGPoint(x: tickX, y: centerY - 30))
                            path.addLine(to: CGPoint(x: tickX, y: centerY + 30))
                        }
                        .stroke(Color.blue, lineWidth: 4)
                        // MIDI hit line
                        Path { path in
                            path.move(to: CGPoint(x: hitX, y: centerY - 30))
                            path.addLine(to: CGPoint(x: hitX, y: centerY + 30))
                        }
                        .stroke(Color.red, lineWidth: 4)
                        // Deviation bar
                        Path { path in
                            path.move(to: CGPoint(x: tickX, y: centerY))
                            path.addLine(to: CGPoint(x: hitX, y: centerY))
                        }
                        .stroke(color, style: StrokeStyle(lineWidth: 4, dash: [8, 4]))
                        // Arrow head
                        if deviationMs != 0 {
                            let arrowX = deviationMs > 0 ? hitX : tickX
                            let direction: CGFloat = deviationMs > 0 ? -1 : 1
                            Path { path in
                                path.move(to: CGPoint(x: arrowX, y: centerY))
                                path.addLine(to: CGPoint(x: arrowX + direction * 12, y: centerY - 8))
                                path.move(to: CGPoint(x: arrowX, y: centerY))
                                path.addLine(to: CGPoint(x: arrowX + direction * 12, y: centerY + 8))
                            }
                            .stroke(color, lineWidth: 3)
                        }
                        // Deviation value
                        Text(String(format: "%+.0f ms", deviationMs))
                            .font(.title2)
                            .bold()
                            .foregroundColor(color)
                            .position(x: (tickX + hitX) / 2, y: centerY - 28)
                    }
                }
                .frame(height: 80)
                //            .background(Color.gray.opacity(0.08))
                //            .cornerRadius(8)
                Text("Blue = Metronome, Red = Drum Hit")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            setupObservers()
        }
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(forName: .metronomeTickNotification, object: nil, queue: .main) { notification in
            if let tickTime = notification.object as? Date {
                lastMetronomeTick = tickTime
                updateDeviation()
            }
        }
        NotificationCenter.default.addObserver(forName: .midiMessageReceived, object: nil, queue: .main) { notification in
            lastMidiHit = Date()
            updateDeviation()
        }
    }
    private func updateDeviation() {
        guard let tick = lastMetronomeTick, let hit = lastMidiHit else { deviationMs = 0; return }
        deviationMs = (hit.timeIntervalSince(tick)) * 1000
    }
}

#Preview {
    DeviationVisualizerView()
}
