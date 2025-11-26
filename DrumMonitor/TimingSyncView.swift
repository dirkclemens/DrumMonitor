//
//  TimingSyncView.swift
//  DrumMonitor
//
//  Created by Dirk Clemens on 26.11.25.
//

import SwiftUI

struct TimingSyncView: View {
    @EnvironmentObject var midiManager: MIDIManager
    @State private var metronomeBeats: [Date] = []
    @State private var timingDeviations: [Double] = []
    @State private var lastMidiTime: Date?
    @State private var isListening = false
    @State private var currentDeviation: Double = 0
    @State private var averageDeviation: Double = 0
    @State private var accuracy: String = "Perfect"
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Timing Sync")
                .font(.headline)
                .bold()
            
            // Current Deviation Display
            VStack(spacing: 8) {
                Text("Current Deviation")
                    .font(.caption)
                
                Text("\(Int(abs(currentDeviation * 1000)))ms")
                    .font(.title2)
                    .bold()
                    .foregroundColor(deviationColor)
                
                Text(accuracy)
                    .font(.caption)
                    .foregroundColor(deviationColor)
            }
            
            // Visual Timing Indicator
            HStack(spacing: 4) {
                Rectangle()
                    .fill(.red.opacity(0.3))
                    .frame(width: 40, height: 8)
                
                Rectangle()
                    .fill(.yellow.opacity(0.5))
                    .frame(width: 20, height: 8)
                
                Rectangle()
                    .fill(.green)
                    .frame(width: 20, height: 12)
                
                Rectangle()
                    .fill(.yellow.opacity(0.5))
                    .frame(width: 20, height: 8)
                
                Rectangle()
                    .fill(.red.opacity(0.3))
                    .frame(width: 40, height: 8)
            }
            .overlay(
                Rectangle()
                    .fill(.blue)
                    .frame(width: 2, height: 16)
                    .offset(x: CGFloat(currentDeviation * 500)) // Scale for visualization
                    .animation(.easeInOut(duration: 0.1), value: currentDeviation)
            )
            
            // Statistics
            VStack(spacing: 5) {
                HStack {
                    Text("Average:")
                        .font(.caption2)
                    Spacer()
                    Text("\(Int(abs(averageDeviation * 1000)))ms")
                        .font(.caption2)
                        .bold()
                }
                
                HStack {
                    Text("Samples:")
                        .font(.caption2)
                    Spacer()
                    Text("\(timingDeviations.count)")
                        .font(.caption2)
                        .bold()
                }
            }
            
            // Control Buttons
            HStack(spacing: 10) {
                Button(action: toggleListening) {
                    Text(isListening ? "Stop" : "Start")
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 25)
                        .background(isListening ? .red : .green)
                        .cornerRadius(5)
                }
                
                Button(action: reset) {
                    Text("Reset")
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 25)
                        .background(.blue)
                        .cornerRadius(5)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
        .frame(minHeight: 100)
        .onReceive(NotificationCenter.default.publisher(for: .metronomeTickNotification)) { notification in
            if let tickTime = notification.object as? Date, isListening {
                recordMetronomeTick(at: tickTime)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .midiMessageReceived)) { _ in
            if isListening {
                recordMidiMessage()
            }
        }
    }
    
    private var deviationColor: Color {
        let absDeviation = abs(currentDeviation * 1000)
        if absDeviation < 20 {
            return .green
        } else if absDeviation < 50 {
            return .yellow
        } else {
            return .red
        }
    }
    
    private func toggleListening() {
        isListening.toggle()
        if !isListening {
            reset()
        }
    }
    
    private func reset() {
        metronomeBeats.removeAll()
        timingDeviations.removeAll()
        lastMidiTime = nil
        currentDeviation = 0
        averageDeviation = 0
        accuracy = "Perfect"
    }
    
    private func recordMetronomeTick(at time: Date) {
        metronomeBeats.append(time)
        
        // Keep only recent beats (last 10 seconds)
        let cutoff = time.addingTimeInterval(-10)
        metronomeBeats = metronomeBeats.filter { $0 > cutoff }
    }
    
    private func recordMidiMessage() {
        let now = Date()
        lastMidiTime = now
        
        // Find the closest metronome beat
        guard let closestBeat = findClosestBeat(to: now) else { return }
        
        let deviation = now.timeIntervalSince(closestBeat)
        currentDeviation = deviation
        
        // Add to statistics
        timingDeviations.append(abs(deviation))
        if timingDeviations.count > 100 {
            timingDeviations.removeFirst()
        }
        
        // Calculate average
        if !timingDeviations.isEmpty {
            averageDeviation = timingDeviations.reduce(0, +) / Double(timingDeviations.count)
        }
        
        // Update accuracy description
        updateAccuracy()
    }
    
    private func findClosestBeat(to time: Date) -> Date? {
        guard !metronomeBeats.isEmpty else { return nil }
        
        return metronomeBeats.min { beat1, beat2 in
            abs(time.timeIntervalSince(beat1)) < abs(time.timeIntervalSince(beat2))
        }
    }
    
    private func updateAccuracy() {
        let absDeviation = abs(currentDeviation * 1000)
        
        switch absDeviation {
        case 0..<10:
            accuracy = "Perfect!"
        case 10..<20:
            accuracy = "Excellent"
        case 20..<50:
            accuracy = "Good"
        case 50..<100:
            accuracy = "Fair"
        default:
            accuracy = "Needs Work"
        }
    }
}

#Preview {
    TimingSyncView()
}
