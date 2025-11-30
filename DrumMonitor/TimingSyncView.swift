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
    @State private var deviationColor: Color = .green
    
    var body: some View {
        ViewContainer(title: "Timing Sync", footer: "Shows timing deviation between MIDI input and metronome") {
            
            VStack(spacing: 10) {
                //            Text("Timing Sync")
                //                .font(.headline)
                //                .bold()
                
                // Current Deviation Display
                VStack(spacing: 8) {
                    Text("Current Deviation")
                        .font(.caption)
                    
                    HStack(){
                        Text("\(Int(abs(currentDeviation * 1000)))ms")
                            .font(.title2)
                            .bold()
                            .foregroundColor(deviationColor)
                        
                        Text(accuracy)
                            .font(.title2)
                            .bold()
                            .foregroundColor(deviationColor)
                    }
                }
                
                // Visual Timing Indicator
                GeometryReader { geometry in
                    let totalSpacing: CGFloat = 28 // 7 gaps of 4 points each
                    let availableWidth = geometry.size.width - totalSpacing
                    let totalRelativeWidth: CGFloat = 100 // 100ms total range
                    let widthMultiplier = availableWidth / totalRelativeWidth
                    //                let thresholds: [Double] = [-50, -25, -10, 10, 25, 50]
                    //                let regionWidths: [CGFloat] = [25, 12.5, 7.5, 5, 5, 7.5, 12.5, 25]
                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(Color.red.opacity(0.3))
                            .frame(width: 25 * widthMultiplier, height: 8)
                        Rectangle()
                            .fill(Color.orange.opacity(0.5))
                            .frame(width: 12.5 * widthMultiplier, height: 10)
                        Rectangle()
                            .fill(Color.yellow.opacity(0.5))
                            .frame(width: 7.5 * widthMultiplier, height: 12)
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: 5 * widthMultiplier, height: 14)
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: 5 * widthMultiplier, height: 14)
                        Rectangle()
                            .fill(Color.yellow.opacity(0.5))
                            .frame(width: 7.5 * widthMultiplier, height: 12)
                        Rectangle()
                            .fill(Color.orange.opacity(0.5))
                            .frame(width: 12.5 * widthMultiplier, height: 10)
                        Rectangle()
                            .fill(Color.red.opacity(0.3))
                            .frame(width: 25 * widthMultiplier, height: 8)
                    }
                    .overlay(
                        Capsule()
                            .fill(deviationColor)
                            .frame(width: 10, height: 25)
                            .offset(x: CGFloat(max(-50, min(50, currentDeviation * 1000)) / 50) * (availableWidth / 2))
                            .animation(.easeInOut(duration: 0.1), value: currentDeviation)
                    )
                }
                .frame(height: 16)
                
                // Statistics
                VStack(spacing: 5) {
                    HStack {
                        Spacer()
                        Text("Average:")
                            .font(.caption2)
                        //                    Spacer()
                        Text("\(Int(abs(averageDeviation * 1000)))ms")
                            .font(.caption2)
                            .bold()
                        Spacer()
                    }
                    
                    HStack {
                        Spacer()
                        Text("Samples:")
                            .font(.caption2)
                        //                    Spacer()
                        Text("\(timingDeviations.count)")
                            .font(.caption2)
                            .bold()
                        Spacer()
                    }
                }
                
                // Control Buttons
                HStack(spacing: 10) {
                    //                Button(action: {}) {
                    //                    Text(isListening ? "Listening" : "Waiting")
                    //                        .font(.headline)
                    //                        .foregroundColor(.white)
                    //                        .frame(width: 80, height: 35)
                    //                        .background(isListening ? .green : .gray)
                    //                        .cornerRadius(8)
                    //                }
                    //                .disabled(true)
                    
                    Button(action: reset) {
                        Text("Reset")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 80, height: 35)
                            .background(.blue)
                            .cornerRadius(8)
                    }
                }
            }
        }
//        .padding()
//        .background(Color.gray.opacity(0.1))
//        .cornerRadius(10)
//        .frame(minHeight: 100)
        .onReceive(NotificationCenter.default.publisher(for: .metronomeTickNotification)) { notification in
//            print("TimingSyncView: Received metronome tick notification")
            if let tickTime = notification.object as? Date, isListening {
                recordMetronomeTick(at: tickTime)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .midiMessageReceived)) { notification in
//            print("TimingSyncView: Received MIDI message notification")
            if isListening {
                recordMidiMessage()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .metronomeStartNotification)) { _ in
//            print("TimingSyncView: Metronome started, enabling listening")
            isListening = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .metronomeStopNotification)) { _ in
//            print("TimingSyncView: Metronome stopped, disabling listening")
            isListening = false
            reset()
        }
    }
    
    private func updateAccuracy() {
        let absDeviation = abs(currentDeviation * 1000)
        
        switch absDeviation {
        case 0..<10:
            accuracy = "Perfect!"
            deviationColor = .green
        case 10..<25:
            accuracy = "Excellent"
            deviationColor = .yellow
        case 25..<50:
            accuracy = "Good"
            deviationColor = .orange
        case 50..<100:
            accuracy = "Fair"
            deviationColor = .red
        default:
            accuracy = "Needs Work"
            deviationColor = .red
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
    
    private func deviationToOffset(_ deviationMs: Double, regionWidths: [CGFloat], thresholds: [Double], widthMultiplier: CGFloat, availableWidth: CGFloat) -> CGFloat {
        let maxMs: Double = 50
        let minMs: Double = -50
        let clamped = min(max(deviationMs, minMs), maxMs)
        var x: CGFloat = 0
        var regionStartMs = minMs
        var regionStartX: CGFloat = 0
        for i in 0..<regionWidths.count {
            let regionEndMs: Double
            if i < 3 {
                regionEndMs = thresholds[i+1]
            } else if i == 3 {
                regionEndMs = thresholds[3]
            } else if i == 4 {
                regionEndMs = thresholds[4]
            } else if i < 7 {
                regionEndMs = thresholds[i-2]
            } else {
                regionEndMs = maxMs
            }
            let regionWidthPx = regionWidths[i] * widthMultiplier
            if clamped >= regionStartMs && clamped <= regionEndMs {
                let regionRangeMs = regionEndMs - regionStartMs
                let regionFrac = regionRangeMs != 0 ? (clamped - regionStartMs) / regionRangeMs : 0
                x = regionStartX + CGFloat(regionFrac) * regionWidthPx
                break
            }
            regionStartX += regionWidthPx
            regionStartMs = regionEndMs
        }
        return x - availableWidth / 2
    }
}
