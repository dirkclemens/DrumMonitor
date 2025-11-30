import SwiftUI

struct OscilloscopeView: View {
    @EnvironmentObject var midiManager: MIDIManager
    @State private var metronomePeaks: [Date] = []
    @State private var midiPeaks: [Date] = []
    @State private var midiPeaksPerPad: [UInt8: [Date]] = [:]
    @State private var timer: Timer?
    private let windowSeconds: Double = 2.0
    private let sampleRate: Int = 240 // Number of points in the oscilloscope
    private let padColors: [Color] = [.red, .green, .orange, .purple, .pink, .yellow, .cyan, .mint, .indigo, .brown]
    
    var body: some View {
        ViewContainer(title: "Oscilloscope", footer: "Shows the timing of MIDI drum hits and metronome ticks.") {
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height
                let yAxisX = width / 2
                let centerY = height / 2
                let metronomeColor = Color.blue
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

                    let padKeys = Array(midiPeaksPerPad.keys).sorted()
                    let padCount = padKeys.count
                    let bandHeight = height / CGFloat(max(padCount, 1))

                    // Metronome line (spans full height, based on bottom)
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
                    .stroke(metronomeColor, lineWidth: 2)

                    // MIDI lines per pad (stacked, overlayed)
                    ForEach(padKeys.enumerated().map({ ($0.offset, $0.element) }), id: \.1) { idx, noteIdx in
                        let color = padColors[idx % padColors.count]
                        let bandCenterY = bandHeight * (CGFloat(idx) + 0.5)
                        Path { path in
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
                    }
                }
                .background(.black.opacity(0.05))
                .cornerRadius(8)
            }
            .frame(minHeight: 150)
            .frame(maxHeight: .infinity)
        }
//        .padding()
//        .background(Color.gray.opacity(0.1))
//        .cornerRadius(10)
        .onAppear {
            startTimer()
            setupObservers()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            let now = Date()
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
