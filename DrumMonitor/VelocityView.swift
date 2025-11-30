//
//  VelocityView.swift
//  DrumMonitor
//
//  Created by Dirk Clemens on 26.11.25.
//

import SwiftUI
import Combine

struct VelocityView: View {
    @EnvironmentObject var midiManager: MIDIManager
    @State private var currentVelocity: Double = 0
    @State private var velocityHistory: [Double] = []
    @State private var animationPhase: Double = 0
    @State private var timer: Timer?
    
    private let maxHistoryCount = 100
    
    var body: some View {
        ViewContainer(title: "Velocity View", footer: "Visualizes the velocity of incoming MIDI note-on messages.") {
            VStack(spacing: 10) {
//                Text("Velocity Visualization")
//                    .font(.headline)
//                    .padding(.bottom, 5)
                
                Text("Current Velocity: \(Int(currentVelocity))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack() {
                    VelocitySineWaveView(velocity: currentVelocity, animationPhase: animationPhase)
                        .frame(minHeight: 150)
                        .background(.black.opacity(0.05))
                        .cornerRadius(8)
                    
                    VUMeterView(level: currentVelocity / 127.0)
                        .frame(maxHeight: .infinity)
                        .frame(width: 30)
                }//HStack
                
            }//VStack
            //        .padding()
            //        .background(Color.gray.opacity(0.1))
            //        .cornerRadius(10)
        }
        .onAppear {
            startAnimation()
            setupNotificationObserver()
        }
        .onDisappear {
            stopAnimation()
        }
    }
    
    private func velocityColor() -> [Color] {
        let intensity = currentVelocity / 127.0
        if intensity < 0.3 {
            return [.blue, .cyan]
        } else if intensity < 0.7 {
            return [.green, .yellow]
        } else {
            return [.orange, .red]
        }
    }
    
    private func startAnimation() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            withAnimation(.linear(duration: 0.05)) {
                animationPhase += 0.1
                if animationPhase > 2 * .pi {
                    animationPhase -= 2 * .pi
                }
            }
            
            // Decay velocity over time
            if currentVelocity > 0 {
                currentVelocity *= 0.98
                if currentVelocity < 1 {
                    currentVelocity = 0
                }
            }
        }
    }
    
    private func stopAnimation() {
        timer?.invalidate()
        timer = nil
    }
    
    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: .midiMessageReceived,
            object: nil,
            queue: .main
        ) { notification in
            if let message = notification.object as? MIDIMessage,
               (message.status & 0xF0) == 0x90 && message.velocity > 0 {
                currentVelocity = Double(message.velocity)
                velocityHistory.append(currentVelocity)
                
                if velocityHistory.count > maxHistoryCount {
                    velocityHistory.removeFirst()
                }
                
//                print("VelocityView: Received MIDI velocity \(message.velocity)")
            }
        }
    }
}

#Preview {
    VelocityView()
}
