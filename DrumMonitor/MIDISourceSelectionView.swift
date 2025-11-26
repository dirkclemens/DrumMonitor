//
//  MIDISourceSelectionView.swift
//  DrumMonitor
//
//  Created by Dirk Clemens on 26.11.25.
//

import SwiftUI

struct MIDISourceSelectionView: View {
    @EnvironmentObject var midiManager: MIDIManager
    @Binding var selectedSource: String?
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("MIDI Sources:")
                .font(.headline)
            
            if midiManager.availableSources.isEmpty {
                Text("No MIDI sources available")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(midiManager.availableSources, id: \.self) { source in
                    HStack {
                        Text(source)
                        Spacer()
                        if selectedSource == source && midiManager.isConnected {
                            Button("Disconnect") {
                                midiManager.disconnect()
                                selectedSource = nil
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                        } else {
                            Button("Connect") {
                                midiManager.disconnect()
                                midiManager.connectToSource(named: source)
                                selectedSource = source
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            
            Button("Refresh") {
                midiManager.refreshSources()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

#Preview {
    MIDISourceSelectionView(selectedSource: .constant(nil))
        .environmentObject(MIDIManager())
}
