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
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Metronome")
                .font(.headline)
                .bold()
            
            // BPM Display
            Text("\(Int(bpm)) BPM")
                .font(.title2)
                .bold()
            
            // BPM Slider
            VStack {
                Text("Tempo")
                    .font(.caption)
                Slider(value: $bpm, in: 60...200, step: 1)
                    .onChange(of: bpm) { _, _ in
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
        .frame(minHeight: 100)
        .onAppear {
            setupAudio()
        }
        .onDisappear {
            stopMetronome()
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
        currentBeat = 0
        let interval = 60.0 / bpm
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            playTick()
            currentBeat += 1
        }
    }
    
    private func stopMetronome() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        currentBeat = 0
    }
    
    private func restartMetronome() {
        stopMetronome()
        startMetronome()
    }
    
    private func playTick() {
        let tickTime = Date()
        
        // Send notification for timing sync
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
}

// Notification extensions
extension Notification.Name {
    static let metronomeTickNotification = Notification.Name("metronomeTickNotification")
}

#Preview {
    MetronomeView()
}
