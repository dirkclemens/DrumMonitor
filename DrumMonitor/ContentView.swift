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
        VStack(spacing: 20) {
            Text("Drum Monitor")
                .font(.largeTitle)
                .bold()
            
            // Connection Status
            HStack {
                Circle()
                    .fill(midiManager.isConnected ? .green : .red)
                    .frame(width: 12, height: 12)
                
                Text(midiManager.isConnected ? "Connected" : "Disconnected")
                    .font(.headline)
            }
            
            HStack(alignment: .top, spacing: 10) {
                // MIDI Source Selection
                MIDISourceSelectionView(selectedSource: $selectedSource)

                // Last MIDI Message
                MIDIMessageDisplayView()
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)

            if midiManager.isConnected {
                
                Spacer()
                
                // Metronome
                MetronomeView()
                
                // Oscilloscope
                OscilloscopeView()
            
                Spacer()

                // Timing Sync
                TimingSyncView()
                
                Spacer()
                
                VelocityView()
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
        let minSize = NSSize(width: 600, height: 180) // Disconnected size
        let maxSize = NSSize(width: 600, height: 700) // Connected size
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
