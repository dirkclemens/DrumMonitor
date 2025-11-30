//
//  ContentView.swift
//  DrumMonitor
//
//  Created by Dirk Clemens on 26.11.25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var midiManager: MIDIManager
    @State private var selectedSource: String?
    
    var body: some View {
        VStack(spacing: 10) {
//            Text("Drum Monitor")
//                .font(.largeTitle)
//                .bold()
            
            // Connection Status
//            HStack {
//                Circle()
//                    .fill(midiManager.isConnected ? .green : .red)
//                    .frame(width: 12, height: 12)
//                
//                Text(midiManager.isConnected ? "Connected" : "Disconnected")
//                    .font(.headline)
//            }
            
            HStack(alignment: .top, spacing: 10) {
                // MIDI Source Selection
                MIDISourceSelectionView(selectedSource: $selectedSource)
                // Last MIDI Message
                MIDIMessageDisplayView()
            }

            if midiManager.isConnected {
                    
                // Metronome
                MetronomeView()
                // Oscilloscope
                OscilloscopeView()
                // Deviation Visualizer
//                DeviationVisualizerView(
                // Timing Sync
//                TimingSyncView()
                // Velocity Visualization
//                VelocityView()
            }
            Spacer()
        }
        .padding()
        .onAppear {
            midiManager.refreshSources()
        }
        .onChange(of: midiManager.isConnected) {
            setWindowSize(connected: midiManager.isConnected)
        }
    }
    
    private func setWindowSize(connected: Bool) {
        let minSize = NSSize(width: 800, height: 180) // Disconnected size
        let maxSize = NSSize(width: 800, height: 700) // Connected size
        DispatchQueue.main.async {
            if let window = NSApp.windows.first {
                window.setContentSize(connected ? maxSize : minSize)
                window.minSize = connected ? maxSize : minSize
                window.maxSize = connected ? maxSize : minSize
            }
        }
    }
}

#Preview {
    ContentView()
}
