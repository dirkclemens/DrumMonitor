//
//  MIDIManager.swift
//  DrumMonitor
//
//  Created by Dirk Clemens on 26.11.25.
//

import Foundation
import CoreMIDI
import Combine

struct MIDIMessage {
    let timestamp: CFTimeInterval
    let status: UInt8
    let note: UInt8
    let velocity: UInt8
    let channel: UInt8
    
    var drumPad: String {
        // Common MIDI drum map (General MIDI Level 1)
        switch note {
        case 36: return "Kick Drum"
        case 38, 40: return "Snare Drum"
        case 42, 44: return "Hi-Hat"
        case 46: return "Open Hi-Hat"
        case 41, 43: return "Low Tom"
        case 45, 47: return "Mid Tom"
        case 48, 50: return "High Tom"
        case 49, 57: return "Crash Cymbal"
        case 51, 59: return "Ride Cymbal"
        default: return "Drum \(note)"
        }
    }
}

class MIDIManager: ObservableObject {
    @Published var lastMessage: MIDIMessage?
    @Published var isConnected = false
    @Published var availableSources: [String] = []
    
    private var midiClient: MIDIClientRef = 0
    private var inputPort: MIDIPortRef = 0
    private let messageSubject = PassthroughSubject<MIDIMessage, Never>()
    
    var messagePublisher: AnyPublisher<MIDIMessage, Never> {
        messageSubject.eraseToAnyPublisher()
    }
    
    init() {
        setupMIDI()
        refreshSources()
    }
    
    deinit {
        cleanup()
    }
    
    private func setupMIDI() {
        let status = MIDIClientCreateWithBlock("DrumMonitorClient" as CFString, &midiClient) { notification in
            self.handleMIDINotification(notification)
        }
        
        guard status == noErr else {
            print("Error creating MIDI client: \(status)")
            return
        }
        
        let inputStatus = MIDIInputPortCreateWithBlock(midiClient, "DrumMonitorInput" as CFString, &inputPort) { packetList, srcConnRefCon in
            self.handleMIDIPackets(packetList)
        }
        
        guard inputStatus == noErr else {
            print("Error creating MIDI input port: \(inputStatus)")
            return
        }
    }
    
    private func handleMIDINotification(_ notification: UnsafePointer<MIDINotification>) {
        DispatchQueue.main.async {
            self.refreshSources()
        }
    }
    
    private func handleMIDIPackets(_ packetList: UnsafePointer<MIDIPacketList>) {
        let packets = MIDIPacketListIterator(packetList)
        
        for packet in packets {
            processMIDIPacket(packet)
        }
    }
    
    private func processMIDIPacket(_ packet: MIDIPacket) {
        let data = withUnsafePointer(to: packet.data) {
            $0.withMemoryRebound(to: UInt8.self, capacity: Int(packet.length)) {
                Array(UnsafeBufferPointer(start: $0, count: Int(packet.length)))
            }
        }
        
        guard data.count >= 3 else { return }
        
        let status = data[0]
        let note = data[1]
        let velocity = data[2]
        let channel = status & 0x0F
        
        // Filter for Note On messages (0x90) with velocity > 0
        if (status & 0xF0) == 0x90 && velocity > 0 {
            let message = MIDIMessage(
                timestamp: CFAbsoluteTimeGetCurrent(),
                status: status,
                note: note,
                velocity: velocity,
                channel: channel
            )
            
            DispatchQueue.main.async {
                self.lastMessage = message
            }
            
            messageSubject.send(message)
            
            // Send notification for timing sync
            print("MIDIManager: Posting MIDI message notification")
            NotificationCenter.default.post(name: .midiMessageReceived, object: message)
        }
    }
    
    func refreshSources() {
        var sources: [String] = []
        let sourceCount = MIDIGetNumberOfSources()
        
        for i in 0..<sourceCount {
            let source = MIDIGetSource(i)
            var name: Unmanaged<CFString>?
            let status = MIDIObjectGetStringProperty(source, kMIDIPropertyName, &name)
            
            if status == noErr, let name = name?.takeRetainedValue() {
                sources.append(String(name))
            }
        }
        
        DispatchQueue.main.async {
            self.availableSources = sources
        }
    }
    
    func connectToSource(named sourceName: String) {
        let sourceCount = MIDIGetNumberOfSources()
        
        for i in 0..<sourceCount {
            let source = MIDIGetSource(i)
            var name: Unmanaged<CFString>?
            let status = MIDIObjectGetStringProperty(source, kMIDIPropertyName, &name)
            
            if status == noErr, let name = name?.takeRetainedValue(), String(name) == sourceName {
                let connectStatus = MIDIPortConnectSource(inputPort, source, nil)
                
                DispatchQueue.main.async {
                    self.isConnected = (connectStatus == noErr)
                }
                
                if connectStatus == noErr {
                    print("Connected to MIDI source: \(sourceName)")
                } else {
                    print("Failed to connect to MIDI source: \(connectStatus)")
                }
                break
            }
        }
    }
    
    func disconnect() {
        let sourceCount = MIDIGetNumberOfSources()
        
        for i in 0..<sourceCount {
            let source = MIDIGetSource(i)
            MIDIPortDisconnectSource(inputPort, source)
        }
        
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }
    
    private func cleanup() {
        disconnect()
        
        if inputPort != 0 {
            MIDIPortDispose(inputPort)
        }
        
        if midiClient != 0 {
            MIDIClientDispose(midiClient)
        }
    }
}

// MIDI Packet List Iterator Helper
struct MIDIPacketListIterator: Sequence, IteratorProtocol {
    private let packetList: UnsafePointer<MIDIPacketList>
    private var currentPacket: UnsafePointer<MIDIPacket>?
    private var remainingPackets: UInt32
    
    init(_ packetList: UnsafePointer<MIDIPacketList>) {
        self.packetList = packetList
        self.remainingPackets = packetList.pointee.numPackets
        self.currentPacket = remainingPackets > 0 ? withUnsafePointer(to: packetList.pointee.packet) { $0 } : nil
    }
    
    mutating func next() -> MIDIPacket? {
        guard remainingPackets > 0, let packet = currentPacket else {
            return nil
        }
        
        let result = packet.pointee
        remainingPackets -= 1
        
        if remainingPackets > 0 {
            // Convert mutable pointer to immutable pointer
            let nextPacketPtr = MIDIPacketNext(UnsafeMutablePointer(mutating: packet))
            currentPacket = UnsafePointer(nextPacketPtr)
        } else {
            currentPacket = nil
        }
        
        return result
    }
}

// Notification extensions
extension Notification.Name {
    static let midiMessageReceived = Notification.Name("midiMessageReceived")
}
