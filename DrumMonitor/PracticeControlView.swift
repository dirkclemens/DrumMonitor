import SwiftUI

struct PracticeControlView: View {
    @EnvironmentObject var midiManager: MIDIManager

    var body: some View {
        ViewContainer(title: "Practice Controls", footer: "Configure focus and practice mode.") {
            VStack(spacing: 10) {
                HStack {
                    Text("Focus Pad")
                        .font(.caption)
                    Picker("Focus Pad", selection: $midiManager.focusPad) {
                        Text("All").tag(UInt8?.none)
                        ForEach(midiManager.seenNotes, id: \.self) { note in
                            Text(midiManager.drumPadName(for: note))
                                .tag(UInt8?.some(note))
                        }
                    }
                    .frame(width: 160)
                }

                HStack {
                    Text("Mode")
                        .font(.caption)
                    Picker("Mode", selection: $midiManager.practiceMode) {
                        ForEach(PracticeMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                HStack {
                    Text("Subdivision")
                        .font(.caption)
                    Picker("Subdivision", selection: $midiManager.subdivision) {
                        Text("1/4").tag(1)
                        Text("1/8").tag(2)
                        Text("1/16").tag(4)
                    }
                    .frame(width: 140)
                }

                if midiManager.practiceMode == .ghost {
                    HStack {
                        Text("Ghost On")
                            .font(.caption)
                        Stepper("\(midiManager.ghostBarsOn) bars", value: $midiManager.ghostBarsOn, in: 1...16)
                            .labelsHidden()
                        Text("Ghost Off")
                            .font(.caption)
                        Stepper("\(midiManager.ghostBarsOff) bars", value: $midiManager.ghostBarsOff, in: 1...16)
                            .labelsHidden()
                    }
                }

                Toggle("Auditory feedback", isOn: $midiManager.feedbackEnabled)
                    .toggleStyle(.switch)
                if midiManager.feedbackEnabled {
                    HStack {
                        Text("Threshold \(Int(midiManager.feedbackThresholdMs)) ms")
                            .font(.caption)
                        Slider(value: $midiManager.feedbackThresholdMs, in: 5...60, step: 5)
                            .frame(width: 140)
                    }
                }
            }
        }
    }
}

#Preview {
    PracticeControlView()
        .environmentObject(MIDIManager())
}
