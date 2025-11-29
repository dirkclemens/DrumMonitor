//
//  MIDIMessageDisplayView.swift
//  DrumMonitor
//
//  Created by Dirk Clemens on 26.11.25.
//

import SwiftUI

struct MIDIMessageDisplayView: View {
    @EnvironmentObject var midiManager: MIDIManager
    
    var body: some View {
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
        .frame(minHeight: 150)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.1)))
    }
}

#Preview {
    MIDIMessageDisplayView()
}
