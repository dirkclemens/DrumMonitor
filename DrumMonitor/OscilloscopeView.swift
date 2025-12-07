import SwiftUI

struct OscilloscopeView: View {
    @EnvironmentObject var midiManager: MIDIManager
    @State private var metronomePeaks: [Date] = []
    @State private var midiPeaks: [Date] = []
    @State private var midiPeaksPerPad: [UInt8: [Date]] = [:]
    @State private var timer: Timer?
    @State private var windowSeconds: Double = 1.0
    @State private var sampleRate: Int = 120 // Number of points in the oscilloscope
    @State private var autoMode: Bool = false
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
    private let pointsPerBeat = 60.0
    
    var body: some View {
        let padKeys = Array(midiPeaksPerPad.keys).sorted()
        let padCount = padKeys.count
        
        ViewContainer(title: "Oscilloscope", footer: "Shows the timing of MIDI drum hits and metronome ticks.") {
            ZStack {
                GeometryReader { geometry in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let yAxisX = width / 2
                    let metronomeColor = Color.gray.opacity(0.7)
                    let now = Date()
                    let times = (0..<sampleRate).map { i in
                        now.addingTimeInterval(-windowSeconds + windowSeconds * Double(i) / Double(sampleRate))
                    }
                    ZStack {
                        // Coordinate grid
                        Path { path in
                            // Vertical y-axis
                            path.move(to: CGPoint(x: yAxisX, y: 0))
                            path.addLine(to: CGPoint(x: yAxisX, y: height))
                        }
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundColor(.gray.opacity(0.5))

                        let bandHeight = height / CGFloat(max(padCount, 1))

                        // Background bands for each pad
                        ForEach(padKeys.enumerated().map({ ($0.offset, $0.element) }), id: \.1) { idx, noteIdx in
                            let bandY = bandHeight * CGFloat(idx)
                            Rectangle()
                                .fill(padColors[idx % padColors.count].opacity(0.08))
                                .frame(width: width, height: bandHeight)
                                .position(x: width/2, y: bandY + bandHeight/2)
                        }

                        // Metronome line (spans full height, based on bottom, with glow)
                        Path { path in
                            for (i, t) in times.enumerated() {
                                let x = CGFloat(i) / CGFloat(sampleRate - 1) * width
                                let peak = metronomePeaks.contains { abs($0.timeIntervalSince(t)) < 0.01 }
                                let baseY = height - 2 // small offset from bottom
                                let y = baseY - (peak ? height * 0.9 : 0)
                                if i == 0 {
                                    path.move(to: CGPoint(x: x, y: baseY))
                                }
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        .stroke(metronomeColor, lineWidth: 1)

                        // MIDI lines per pad (stacked, overlayed)
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
                                // Pad line centered vertically in band
                                Path { path in
                                    let bandCenterY = bandHeight / 2
                                    for (i, t) in times.enumerated() {
                                        let x = CGFloat(i) / CGFloat(sampleRate - 1) * width
                                        let peak = midiPeaksPerPad[noteIdx]?.contains { abs($0.timeIntervalSince(t)) < 0.01 } ?? false
                                        let y = bandCenterY + (peak ? -bandHeight * 0.4 : 0)
                                        if i == 0 {
                                            path.move(to: CGPoint(x: x, y: bandCenterY))
                                        }
                                        path.addLine(to: CGPoint(x: x, y: y))
                                    }
                                }
                                .stroke(color, lineWidth: 2)
                                .frame(height: bandHeight)
                                .offset(y: 0)
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
                    HStack(spacing: 16) {
                        Toggle("Auto", isOn: $autoMode)
//                            .toggleStyle(.checkbox)
                            .frame(width: 60)
                        HStack {
                            Text("Window (s):")
                            Slider(value: $windowSeconds, in: 1.0...6.1, step: 1.0)
                                .frame(width: 120)
                                .disabled(autoMode)
                            Text(String(format: "%.2f", windowSeconds))
                                .frame(width: 48, alignment: .leading)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .onAppear {
            startTimer()
            setupObservers()
        }
        .onDisappear {
            stopTimer()
        }
        .onChange(of: autoMode) { newValue, _ in
            if newValue {
                windowSeconds = beatsToShow * (60.0 / (midiManager.bpm))
            }
        }
        .onChange(of: midiManager.bpm) { newValue, _ in
            if autoMode {
                windowSeconds = beatsToShow * (60.0 / newValue)
            }
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            let now = Date()
            // Use the correct window for filtering
            metronomePeaks = metronomePeaks.filter { now.timeIntervalSince($0) < windowSeconds }
            midiPeaks = midiPeaks.filter { now.timeIntervalSince($0) < windowSeconds }
            for note in midiPeaksPerPad.keys {
                midiPeaksPerPad[note] = midiPeaksPerPad[note]?.filter { now.timeIntervalSince($0) < windowSeconds }
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(forName: .metronomeTickNotification, object: nil, queue: .main) { notification in
            metronomePeaks.append(Date())
        }
        NotificationCenter.default.addObserver(forName: .midiMessageReceived, object: nil, queue: .main) { notification in
            if let message = notification.object as? MIDIMessage {
                midiPeaks.append(Date())
                midiPeaksPerPad[message.note, default: []].append(Date())
            }
        }
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
