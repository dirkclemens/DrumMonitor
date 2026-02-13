import SwiftUI

struct HitScatterTimelineView: View {
    @EnvironmentObject var midiManager: MIDIManager
    @State private var lastMetronomeTick: Date?
    @State private var samples: [HitSample] = []
    @State private var cleanupTimer: Timer?
    @State private var metronomeObserver: NSObjectProtocol?
    @State private var midiObserver: NSObjectProtocol?

    private let windowSeconds: TimeInterval = 10
    private let maxDeviationMs: Double = 80

    var body: some View {
        ViewContainer(title: "Hit Scatter Timeline", footer: "Plots early/late hits over time.") {
            VStack(spacing: 10) {
                if lastMetronomeTick == nil {
                    Text("Start the metronome to measure timing.")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }

                GeometryReader { geometry in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let centerY = height / 2
                    let now = Date()

                    ZStack {
                        // Background bands
                        Rectangle()
                            .fill(Color.green.opacity(0.12))
                            .frame(height: bandHeight(for: 10, totalHeight: height))
                            .position(x: width / 2, y: centerY)
                        Rectangle()
                            .fill(Color.yellow.opacity(0.10))
                            .frame(height: bandHeight(for: 25, totalHeight: height))
                            .position(x: width / 2, y: centerY)
                        Rectangle()
                            .fill(Color.orange.opacity(0.08))
                            .frame(height: bandHeight(for: 50, totalHeight: height))
                            .position(x: width / 2, y: centerY)

                        // Center line (perfect timing)
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: centerY))
                            path.addLine(to: CGPoint(x: width, y: centerY))
                        }
                        .stroke(Color.blue.opacity(0.7), lineWidth: 1)

                        // Scatter points
                        ForEach(samples) { sample in
                            let age = now.timeIntervalSince(sample.timestamp)
                            let x = width - CGFloat(age / windowSeconds) * width
                            let clamped = min(max(sample.deviationMs, -maxDeviationMs), maxDeviationMs)
                            let y = centerY - CGFloat(clamped / maxDeviationMs) * (height * 0.45)
                            let alpha = max(0.1, 1.0 - age / windowSeconds)
                            Circle()
                                .fill(sampleColor(for: sample.deviationMs).opacity(alpha))
                                .frame(width: 16, height: 16)
                                .position(x: x, y: y)
                        }
                    }
                }
                .frame(height: 120)

                HStack(spacing: 12) {
                    Text("Early")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Late")
                        .font(.caption2)
                        .foregroundColor(.secondary)
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

    private func bandHeight(for ms: Double, totalHeight: CGFloat) -> CGFloat {
        let ratio = min(ms / maxDeviationMs, 1.0)
        return totalHeight * 0.9 * CGFloat(ratio)
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
            samples.append(HitSample(timestamp: hitTime, deviationMs: deviationMs))
        }
    }

    private func startCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            let now = Date()
            samples = samples.filter { now.timeIntervalSince($0.timestamp) <= windowSeconds }
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

    private func sampleColor(for deviationMs: Double) -> Color {
        let absMs = abs(deviationMs)
        if absMs < 10 { return .green }
        if absMs < 25 { return .yellow }
        if absMs < 50 { return .orange }
        return .red
    }
}

private struct HitSample: Identifiable {
    let id = UUID()
    let timestamp: Date
    let deviationMs: Double
}

#Preview {
    HitScatterTimelineView()
        .environmentObject(MIDIManager())
}
