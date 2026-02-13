import SwiftUI

struct OscilloscopeView: View {
    @EnvironmentObject var midiManager: MIDIManager
    @State private var lastMetronomeTick: Date?
    @State private var hitsPerPad: [UInt8: [HitSample]] = [:]
    @State private var cleanupTimer: Timer?
    @State private var metronomeObserver: NSObjectProtocol?
    @State private var midiObserver: NSObjectProtocol?
    @State private var windowSeconds: Double = 6.0
    @State private var historyBeats: Double = 4.0
    @State private var autoMode: Bool = true
    @State private var isLoaded = false
    private let padColors: [Color] = [
        Color(red: 0.0, green: 0.45, blue: 0.70), // blue
        Color(red: 0.87, green: 0.56, blue: 0.05), // orange
        Color(red: 0.94, green: 0.23, blue: 0.17), // red
        Color(red: 0.0, green: 0.62, blue: 0.45), // teal
        Color(red: 0.80, green: 0.47, blue: 0.74), // purple
        Color(red: 0.80, green: 0.73, blue: 0.36), // yellow
        Color(red: 0.13, green: 0.69, blue: 0.30), // green
        Color(red: 0.98, green: 0.51, blue: 0.18), // orange-red
        Color(red: 0.56, green: 0.56, blue: 0.56), // gray
        Color(red: 0.0, green: 0.0, blue: 0.0)     // black
    ]
    private let beatsToShow = 4.0
    private let autoModeKey = "DrumMonitor_PhaseView_AutoMode"
    private let historyBeatsKey = "DrumMonitor_PhaseView_HistoryBeats"
    private let historySecondsKey = "DrumMonitor_PhaseView_HistorySeconds"
    
