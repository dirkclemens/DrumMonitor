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
        VStack {
            Text("Velocity Visualization")
                .font(.headline)
                .padding(.bottom, 5)
            
            Text("Current Velocity: \(Int(currentVelocity))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height
                let centerY = height / 2
                let amplitude = currentVelocity / 127.0 * (height * 0.4) // Scale velocity to amplitude
                let yAxisX = width / 2
                let line50YPos = centerY - (height * 0.4) * 0.5
                let line100YPos = centerY - (height * 0.4)
                let line50YNeg = centerY + (height * 0.4) * 0.5
                let line100YNeg = centerY + (height * 0.4)
                
                ZStack {
                    // Coordinate grid
                    Path { path in
                        // Vertical y-axis
                        path.move(to: CGPoint(x: yAxisX, y: 0))
                        path.addLine(to: CGPoint(x: yAxisX, y: height))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundColor(.gray.opacity(0.5))
                    
                    // Horizontal dotted lines at +50%, +100%, -50%, -100% amplitude
                    Path { path in
                        // Positive side
                        path.move(to: CGPoint(x: 0, y: line50YPos))
                        path.addLine(to: CGPoint(x: width, y: line50YPos))
                        path.move(to: CGPoint(x: 0, y: line100YPos))
                        path.addLine(to: CGPoint(x: width, y: line100YPos))
                        // Negative side
                        path.move(to: CGPoint(x: 0, y: line50YNeg))
                        path.addLine(to: CGPoint(x: width, y: line50YNeg))
                        path.move(to: CGPoint(x: 0, y: line100YNeg))
                        path.addLine(to: CGPoint(x: width, y: line100YNeg))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
                    .foregroundColor(.gray.opacity(0.4))
                    
                    // Sine wave
                    Path { path in
                        let points = 200
                        let stepX = width / CGFloat(points)
                        for i in 0...points {
                            let x = CGFloat(i) * stepX
                            let normalizedX = Double(i) / Double(points) * 4 * .pi // 2 complete cycles
                            let y = centerY + CGFloat(sin(normalizedX + animationPhase) * amplitude)
                            if i == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(
                        LinearGradient(
                            colors: velocityColor(),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 2
                    )
                    .animation(.easeInOut(duration: 0.3), value: currentVelocity)
                    
                    // Center line
                    Rectangle()
                        .fill(.gray.opacity(0.3))
                        .frame(width: width, height: 1)
                        .position(x: width/2, y: centerY)
                }
            }
            .frame(minHeight: 150)
            .background(.black.opacity(0.05))
            .cornerRadius(8)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
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
                
                print("VelocityView: Received MIDI velocity \(message.velocity)")
            }
        }
    }
}

#Preview {
    VelocityView()
}
