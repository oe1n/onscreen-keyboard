import SwiftUI

private let NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

private func noteName(_ midi: Int) -> String {
    NOTE_NAMES[((midi % 12) + 12) % 12] + String(midi / 12 - 1)
}

struct PianoView: View {
    @ObservedObject var model: OSKModel

    var body: some View {
        VStack(spacing: 6) {
            header
            keyboard
            footer
        }
        .padding(10)
        .frame(width: 940, height: 230)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.88))
                .shadow(color: .black.opacity(0.5), radius: 16, x: 0, y: 8)
        )
    }

    private var header: some View {
        HStack {
            Pill(label: "OCT", value: "\(model.octave)", tint: .blue)
            Spacer()
            Text("OnScreen Keyboard · Virtual MIDI")
                .font(.system(size: 10, weight: .medium, design: .default))
                .foregroundColor(.white.opacity(0.45))
                .tracking(1.2)
            Spacer()
            Pill(label: "SUSTAIN", value: model.sustainOn ? "ON" : "OFF",
                 tint: model.sustainOn ? .orange : .gray)
        }
        .padding(.horizontal, 4)
    }

    private var keyboard: some View {
        GeometryReader { geo in
            let whites = KeyMap.allKeys.filter { !$0.isBlack }
            let blacks = KeyMap.allKeys.filter { $0.isBlack }
            let whiteW = geo.size.width / CGFloat(whites.count)

            ZStack(alignment: .topLeading) {
                ForEach(Array(whites.enumerated()), id: \.element.keyCode) { i, def in
                    WhiteKey(
                        label: def.label,
                        note: noteName((model.octave + 1) * 12 + def.semitone),
                        active: model.activeKeyCodes.contains(def.keyCode)
                    )
                    .frame(width: whiteW, height: geo.size.height)
                    .offset(x: CGFloat(i) * whiteW)
                }

                ForEach(blacks, id: \.keyCode) { def in
                    let prevIdx = whites.firstIndex { $0.semitone == def.semitone - 1 } ?? 0
                    let blackW = whiteW * 0.62
                    let x = CGFloat(prevIdx + 1) * whiteW - blackW / 2
                    BlackKey(
                        label: def.label,
                        active: model.activeKeyCodes.contains(def.keyCode)
                    )
                    .frame(width: blackW, height: geo.size.height * 0.62)
                    .offset(x: x)
                }
            }
        }
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var footer: some View {
        HStack {
            footerItem("Z / ⇧L / ←", "OCT−")
            Spacer()
            footerItem("X / ⇧R / →", "OCT+")
            Spacer()
            footerItem("Tab", "Sustain")
            Spacer()
            footerItem("⌘K", "Hide")
        }
        .font(.system(size: 9, weight: .regular))
        .foregroundColor(.white.opacity(0.35))
        .padding(.horizontal, 4)
    }

    private func footerItem(_ key: String, _ desc: String) -> some View {
        HStack(spacing: 4) {
            Text(key).foregroundColor(.white.opacity(0.55))
            Text(desc)
        }
    }
}

private struct Pill: View {
    let label: String
    let value: String
    let tint: Color
    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(tint.opacity(0.55))
                .cornerRadius(4)
        }
    }
}

private struct WhiteKey: View {
    let label: String
    let note: String
    let active: Bool

    var body: some View {
        VStack(spacing: 2) {
            Spacer()
            Text(note)
                .font(.system(size: 9, weight: .regular))
                .foregroundColor(active ? Color(red: 0.0, green: 0.2, blue: 0.45) : .gray.opacity(0.6))
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(active ? Color(red: 0.0, green: 0.2, blue: 0.45) : .gray.opacity(0.75))
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: active
                    ? [Color(red: 0.62, green: 0.82, blue: 1.0),
                       Color(red: 0.35, green: 0.65, blue: 0.93)]
                    : [Color.white,
                       Color(white: 0.88)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            Rectangle()
                .strokeBorder(Color.black.opacity(0.45), lineWidth: 0.5)
        )
    }
}

private struct BlackKey: View {
    let label: String
    let active: Bool

    var body: some View {
        VStack {
            Spacer()
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(active ? 1.0 : 0.85))
                .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: active
                    ? [Color(red: 0.28, green: 0.55, blue: 0.85),
                       Color(red: 0.10, green: 0.32, blue: 0.65)]
                    : [Color(white: 0.18),
                       Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 3)
                .offset(y: -3)
        )
    }
}
