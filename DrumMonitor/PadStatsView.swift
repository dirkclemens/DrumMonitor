import SwiftUI

struct PadStatsView: View {
    @EnvironmentObject var midiManager: MIDIManager
    @State private var lastMetronomeTick: Date?
    @State private var stats: [UInt8: PadStats] = [:]
    @State private var metronomeObserver: NSObjectProtocol?
    @State private var midiObserver: NSObjectProtocol?

    var body: some View {
        ViewContainer(title: "Pad Stats", footer: "Per-pad timing averages and consistency.") {
            VStack(spacing: 8) {
                if stats.isEmpty {
                    Text("No pad stats yet.")
                        .foregroundColor(.secondary)
                        .font(.caption)
                } else {
                    ForEach(padKeys, id: \.self) { note in
                        let stat = stats[note]
                        HStack {
                            Text(midiManager.drumPadName(for: note))
                                .frame(width: 90, alignment: .leading)
                            Text("Avg \(formattedMs(stat?.average))")
                                .font(.caption)
                            Text("σ \(formattedMs(stat?.stddev))")
                                .font(.caption)
                            Spacer()
                            Text("\(stat?.count ?? 0)")
                                .font(.caption)
                                .bold()
                        }
                    }
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

    private var padKeys: [UInt8] {
        stats.keys.sorted()
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

            var current = stats[message.note] ?? PadStats()
            current.addSample(deviationMs)
            stats[message.note] = current
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

    private func formattedMs(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%+.0f", value)
    }
}

private struct PadStats {
    private var samples: [Double] = []

    mutating func addSample(_ value: Double) {
        samples.append(value)
        if samples.count > 200 {
            samples.removeFirst()
        }
    }

    var count: Int {
        samples.count
    }

    var average: Double? {
        guard !samples.isEmpty else { return nil }
        let sum = samples.reduce(0.0, +)
        return sum / Double(samples.count)
    }

    var stddev: Double? {
        guard samples.count >= 2, let avg = average else { return nil }
        let variance = samples.reduce(0.0) { $0 + pow($1 - avg, 2) } / Double(samples.count - 1)
        return sqrt(variance)
    }
}

#Preview {
    PadStatsView()
        .environmentObject(MIDIManager())
}
