import SwiftUI

final class OSKModel: ObservableObject {
    @Published var octave: Int = 4
    @Published var sustainOn: Bool = false
    @Published var activeKeyCodes: Set<Int> = []

    private var keyToNote: [Int: UInt8] = [:]
    private let midi: MIDIEngine?

    init(midi: MIDIEngine?) {
        self.midi = midi
    }

    func playKey(keyCode: Int, semitone: Int) {
        guard keyToNote[keyCode] == nil else { return }
        let note = UInt8(max(0, min(127, (octave + 1) * 12 + semitone)))
        keyToNote[keyCode] = note
        midi?.noteOn(note, velocity: 100)
        activeKeyCodes.insert(keyCode)
    }

    func releaseKey(keyCode: Int) {
        guard let note = keyToNote.removeValue(forKey: keyCode) else { return }
        midi?.noteOff(note)
        activeKeyCodes.remove(keyCode)
    }

    func shiftOctave(_ delta: Int) {
        let next = max(0, min(8, octave + delta))
        if next != octave { octave = next }
    }

    func setSustain(_ on: Bool) {
        guard on != sustainOn else { return }
        sustainOn = on
        midi?.cc(64, on ? 127 : 0)
    }

    func releaseAll() {
        for (_, note) in keyToNote {
            midi?.noteOff(note)
        }
        keyToNote.removeAll()
        activeKeyCodes.removeAll()
        if sustainOn { setSustain(false) }
    }
}
