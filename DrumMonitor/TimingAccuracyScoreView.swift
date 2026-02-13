import SwiftUI

struct TimingAccuracyScoreView: View {
    @EnvironmentObject var midiManager: MIDIManager
    @State private var lastMetronomeTick: Date?
    @State private var samples: [Double] = []
    @State private var totalHits: Int = 0
    @State private var streak: Int = 0
    @State private var metronomeObserver: NSObjectProtocol?
    @State private var midiObserver: NSObjectProtocol?

    private let maxSamples = 500

    var body: some View {
        ViewContainer(title: "Timing Accuracy Score", footer: "Scores how close your hits are to the metronome.") {
            VStack(spacing: 10) {
                HStack(spacing: 24) {
                    metricBlock(title: "Score", value: "\(score)%")
                    metricBlock(title: "Hits", value: "\(totalHits)")
                    metricBlock(title: "Streak", value: "\(streak)")
                }

                HStack(spacing: 12) {
                    scoreBucket(title: "Perfect", range: "±10ms", count: bucketCounts.perfect, color: .green)
                    scoreBucket(title: "Great", range: "±25ms", count: bucketCounts.great, color: .yellow)
                    scoreBucket(title: "OK", range: "±50ms", count: bucketCounts.ok, color: .orange)
                    scoreBucket(title: "Late/Early", range: ">50ms", count: bucketCounts.bad, color: .red)
                }
            }
        }
        .onAppear {
            setupObservers()
        }
        .onDisappear {
            teardown()
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
            if let focus = midiManager.focusPad, message.note != focus {
                return
            }

            let hitTime = Date()
            let interval = 60.0 / max(30.0, midiManager.bpm) / Double(max(1, midiManager.subdivision))
            let raw = hitTime.timeIntervalSince(tick)
            let deviation = raw > interval / 2 ? raw - interval : raw
            let deviationMs = deviation * 1000.0

            totalHits += 1
            samples.append(deviationMs)
            if samples.count > maxSamples {
                samples.removeFirst()
            }

            if abs(deviationMs) <= 10 {
                streak += 1
            } else {
                streak = 0
            }
        }
    }

    private func teardown() {
        if let observer = metronomeObserver {
            NotificationCenter.default.removeObserver(observer)
            metronomeObserver = nil
        }
        if let observer = midiObserver {
            NotificationCenter.default.removeObserver(observer)
            midiObserver = nil
        }
    }

    private var bucketCounts: (perfect: Int, great: Int, ok: Int, bad: Int) {
        var perfect = 0
        var great = 0
        var ok = 0
        var bad = 0
        for value in samples {
            let absMs = abs(value)
            if absMs <= 10 { perfect += 1 }
            else if absMs <= 25 { great += 1 }
            else if absMs <= 50 { ok += 1 }
            else { bad += 1 }
        }
        return (perfect, great, ok, bad)
    }

    private var score: Int {
        let counts = bucketCounts
        let total = max(1, samples.count)
        let weighted = counts.perfect * 100 + counts.great * 80 + counts.ok * 50 + counts.bad * 0
        return weighted / total
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

    private func scoreBucket(title: String, range: String, count: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(range)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text("\(count)")
                .font(.caption)
                .bold()
                .foregroundColor(color)
        }
    }
}

#Preview {
    TimingAccuracyScoreView()
        .environmentObject(MIDIManager())
}
