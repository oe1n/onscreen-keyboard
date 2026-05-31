import Foundation

struct KeyDef: Hashable {
    let keyCode: Int
    let semitone: Int
    let isBlack: Bool
    let label: String
}

enum KeyMap {
    // macOS virtual key codes (kVK_ANSI_*)
    static let allKeys: [KeyDef] = [
        KeyDef(keyCode: 0,  semitone: 0,  isBlack: false, label: "A"),
        KeyDef(keyCode: 13, semitone: 1,  isBlack: true,  label: "W"),
        KeyDef(keyCode: 1,  semitone: 2,  isBlack: false, label: "S"),
        KeyDef(keyCode: 14, semitone: 3,  isBlack: true,  label: "E"),
        KeyDef(keyCode: 2,  semitone: 4,  isBlack: false, label: "D"),
        KeyDef(keyCode: 3,  semitone: 5,  isBlack: false, label: "F"),
        KeyDef(keyCode: 17, semitone: 6,  isBlack: true,  label: "T"),
        KeyDef(keyCode: 5,  semitone: 7,  isBlack: false, label: "G"),
        KeyDef(keyCode: 16, semitone: 8,  isBlack: true,  label: "Y"),
        KeyDef(keyCode: 4,  semitone: 9,  isBlack: false, label: "H"),
        KeyDef(keyCode: 32, semitone: 10, isBlack: true,  label: "U"),
        KeyDef(keyCode: 38, semitone: 11, isBlack: false, label: "J"),
        KeyDef(keyCode: 40, semitone: 12, isBlack: false, label: "K"),
        KeyDef(keyCode: 31, semitone: 13, isBlack: true,  label: "O"),
        KeyDef(keyCode: 37, semitone: 14, isBlack: false, label: "L"),
        KeyDef(keyCode: 35, semitone: 15, isBlack: true,  label: "P"),
        KeyDef(keyCode: 41, semitone: 16, isBlack: false, label: ";"),
        KeyDef(keyCode: 39, semitone: 17, isBlack: false, label: "'"),
    ]

    static let byKeyCode: [Int: KeyDef] = {
        var m: [Int: KeyDef] = [:]
        for k in allKeys { m[k.keyCode] = k }
        return m
    }()

    // Special keys
    static let zKey       = 6
    static let xKey       = 7
    static let tabKey     = 48
    static let escapeKey  = 53
    static let leftArrow  = 123
    static let rightArrow = 124
    static let leftShift  = 56
    static let rightShift = 60
    static let kKey       = 40  // for Cmd+K toggle
}
