import SwiftUI

struct DeviationMeterView: View {
    @EnvironmentObject var midiManager: MIDIManager
    @State private var lastMetronomeTick: Date?
    @State private var samples: [DeviationSample] = []
    @State private var cleanupTimer: Timer?
    @State private var metronomeObserver: NSObjectProtocol?
    @State private var midiObserver: NSObjectProtocol?

    private let maxVisibleSeconds: TimeInterval = 6

    var body: some View {
        ViewContainer(title: "Deviation Meter", footer: "Shows early/late hits relative to the metronome.") {
            VStack(spacing: 12) {
                if lastMetronomeTick == nil {
                    Text("Start the metronome to measure timing.")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }

                ZStack {
                    GeometryReader { geometry in
                        let width = geometry.size.width
                        let height = geometry.size.height
                        let centerX = width / 2
                        let centerY = height / 2
                        let maxMs: Double = 80

                        // Axis
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: centerY))
                            path.addLine(to: CGPoint(x: width, y: centerY))
                        }
                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)

                        // Center line
                        Path { path in
                            path.move(to: CGPoint(x: centerX, y: centerY - 16))
                            path.addLine(to: CGPoint(x: centerX, y: centerY + 16))
                        }
                        .stroke(Color.blue.opacity(0.8), lineWidth: 2)

                        // Labels
                        Text("Early")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .position(x: 20, y: centerY - 18)
                        Text("Late")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .position(x: width - 20, y: centerY - 18)

                        // Samples (fade by age)
                        ForEach(samples) { sample in
                            let age = Date().timeIntervalSince(sample.timestamp)
                            let alpha = max(0.1, 1.0 - age / maxVisibleSeconds)
                            let clamped = min(max(sample.deviationMs, -maxMs), maxMs)
                            let x = centerX + CGFloat(clamped / maxMs) * (width * 0.45)
                            Circle()
                                .fill(sampleColor(for: sample.deviationMs).opacity(alpha))
                                .frame(width: 16, height: 16)
                                .position(x: x, y: centerY)
                        }
                    }
                }
                .frame(height: 60)

                HStack(spacing: 24) {
                    metricBlock(title: "Last", value: formattedMs(lastDeviation))
                    metricBlock(title: "Average", value: formattedMs(averageDeviation))
                    metricBlock(title: "Consistency", value: formattedMs(standardDeviation))
                }
            }
        }
        .onAppear {
            setupObservers()
            startCleanupTimer()
        }
        .onDisappear {
            cleanup()
        }
    }

    private func setupObservers() {
        if let observer = metronomeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = midiObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        metronomeObserver = NotificationCenter.default.addObserver(
            forName: .metronomeTickNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let tickTime = notification.object as? Date {
                lastMetronomeTick = tickTime
            }
        }

        midiObserver = NotificationCenter.default.addObserver(
            forName: .midiMessageReceived,
            object: nil,
            queue: .main
        ) { notification in
            guard let tick = lastMetronomeTick else { return }
            guard let message = notification.object as? MIDIMessage else { return }
            guard (message.status & 0xF0) == 0x90, message.velocity > 0 else { return }

            let hitTime = Date()
            let interval = 60.0 / max(30.0, midiManager.bpm) / Double(max(1, midiManager.subdivision))
            let raw = hitTime.timeIntervalSince(tick)
            let deviation = raw > interval / 2 ? raw - interval : raw
            let deviationMs = deviation * 1000.0

            if let focus = midiManager.focusPad, message.note != focus {
                return
            }
            samples.append(DeviationSample(timestamp: hitTime, deviationMs: deviationMs))
        }
    }

    private func startCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            let now = Date()
            samples = samples.filter { now.timeIntervalSince($0.timestamp) <= maxVisibleSeconds }
        }
    }

    private func cleanup() {
        cleanupTimer?.invalidate()
        cleanupTimer = nil
        if let observer = metronomeObserver {
            NotificationCenter.default.removeObserver(observer)
            metronomeObserver = nil
        }
        if let observer = midiObserver {
            NotificationCenter.default.removeObserver(observer)
            midiObserver = nil
        }
    }

    private var lastDeviation: Double? {
        samples.last?.deviationMs
    }

    private var averageDeviation: Double? {
        guard !samples.isEmpty else { return nil }
        let sum = samples.reduce(0.0) { $0 + $1.deviationMs }
        return sum / Double(samples.count)
    }

    private var standardDeviation: Double? {
        guard samples.count >= 2, let avg = averageDeviation else { return nil }
        let variance = samples.reduce(0.0) { $0 + pow($1.deviationMs - avg, 2) } / Double(samples.count - 1)
        return sqrt(variance)
    }

    private func formattedMs(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%+.0f ms", value)
    }

    private func metricBlock(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .bold()
        }
    }

    private func sampleColor(for deviationMs: Double) -> Color {
        let absMs = abs(deviationMs)
        if absMs < 10 { return .green }
        if absMs < 25 { return .yellow }
        if absMs < 50 { return .orange }
        return .red
    }
}

private struct DeviationSample: Identifiable {
    let id = UUID()
    let timestamp: Date
    let deviationMs: Double
}

#Preview {
    DeviationMeterView()
        .environmentObject(MIDIManager())
}
