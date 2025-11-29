//
//  MetronomeView.swift
//  DrumMonitor
//
//  Created by Dirk Clemens on 26.11.25.
//

import SwiftUI
import AVFoundation

struct MetronomeView: View {
    @State private var bpm: Double = 120
    @State private var isRunning = false
    @State private var timer: Timer?
    @State private var audioEngine = AVAudioEngine()
    @State private var player = AVAudioPlayerNode()
    @State private var currentBeat = 0
    @State private var midiMessageTimestamps: [Date] = []
    @State private var midiBPM: Double = 0
    @State private var midiAverageBPM: Double = 0
    @State private var midiBPMTimer: Timer?
    
    private let bpmKey = "DrumMonitor_BPM"
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Metronome")
                .font(.headline)
                .bold()
            
            // BPM Display
            Text(isRunning ? "\(Int(bpm)) BPM" : "\(Int(midiAverageBPM)) BPM (MIDI avg)" )
                .font(.title2)
                .bold()
            
            // BPM Slider
            VStack {
                Text("Tempo")
                    .font(.caption)
                Slider(value: $bpm, in: 60...200, step: 1)
                    .onChange(of: bpm) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: bpmKey)
                        if isRunning {
                            restartMetronome()
                        }
                    }
                HStack {
                    Text("60")
                        .font(.caption2)
                    Spacer()
                    Text("200")
                        .font(.caption2)
                }
            }
            
            // Beat Indicator
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { beat in
                    Circle()
                        .fill(beat == currentBeat % 4 && isRunning ? .blue : .gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                        .scaleEffect(beat == currentBeat % 4 && isRunning ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.1), value: currentBeat)
                }
            }
            
            // Start/Stop Button
            Button(action: toggleMetronome) {
                Text(isRunning ? "Stop" : "Start")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 80, height: 35)
                    .background(isRunning ? .red : .green)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
//        .frame(minHeight: 100)
        .onAppear {
            setupAudio()
            setupMIDICounter()
            if let storedBPM = UserDefaults.standard.value(forKey: bpmKey) as? Double {
                bpm = storedBPM
            } else {
                bpm = 120
            }
        }
        .onDisappear {
            stopMetronome()
            stopMIDICounter()
        }
    }
    
    private func setupAudio() {
        do {
            audioEngine.attach(player)
            audioEngine.connect(player, to: audioEngine.mainMixerNode, format: nil)
            
            try audioEngine.start()
        } catch {
            print("Audio setup failed: \(error)")
        }
    }
    
    private func toggleMetronome() {
        if isRunning {
            stopMetronome()
        } else {
            startMetronome()
        }
    }
    
    private func startMetronome() {
        isRunning = true
        currentBeat = -1
        let interval = 60.0 / bpm
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            currentBeat += 1
            playTick()
        }
        
        NotificationCenter.default.post(name: .metronomeStartNotification, object: nil)
        stopMIDICounter()
    }
    
    private func stopMetronome() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        currentBeat = 0
        
        NotificationCenter.default.post(name: .metronomeStopNotification, object: nil)
        setupMIDICounter()
    }
    
    private func restartMetronome() {
        stopMetronome()
        startMetronome()
    }
    
    private func playTick() {
        let tickTime = Date()
        
        // Send notification for timing sync
//        print("MetronomeView: Posting metronome tick notification")
        NotificationCenter.default.post(name: .metronomeTickNotification, object: tickTime)
        
        // Generate a simple tick sound using AVAudioPlayerNode
        let sampleRate = 44100.0
        let duration = 0.1
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioEngine.mainMixerNode.outputFormat(forBus: 0), frameCapacity: frameCount) else { return }
        
        buffer.frameLength = frameCount
        
        // Generate a simple beep
        let frequency: Float = currentBeat % 4 == 0 ? 800 : 400 // Higher pitch on downbeat
        let amplitude: Float = 0.3
        
        for frame in 0..<Int(frameCount) {
            let value = sin(2.0 * Float.pi * frequency * Float(frame) / Float(sampleRate)) * amplitude
            buffer.floatChannelData?[0][frame] = value
            if buffer.format.channelCount > 1 {
                buffer.floatChannelData?[1][frame] = value
            }
        }
        
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !player.isPlaying {
            player.play()
        }
    }
    
    private func setupMIDICounter() {
        NotificationCenter.default.addObserver(forName: .midiMessageReceived, object: nil, queue: .main) { notification in
            guard !isRunning else { return }
            let now = Date()
            midiMessageTimestamps.append(now)
            // Remove timestamps older than 10 seconds for rolling window
            midiMessageTimestamps = midiMessageTimestamps.filter { now.timeIntervalSince($0) <= 10 }
        }
        midiBPMTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            guard !isRunning else { midiAverageBPM = 0; return }
            if midiMessageTimestamps.count >= 2 {
                let first = midiMessageTimestamps.first!
                let last = midiMessageTimestamps.last!
                let totalTime = last.timeIntervalSince(first)
                let messageCount = midiMessageTimestamps.count - 1
                if totalTime > 0 {
                    midiAverageBPM = Double(messageCount) / totalTime * 60.0
                } else {
                    midiAverageBPM = 0
                }
            } else {
                midiAverageBPM = 0
            }
        }
    }
    private func stopMIDICounter() {
        midiBPMTimer?.invalidate()
        midiBPMTimer = nil
        midiMessageTimestamps.removeAll()
        midiAverageBPM = 0
    }
}

// Notification extensions
extension Notification.Name {
    static let metronomeTickNotification = Notification.Name("metronomeTickNotification")
    static let metronomeStartNotification = Notification.Name("metronomeStartNotification")
    static let metronomeStopNotification = Notification.Name("metronomeStopNotification")
}

#Preview {
    MetronomeView()
}