    var body: some View {
        let padKeys = Array(hitsPerPad.keys).sorted()
        let padCount = padKeys.count
        
        ViewContainer(title: "Phase View", footer: "Beat-aligned view of early/late hits.") {
            ZStack {
                GeometryReader { geometry in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let centerX = width / 2
                    let now = Date()
                    let interval = 60.0 / max(30.0, midiManager.bpm) / Double(max(1, midiManager.subdivision))
                    let halfInterval = interval / 2
                    let step = interval / Double(max(1, midiManager.subdivision))
                    ZStack {
                        let bandHeight = height / CGFloat(max(padCount, 1))

                        // Background bands for each pad
                        ForEach(padKeys.enumerated().map({ ($0.offset, $0.element) }), id: \.1) { idx, noteIdx in
                            let bandY = bandHeight * CGFloat(idx)
                            Rectangle()
                                .fill(padColors[idx % padColors.count].opacity(0.08))
                                .frame(width: width, height: bandHeight)
                                .position(x: width/2, y: bandY + bandHeight/2)
                        }

                        // Grid lines (subdivision) and center line
                        Path { path in
                            let range = Int(ceil(Double(max(1, midiManager.subdivision)) / 2.0))
                            for i in -range...range {
                                let offset = Double(i) * step
                                guard abs(offset) <= halfInterval + 0.0001 else { continue }
                                let x = centerX + CGFloat(offset / halfInterval) * (width * 0.45)
                                path.move(to: CGPoint(x: x, y: 0))
                                path.addLine(to: CGPoint(x: x, y: height))
                            }
                        }
                        .stroke(Color.gray.opacity(0.25), lineWidth: 1)

                        Path { path in
                            path.move(to: CGPoint(x: centerX, y: 0))
                            path.addLine(to: CGPoint(x: centerX, y: height))
                        }
                        .stroke(Color.blue.opacity(0.7), lineWidth: 2)

                        // Hits per pad (dots)
                        ForEach(padKeys.enumerated().map({ ($0.offset, $0.element) }), id: \.1) { idx, noteIdx in
                            let color = padColors[idx % padColors.count]
                            let bandY = bandHeight * CGFloat(idx)
                            ZStack(alignment: .topLeading) {
                                // Pad label at top left of band
                                Text(midiManager.drumPadName(for: noteIdx))
                                    .font(.caption2)
                                    .foregroundColor(color)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, 8)
                                    .padding(.top, 2)
                                // Hit dots centered vertically in band
                                ForEach(hitsPerPad[noteIdx] ?? []) { hit in
                                    let age = now.timeIntervalSince(hit.timestamp)
                                    let alpha = max(0.1, 1.0 - age / windowSeconds)
                                    let clamped = min(max(hit.deviation, -halfInterval), halfInterval)
                                    let x = centerX + CGFloat(clamped / halfInterval) * (width * 0.45)
                                    let y = bandHeight / 2
                                    Circle()
                                        .fill(sampleColor(for: clamped * 1000.0).opacity(alpha))
                                        .frame(width: 16, height: 16)
                                        .position(x: x, y: y)
                                }
                            }
                            .frame(width: width, height: bandHeight)
                            .position(x: width/2, y: bandY + bandHeight/2)
                        }
                    }
                }
                .frame(minHeight: 150, maxHeight: .infinity)
                
                // Sliders and auto toggle
                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        Toggle("Auto", isOn: $autoMode)
//                            .toggleStyle(.checkbox)
                            .frame(width: 60)
                        HStack {
                            if autoMode {
                                Text("History (beats):")
                                Slider(value: $historyBeats, in: 2.0...16.0, step: 2.0)
                                    .frame(width: 120)
                                Text(String(format: "%.0f", historyBeats))
                                    .frame(width: 32, alignment: .leading)
                                Text(String(format: "(~%.1fs)", windowSeconds))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("History (s):")
                                Slider(value: $windowSeconds, in: 2.0...12.0, step: 1.0)
                                    .frame(width: 120)
                                Text(String(format: "%.0f", windowSeconds))
                                    .frame(width: 32, alignment: .leading)
                            }
                        }
                        if autoMode {
                            HStack(spacing: 6) {
                                Button("2") { historyBeats = 2 }
                                Button("4") { historyBeats = 4 }
                                Button("8") { historyBeats = 8 }
                                Button("16") { historyBeats = 16 }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .onAppear {
            startCleanupTimer()
            setupObservers()
            if !isLoaded {
                autoMode = UserDefaults.standard.object(forKey: autoModeKey) as? Bool ?? true
                historyBeats = UserDefaults.standard.object(forKey: historyBeatsKey) as? Double ?? beatsToShow
                windowSeconds = UserDefaults.standard.object(forKey: historySecondsKey) as? Double ?? 6.0
                if autoMode {
                    windowSeconds = historyBeats * (60.0 / max(30.0, midiManager.bpm))
                }
                isLoaded = true
            }
        }
        .onDisappear {
            stopCleanupTimer()
            teardownObservers()
        }
        .onChange(of: autoMode) { newValue, _ in
            if newValue {
                windowSeconds = historyBeats * (60.0 / max(30.0, midiManager.bpm))
            }
            if isLoaded {
                UserDefaults.standard.set(newValue, forKey: autoModeKey)
            }
        }
        .onChange(of: midiManager.bpm) { newValue, _ in
            if autoMode {
                windowSeconds = historyBeats * (60.0 / newValue)
            }
        }
        .onChange(of: historyBeats) { newValue, _ in
            if autoMode {
                windowSeconds = newValue * (60.0 / max(30.0, midiManager.bpm))
            }
            if isLoaded {
                UserDefaults.standard.set(newValue, forKey: historyBeatsKey)
            }
        }
        .onChange(of: windowSeconds) { newValue, _ in
            if !autoMode, isLoaded {
                UserDefaults.standard.set(newValue, forKey: historySecondsKey)
            }
        }
    }
    
    private func startCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            let now = Date()
            for key in hitsPerPad.keys {
                hitsPerPad[key] = hitsPerPad[key]?.filter { now.timeIntervalSince($0.timestamp) < windowSeconds }
            }
        }
    }
    
    private func stopCleanupTimer() {
        cleanupTimer?.invalidate()
        cleanupTimer = nil
    }
    
    private func setupObservers() {
        if let observer = metronomeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = midiObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        metronomeObserver = NotificationCenter.default.addObserver(forName: .metronomeTickNotification, object: nil, queue: .main) { notification in
            if let tickTime = notification.object as? Date {
                lastMetronomeTick = tickTime
            }
        }

        midiObserver = NotificationCenter.default.addObserver(forName: .midiMessageReceived, object: nil, queue: .main) { notification in
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
            hitsPerPad[message.note, default: []].append(HitSample(timestamp: hitTime, deviation: deviation))
        }
    }

    private func teardownObservers() {
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

#Preview {
    OscilloscopeView()
}

// Helper for pad name
extension MIDIManager {
    func drumPadName(for note: UInt8) -> String {
        switch note {
        case 36: return "Kick"
        case 38, 40: return "Snare"
        case 42, 44: return "Hi-Hat"
        case 46: return "Open HH"
        case 41, 43: return "Low Tom"
        case 45, 47: return "Mid Tom"
        case 48, 50: return "High Tom"
        case 49, 57: return "Crash"
        case 51, 59: return "Ride"
        default: return "Pad \(note)"
        }
    }
}

private struct HitSample: Identifiable {
    let id = UUID()
    let timestamp: Date
    let deviation: Double
}
