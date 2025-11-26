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
//                Spacer()
                // MIDI Source Selection
                MIDISourceSelectionView(selectedSource: $selectedSource)
//                Spacer()
                // Last MIDI Message
                MIDIMessageDisplayView()
//                Spacer()
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)

            if midiManager.isConnected {
                
                Spacer()
                
                // Metronome
                MetronomeView()
            
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
    }
}

#Preview {
    ContentView()
}
