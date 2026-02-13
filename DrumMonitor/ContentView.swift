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
    @State private var windowObserver: NSObjectProtocol?
    @State private var windowMoveObserver: NSObjectProtocol?
    
    private let windowWidthKey = "DrumMonitor_WindowWidth"
    private let windowHeightKey = "DrumMonitor_WindowHeight"
    private let windowOriginXKey = "DrumMonitor_WindowOriginX"
    private let windowOriginYKey = "DrumMonitor_WindowOriginY"
    
    var body: some View {
        VStack(spacing: 10) {
            
            HStack(alignment: .top, spacing: 10) {
                // MIDI Source Selection
                MIDISourceSelectionView(selectedSource: $selectedSource)
                // Metronome
                MetronomeView()
                // Last MIDI Message
                MIDIMessageDisplayView()
                // Practice Controls
                PracticeControlView()
            }

//            if midiManager.isConnected {
                // Oscilloscope
                OscilloscopeView()
                // Deviation Meter
                DeviationMeterView()
                // Hit Scatter Timeline
                HitScatterTimelineView()
                // Timing Accuracy Score
                TimingAccuracyScoreView()
                // Pad Stats
                PadStatsView()
                // Deviation Visualizer
//                DeviationVisualizerView()
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
            startWindowSizeObserver()
        }
        .onDisappear {
            stopWindowSizeObserver()
        }
    }

    private func restoreWindowSize() {
        let width = UserDefaults.standard.double(forKey: windowWidthKey)
        let height = UserDefaults.standard.double(forKey: windowHeightKey)
        let originX = UserDefaults.standard.double(forKey: windowOriginXKey)
        let originY = UserDefaults.standard.double(forKey: windowOriginYKey)
        DispatchQueue.main.async {
            if let window = NSApp.windows.first {
                if width > 0 && height > 0 {
                    let size = NSSize(width: width, height: height)
                    window.setContentSize(size)
                }
                if originX != 0 || originY != 0 {
                    let origin = NSPoint(x: originX, y: originY)
                    window.setFrameOrigin(origin)
                }
            }
        }
    }

    private func startWindowSizeObserver() {
        if let observer = windowObserver {
            NotificationCenter.default.removeObserver(observer)
            windowObserver = nil
        }
        let saveHandler: (Notification) -> Void = { _ in
            guard let window = NSApp.windows.first else { return }
            let size = window.frame.size
            let origin = window.frame.origin
            UserDefaults.standard.set(size.width, forKey: windowWidthKey)
            UserDefaults.standard.set(size.height, forKey: windowHeightKey)
            UserDefaults.standard.set(origin.x, forKey: windowOriginXKey)
            UserDefaults.standard.set(origin.y, forKey: windowOriginYKey)
        }

        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: nil,
            queue: .main,
            using: saveHandler
        )

        windowMoveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: nil,
            queue: .main,
            using: saveHandler
        )
    }

    private func stopWindowSizeObserver() {
        if let observer = windowObserver {
            NotificationCenter.default.removeObserver(observer)
            windowObserver = nil
        }
        if let observer = windowMoveObserver {
            NotificationCenter.default.removeObserver(observer)
            windowMoveObserver = nil
        }
    }
}

#Preview {
    ContentView()
}
