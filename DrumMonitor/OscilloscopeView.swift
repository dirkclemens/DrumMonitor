import SwiftUI

struct OscilloscopeView: View {
    @EnvironmentObject var midiManager: MIDIManager
    @State private var metronomePeaks: [Date] = []
    @State private var midiPeaks: [Date] = []
    @State private var timer: Timer?
    private let windowSeconds: Double = 2.0
    private let sampleRate: Int = 240 // Number of points in the oscilloscope
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let centerY = height / 2
            let metronomeColor = Color.blue
            let midiColor = Color.red
            let now = Date()
            let times = (0..<sampleRate).map { i in
                now.addingTimeInterval(-windowSeconds + windowSeconds * Double(i) / Double(sampleRate))
            }
            ZStack {
                // Metronome line
                Path { path in
                    for (i, t) in times.enumerated() {
                        let x = CGFloat(i) / CGFloat(sampleRate - 1) * width
                        let peak = metronomePeaks.contains { abs($0.timeIntervalSince(t)) < 0.01 }
                        let y = centerY - (peak ? height * 0.35 : 0)
                        if i == 0 {
                            path.move(to: CGPoint(x: x, y: centerY))
                        }
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                .stroke(metronomeColor, lineWidth: 2)
                
                // MIDI line
                Path { path in
                    for (i, t) in times.enumerated() {
                        let x = CGFloat(i) / CGFloat(sampleRate - 1) * width
                        let peak = midiPeaks.contains { abs($0.timeIntervalSince(t)) < 0.01 }
                        let y = centerY + (peak ? height * 0.35 : 0)
                        if i == 0 {
                            path.move(to: CGPoint(x: x, y: centerY))
                        }
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                .stroke(midiColor, lineWidth: 2)
            }
        }
        .frame(height: 150)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
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
            midiPeaks.append(Date())
        }
    }
}

#Preview {
    OscilloscopeView()
}
