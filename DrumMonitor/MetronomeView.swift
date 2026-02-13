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
    @State private var feedbackPlayer = AVAudioPlayerNode()
    @State private var currentBeat = 0
    @State private var inputHitTimestamps: [Date] = []
    @State private var inputHitBPM: Double = 0
    @State private var inputHitBPMTimer: Timer?
    @State private var midiMessageObserver: NSObjectProtocol?
    @State private var volume: Double = 0.5
    @State private var lastMetronomeTick: Date?
    @State private var midiObserver: NSObjectProtocol?
    @State private var isGhostMuted: Bool = false
    @State private var tickCount: Int = 0
    
    private let bpmKey = "DrumMonitor_BPM"
    private let volumeKey = "DrumMonitor_Volume"
    
    var body: some View {
        ViewContainer(title: "Metronome", footer: "Set the tempo and start/stop the metronome.") {
            VStack(spacing: 10) {
                // BPM Display
                Text(metronomeDisplayText)
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

                // Beat Indicator (subdivision-aware)
                HStack(spacing: 6) {
                    let subdivision = max(1, midiManager.subdivision)
                    let totalTicks = subdivision * 4
                    ForEach(0..<totalTicks, id: \.self) { tick in
                        let isActive = isRunning && (tick == (currentBeat % totalTicks))
                        let isQuarter = tick % subdivision == 0
                        Circle()
                            .fill(isActive ? .blue : .gray.opacity(isQuarter ? 0.45 : 0.25))
                            .frame(width: isQuarter ? 11 : 7, height: isQuarter ? 11 : 7)
                            .scaleEffect(isActive ? 1.2 : 1.0)
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
                setupInputHitCounter()
                setupFeedbackObserver()
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
            .onChange(of: midiManager.subdivision) { _, _ in
                if isRunning {
                    restartMetronome()
                }
            }
            .onDisappear {
                stopMetronome()
                stopInputHitCounter()
                teardownFeedbackObserver()
            }
        }
    }
    
    private func setupAudio() {
        do {
            audioEngine.attach(player)
            audioEngine.attach(feedbackPlayer)
            audioEngine.connect(player, to: audioEngine.mainMixerNode, format: nil)
            audioEngine.connect(feedbackPlayer, to: audioEngine.mainMixerNode, format: nil)
            
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
        tickCount = 0
        isGhostMuted = false
        let interval = 60.0 / bpm / Double(max(1, midiManager.subdivision))
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            currentBeat += 1
            tickCount += 1
            playTick()
        }
        
        NotificationCenter.default.post(name: .metronomeStartNotification, object: nil)
        
        // Stop input hit counter when Metronome starts
        stopInputHitCounter()
    }
    
    private func stopMetronome() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        currentBeat = 0
        NotificationCenter.default.post(name: .metronomeStopNotification, object: nil)
        setupInputHitCounter()
    }
    
    private func restartMetronome() {
        stopMetronome()
        startMetronome()
    }
    
    private func playTick() {
        let tickTime = Date()
        lastMetronomeTick = tickTime
        NotificationCenter.default.post(name: .metronomeTickNotification, object: tickTime)
        let sampleRate = 44100.0
        let duration = 0.1
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioEngine.mainMixerNode.outputFormat(forBus: 0), frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        let subdivision = max(1, midiManager.subdivision)
        let accent = (tickCount % (subdivision * 4) == 1)
        let frequency: Float = accent ? 800 : 400
        let amplitude: Float = Float(volume)
        for frame in 0..<Int(frameCount) {
            let value = sin(2.0 * Float.pi * frequency * Float(frame) / Float(sampleRate)) * amplitude
            buffer.floatChannelData?[0][frame] = value
            if buffer.format.channelCount > 1 {
                buffer.floatChannelData?[1][frame] = value
            }
        }
        if shouldPlayMetronomeAudio() {
            player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
            if !player.isPlaying {
                player.play()
            }
        }
    }
    
    private func setupInputHitCounter() {
        // Remove previous observer if exists
        if let observer = midiMessageObserver {
            NotificationCenter.default.removeObserver(observer)
            midiMessageObserver = nil
        }
        // Count incoming MIDI note hits (drum pad hits)
        midiMessageObserver = NotificationCenter.default.addObserver(forName: .midiMessageReceived, object: nil, queue: .main) { notification in
            guard !isRunning else { return }
            if let message = notification.object as? MIDIMessage, (message.status & 0xF0) == 0x90, message.velocity > 0 {
                let now = Date()
                inputHitTimestamps.append(now)
                // Remove timestamps older than 4 seconds for rolling window
                inputHitTimestamps = inputHitTimestamps.filter { now.timeIntervalSince($0) <= 4 }
            }
        }
        inputHitBPMTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            guard !isRunning else { inputHitBPM = 0; return }
            if inputHitTimestamps.count >= 2 {
                let first = inputHitTimestamps.first!
                let last = inputHitTimestamps.last!
                let totalTime = last.timeIntervalSince(first)
                let hitCount = inputHitTimestamps.count - 1
                if totalTime > 0 {
                    inputHitBPM = Double(hitCount) / totalTime * 60.0
                } else {
                    inputHitBPM = 0
                }
            } else {
                inputHitBPM = 0
            }
        }
    }
    private func stopInputHitCounter() {
        inputHitBPMTimer?.invalidate()
        inputHitBPMTimer = nil
        inputHitTimestamps.removeAll()
        inputHitBPM = 0
        if let observer = midiMessageObserver {
            NotificationCenter.default.removeObserver(observer)
            midiMessageObserver = nil
        }
    }

    private var metronomeDisplayText: String {
        if isRunning {
            return "\(Int(bpm)) BPM"
        }
        if inputHitBPM > 0.5 {
            return "\(Int(inputHitBPM)) BPM (pad hits)"
        }
        return "No pad hits"
    }

    private func shouldPlayMetronomeAudio() -> Bool {
        guard midiManager.practiceMode == .ghost else { return true }
        let subdivision = max(1, midiManager.subdivision)
        let ticksPerBar = subdivision * 4
        let barIndex = (tickCount - 1) / ticksPerBar
        let cycle = max(1, midiManager.ghostBarsOn + midiManager.ghostBarsOff)
        let positionInCycle = barIndex % cycle
        let play = positionInCycle < max(1, midiManager.ghostBarsOn)
        isGhostMuted = !play
        return play
    }

    private func setupFeedbackObserver() {
        if let observer = midiObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        midiObserver = NotificationCenter.default.addObserver(forName: .midiMessageReceived, object: nil, queue: .main) { notification in
            guard midiManager.feedbackEnabled else { return }
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
            if abs(deviationMs) < midiManager.feedbackThresholdMs {
                return
            }
            playFeedbackTone(isEarly: deviationMs < 0)
        }
    }

    private func teardownFeedbackObserver() {
        if let observer = midiObserver {
            NotificationCenter.default.removeObserver(observer)
            midiObserver = nil
        }
    }

    private func playFeedbackTone(isEarly: Bool) {
        let sampleRate = 44100.0
        let duration = 0.06
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioEngine.mainMixerNode.outputFormat(forBus: 0), frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        let frequency: Float = isEarly ? 900 : 300
        let amplitude: Float = 0.4
        for frame in 0..<Int(frameCount) {
            let value = sin(2.0 * Float.pi * frequency * Float(frame) / Float(sampleRate)) * amplitude
            buffer.floatChannelData?[0][frame] = value
            if buffer.format.channelCount > 1 {
                buffer.floatChannelData?[1][frame] = value
            }
        }
        feedbackPlayer.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !feedbackPlayer.isPlaying {
            feedbackPlayer.play()
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
