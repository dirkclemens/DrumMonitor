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
    
    private let windowWidthKey = "DrumMonitor_WindowWidth"
    private let windowHeightKey = "DrumMonitor_WindowHeight"
    
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
                // Metronome
                MetronomeView()
                // Last MIDI Message
                MIDIMessageDisplayView()
            }

//            if midiManager.isConnected {
                // Oscilloscope
                OscilloscopeView()
                // Deviation Visualizer
//                DeviationVisualizerView(
                // Timing Sync
//                TimingSyncView()
                // Velocity Visualization
//                VelocityView()
//            }
            Spacer()
        }
        .padding()
        .onAppear {
            midiManager.refreshSources()
            restoreWindowSize()
        }
//        .onChange(of: midiManager.isConnected) {
//            setWindowSize(connected: midiManager.isConnected)
//        }
    }
    
    private func setWindowSize() {
        let defaultSize = NSSize(width: 800, height: 180)

        DispatchQueue.main.async {
            if let window = NSApp.windows.first {
                let width = UserDefaults.standard.double(forKey: windowWidthKey)
                let height = UserDefaults.standard.double(forKey: windowHeightKey)
                let size: NSSize
                if width > 0 && height > 0 {
                    size = NSSize(width: width, height: height)
                } else {
                    size = defaultSize
                }
                window.setContentSize(size)
                // Save size
                UserDefaults.standard.set(size.width, forKey: windowWidthKey)
                UserDefaults.standard.set(size.height, forKey: windowHeightKey)
            }
        }
    }
    private func restoreWindowSize() {
        let width = UserDefaults.standard.double(forKey: windowWidthKey)
        let height = UserDefaults.standard.double(forKey: windowHeightKey)
        if width > 0 && height > 0 {
            DispatchQueue.main.async {
                if let window = NSApp.windows.first {
                    let size = NSSize(width: width, height: height)
                    window.setContentSize(size)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
