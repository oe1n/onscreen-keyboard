import CoreMIDI
import Foundation

enum MIDIEngineError: Error {
    case clientFailed(OSStatus)
    case sourceFailed(OSStatus)
}

final class MIDIEngine {
    private var client: MIDIClientRef = 0
    private var source: MIDIEndpointRef = 0

    init() throws {
        let name = "OnScreen Keyboard" as CFString
        var status = MIDIClientCreate(name, nil, nil, &client)
        guard status == noErr else { throw MIDIEngineError.clientFailed(status) }
        status = MIDISourceCreate(client, name, &source)
        guard status == noErr else { throw MIDIEngineError.sourceFailed(status) }
    }

    func noteOn(_ note: UInt8, velocity: UInt8 = 100, channel: UInt8 = 0) {
        send([0x90 | (channel & 0x0F), note & 0x7F, velocity & 0x7F])
    }

    func noteOff(_ note: UInt8, channel: UInt8 = 0) {
        send([0x80 | (channel & 0x0F), note & 0x7F, 0])
    }

    func cc(_ controller: UInt8, _ value: UInt8, channel: UInt8 = 0) {
        send([0xB0 | (channel & 0x0F), controller & 0x7F, value & 0x7F])
    }

    private func send(_ bytes: [UInt8]) {
        let bufferSize = 1024
        let buffer = UnsafeMutableRawPointer.allocate(
            byteCount: bufferSize,
            alignment: MemoryLayout<MIDIPacketList>.alignment
        )
        defer { buffer.deallocate() }
        let packetList = buffer.assumingMemoryBound(to: MIDIPacketList.self)
        let firstPacket = MIDIPacketListInit(packetList)
        _ = MIDIPacketListAdd(packetList, bufferSize, firstPacket, 0, bytes.count, bytes)
        MIDIReceived(source, packetList)
    }

    deinit {
        if source != 0 { MIDIEndpointDispose(source) }
        if client != 0 { MIDIClientDispose(client) }
    }
}
