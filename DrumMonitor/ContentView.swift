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
            
            // MIDI Source Selection
            MIDISourceSelectionView(selectedSource: $selectedSource)
            
            // Last MIDI Message
            VStack(alignment: .leading, spacing: 10) {
                Text("Last MIDI Message:")
                    .font(.headline)
                
                if let message = midiManager.lastMessage {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("Pad:")
                                .bold()
                            Text(message.drumPad)
                        }
                        
                        HStack {
                            Text("Velocity:")
                                .bold()
                            Text("\(message.velocity)")
                            
                            // Velocity bar
                            ProgressView(value: Double(message.velocity), total: 127.0)
                                .frame(width: 100)
                        }
                        
                        HStack {
                            Text("Note:")
                                .bold()
                            Text("\(message.note)")
                            
                            Text("Channel:")
                                .bold()
                            Text("\(message.channel + 1)")
                        }
                    }
                } else {
                    Text("No MIDI data received")
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)
            
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
