import Cocoa
import InputMethodKit

// MARK: - Conversion engine (same rules as before)

enum Mapper {
    static let two: [String: String] = [
        "ph": "ф", "ts": "ц", "sh": "ш", "kh": "х", "ch": "ч",
        "ya": "я", "yo": "ё", "ye": "е", "yu": "ю", "yi": "й",
        "ou": "ө"
    ]

    static let one: [Character: String] = [
        "a": "а", "b": "б", "d": "д", "e": "э", "g": "г", "h": "х",
        "i": "и", "j": "ж", "k": "к", "l": "л", "m": "м", "n": "н",
        "o": "о", "p": "п", "r": "р", "s": "с", "t": "т", "u": "ү",
        "v": "в", "w": "в", "y": "у", "z": "з"
    ]

    // Cyrillic vowels: a lone "i" typed right after one of these becomes й
    static let vowels: Set<String> = ["а", "о", "у", "ү", "ө", "э", "е", "ы", "ю", "я", "ё"]

    static let masculine: Set<String> = ["а", "о", "у", "я", "ё"]
    static let feminine: Set<String> = ["э", "ө", "ү", "е"]

    private struct Piece {
        var text: String
        var isSign = false
        var isII = false        // "ii" -> ий, or ы if the word has а у о я ё
        var upper = false
        var upper2 = false      // case of the 2nd letter of "ii"
    }

    /// Converts one Latin word. Re-run on every keystroke, so the result
    /// (including the ь/ъ decision) updates live as the word grows.
    static func convertWord(_ word: String) -> String {
        let chars = Array(word)
        let lower = chars.map { Character($0.lowercased()) }
        var pieces: [Piece] = []
        var i = 0

        while i < chars.count {
            let up = chars[i].isUppercase
            if i + 1 < chars.count {
                let pair = String(lower[i...i + 1])
                if pair == "ii" {
                    pieces.append(Piece(text: "", isII: true, upper: up, upper2: chars[i + 1].isUppercase))
                    i += 2; continue
                }
                if pair == "iy" {
                    pieces.append(Piece(text: "", isSign: true, upper: up))
                    i += 2; continue
                }
                if let m = two[pair] {
                    pieces.append(Piece(text: m, upper: up))
                    i += 2; continue
                }
            }
            if lower[i] == "i", let prev = pieces.last, !prev.isSign,
               vowels.contains(prev.text.lowercased()) {
                pieces.append(Piece(text: "й", upper: up))   // vowel + i -> й
            } else if let m = one[lower[i]] {
                pieces.append(Piece(text: m, upper: up))
            } else {
                pieces.append(Piece(text: String(chars[i])))
            }
            i += 1
        }

        // Vowel harmony: the word's gender is set by its first non-neutral vowel
        // (the root). и, й (and ю) are neutral and are skipped.
        //   masculine: а о у я ё      feminine: э ө ү е
        let letters = pieces.filter { !$0.isSign && !$0.isII }.map { $0.text.lowercased() }
        let firstHarmonic = letters.first { masculine.contains($0) || feminine.contains($0) }
        let isMasculine = firstHarmonic.map { masculine.contains($0) } ?? false

        // iy -> ъ in masculine words, ь otherwise (feminine / neutral / no vowel)
        let sign = isMasculine ? "ъ" : "ь"
        // ii -> ы in masculine words, ий otherwise
        let hardCue = isMasculine

        return pieces.map { (p: Piece) -> String in
            if p.isII {
                if hardCue { return p.upper ? "Ы" : "ы" }
                return (p.upper ? "И" : "и") + (p.upper2 ? "Й" : "й")
            }
            let t = p.isSign ? sign : p.text
            return p.upper ? t.uppercased() : t
        }.joined()
    }
}

// MARK: - Input controller

@objc(MongolianController)
class MongolianController: IMKInputController {
    private var buffer = ""
    private let any = NSRange(location: NSNotFound, length: NSNotFound)

    override func recognizedEvents(_ sender: Any!) -> Int {
        Int(NSEvent.EventTypeMask.keyDown.rawValue)
    }

    private func showComposition(_ client: IMKTextInput) {
        let text = Mapper.convertWord(buffer)
        client.setMarkedText(text,
                             selectionRange: NSRange(location: text.utf16.count, length: 0),
                             replacementRange: any)
    }

    private func commit(_ client: IMKTextInput, extra: String = "") {
        let text = Mapper.convertWord(buffer) + extra
        buffer = ""
        if !text.isEmpty {
            client.insertText(text, replacementRange: any)
        }
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event = event, event.type == .keyDown,
              let client = sender as? IMKTextInput else { return false }

        // Shortcuts (⌘, ⌃, ⌥): finish the word and let the shortcut through
        if !event.modifierFlags.intersection([.command, .control, .option]).isEmpty {
            commit(client)
            return false
        }

        switch event.keyCode {
        case 51: // delete / backspace
            guard !buffer.isEmpty else { return false }
            buffer.removeLast()
            if buffer.isEmpty {
                client.setMarkedText("", selectionRange: NSRange(location: 0, length: 0), replacementRange: any)
            } else {
                showComposition(client)
            }
            return true
        case 53: // escape: cancel current word
            guard !buffer.isEmpty else { return false }
            buffer = ""
            client.setMarkedText("", selectionRange: NSRange(location: 0, length: 0), replacementRange: any)
            return true
        case 36, 76, 48, 123, 124, 125, 126: // return, enter, tab, arrows
            commit(client)
            return false
        default:
            break
        }

        guard let chars = event.characters, !chars.isEmpty else { return false }

        // Latin letter: add to the word and show live Cyrillic
        if chars.count == 1, let c = chars.first, c.isASCII, c.isLetter {
            buffer.append(c)
            showComposition(client)
            return true
        }

        // Space, punctuation, digits: commit the word, then the character
        if !buffer.isEmpty {
            commit(client, extra: chars)
            return true
        }
        return false
    }

    override func commitComposition(_ sender: Any!) {
        if let client = sender as? IMKTextInput { commit(client) }
    }

    override func deactivateServer(_ sender: Any!) {
        if let client = sender as? IMKTextInput { commit(client) }
        super.deactivateServer(sender)
    }
}

// MARK: - Start the input method server

let connectionName = "MongolianLatin_Connection"
let server = IMKServer(name: connectionName, bundleIdentifier: Bundle.main.bundleIdentifier)
_ = server
NSApplication.shared.run()
