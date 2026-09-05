//
//  DrumMonitorApp.swift
//  DrumMonitor
//
//  Created by Dirk Clemens on 26.11.25.
//

import SwiftUI

@main
struct DrumMonitorApp: App {
    @StateObject private var midiManager = MIDIManager()

    init() {
        UpdateChecker.checkForUpdate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(midiManager)
        }
    }
}
