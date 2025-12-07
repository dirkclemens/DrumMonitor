//
//  MetronomeView.swift
//  DrumMonitor
//
//  Created by Dirk Clemens on 26.11.25.
//

import SwiftUI
import AVFoundation

struct MetronomeView: View {
    @EnvironmentObject var midiManager: MIDIManager
    @State private var bpm: Double = 120
    @State private var isRunning = false
    @State private var timer: Timer?
    @State private var audioEngine = AVAudioEngine()
    @State private var player = AVAudioPlayerNode()
    @State private var currentBeat = 0
    @State private var midiClockTimestamps: [Date] = []
    @State private var midiClockBPM: Double = 0
    @State private var midiClockBPMTimer: Timer?
    @State private var midiMessageObserver: NSObjectProtocol?
    @State private var volume: Double = 0.5
    
    private let bpmKey = "DrumMonitor_BPM"
    private let volumeKey = "DrumMonitor_Volume"
    
    var body: some View {
        ViewContainer(title: "Metronome", footer: "Set the tempo and start/stop the metronome.") {
            VStack(spacing: 10) {
                // BPM Display
                Text(isRunning ? "\(Int(bpm)) BPM" : "\(Int(midiClockBPM)) BPM (MIDI clock)")
                    .font(.title2)
                    .bold()
                
                // BPM Slider
                VStack {
                    Text("Tempo")
                        .font(.caption)
                    Slider(value: $bpm, in: 60...180, step: 5)
                        .onChange(of: bpm) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: bpmKey)
                            midiManager.bpm = newValue // keep global bpm in sync
                            if isRunning {
                                restartMetronome()
                            }
                        }
                    HStack {
                        Text("60")
                            .font(.caption2)
                        Spacer()
                        Text("180")
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
                
                // Start/Stop Button + Volume Slider
                HStack(spacing: 12) {
                    Button(action: toggleMetronome) {
                        Text(isRunning ? "Stop" : "Start")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(isRunning ? .red : .green)
                    .frame(width: 80, height: 35)
                    .cornerRadius(8)
                    
                    // Volume slider
                    HStack(spacing: 4) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.caption)
                        Slider(value: $volume, in: 0.0...1.0, step: 0.1)
                            .frame(width: 80)
                            .onChange(of: volume) { _, newValue in
                                UserDefaults.standard.set(newValue, forKey: volumeKey)
                            }
                    }
                }
            }
            .onAppear {
                setupAudio()
                setupMIDIClockCounter()
                if let storedBPM = UserDefaults.standard.value(forKey: bpmKey) as? Double {
                    bpm = storedBPM
                } else {
                    bpm = 120
                }
                midiManager.bpm = bpm // keep global bpm in sync on appear
                if let storedVolume = UserDefaults.standard.value(forKey: volumeKey) as? Double {
                    volume = storedVolume
                } else {
                    volume = 0.5
                }
            }
            .onDisappear {
                stopMetronome()
                stopMIDIClockCounter()
            }
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
        
        // Stop MIDI clock counter when Metronome starts
        stopMIDIClockCounter()
    }
    
    private func stopMetronome() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        currentBeat = 0
        NotificationCenter.default.post(name: .metronomeStopNotification, object: nil)
        setupMIDIClockCounter()
    }
    
    private func restartMetronome() {
        stopMetronome()
        startMetronome()
    }
    
    private func playTick() {
        let tickTime = Date()
        NotificationCenter.default.post(name: .metronomeTickNotification, object: tickTime)
        let sampleRate = 44100.0
        let duration = 0.1
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioEngine.mainMixerNode.outputFormat(forBus: 0), frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        let frequency: Float = currentBeat % 4 == 0 ? 800 : 400
        let amplitude: Float = Float(volume)
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
    
    private func setupMIDIClockCounter() {
        // Remove previous observer if exists
        if let observer = midiMessageObserver {
            NotificationCenter.default.removeObserver(observer)
            midiMessageObserver = nil
        }
        midiMessageObserver = NotificationCenter.default.addObserver(forName: .midiMessageReceived, object: nil, queue: .main) { notification in
            guard !isRunning else { return }
            // Only count Note On messages (drum pad hits)
            if let message = notification.object as? MIDIMessage, (message.status & 0xF0) == 0x90, message.velocity > 0 {
                let now = Date()
                midiClockTimestamps.append(now)
                // Remove timestamps older than 10 seconds for rolling window
                midiClockTimestamps = midiClockTimestamps.filter { now.timeIntervalSince($0) <= 4 }
            }
        }
        midiClockBPMTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            guard !isRunning else { midiClockBPM = 0; return }
            if midiClockTimestamps.count >= 2 {
                let first = midiClockTimestamps.first!
                let last = midiClockTimestamps.last!
                let totalTime = last.timeIntervalSince(first)
                let hitCount = midiClockTimestamps.count - 1
                if totalTime > 0 {
                    // Hits per minute
                    midiClockBPM = Double(hitCount) / totalTime * 60.0
                } else {
                    midiClockBPM = 0
                }
            } else {
                midiClockBPM = 0
            }
        }
    }
    private func stopMIDIClockCounter() {
        midiClockBPMTimer?.invalidate()
        midiClockBPMTimer = nil
        midiClockTimestamps.removeAll()
        midiClockBPM = 0
        if let observer = midiMessageObserver {
            NotificationCenter.default.removeObserver(observer)
            midiMessageObserver = nil
        }
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
