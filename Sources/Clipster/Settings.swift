import AppKit
import Carbon.HIToolbox

/// Пользовательские настройки, хранятся в UserDefaults.
final class Settings: ObservableObject {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    @Published var maxItems: Int { didSet { defaults.set(maxItems, forKey: "maxItems") } }
    @Published var maxDays: Int { didSet { defaults.set(maxDays, forKey: "maxDays") } }
    @Published var maxMegabytes: Int { didSet { defaults.set(maxMegabytes, forKey: "maxMegabytes") } }
    /// Записывать то, что менеджеры паролей помечают как секретное.
    @Published var recordConcealed: Bool { didSet { defaults.set(recordConcealed, forKey: "recordConcealed") } }

    @Published var hotKeyCode: Int { didSet { defaults.set(hotKeyCode, forKey: "hotKeyCode") } }
    @Published var hotKeyModifiers: Int { didSet { defaults.set(hotKeyModifiers, forKey: "hotKeyModifiers") } }
    @Published var hotKeyDisplay: String { didSet { defaults.set(hotKeyDisplay, forKey: "hotKeyDisplay") } }

    /// Пока идёт запись нового сочетания, глобальный хоткей снят.
    @Published var isRecordingHotKey = false

    var maxBytes: Int { maxMegabytes * 1024 * 1024 }

    private init() {
        defaults.register(defaults: [
            "maxItems": 100,
            "maxDays": 3,
            "maxMegabytes": 20,
            "recordConcealed": false,
            "hotKeyCode": kVK_ANSI_E,
            "hotKeyModifiers": cmdKey,
            "hotKeyDisplay": "⌘E",
        ])
        maxItems = defaults.integer(forKey: "maxItems")
        maxDays = defaults.integer(forKey: "maxDays")
        maxMegabytes = defaults.integer(forKey: "maxMegabytes")
        recordConcealed = defaults.bool(forKey: "recordConcealed")
        hotKeyCode = defaults.integer(forKey: "hotKeyCode")
        hotKeyModifiers = defaults.integer(forKey: "hotKeyModifiers")
        hotKeyDisplay = defaults.string(forKey: "hotKeyDisplay") ?? "⌘E"
    }
}

enum KeyNames {
    static func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> Int {
        var m = 0
        if flags.contains(.command) { m |= cmdKey }
        if flags.contains(.option) { m |= optionKey }
        if flags.contains(.control) { m |= controlKey }
        if flags.contains(.shift) { m |= shiftKey }
        return m
    }

    static func symbols(_ flags: NSEvent.ModifierFlags) -> String {
        var s = ""
        if flags.contains(.control) { s += "⌃" }
        if flags.contains(.option) { s += "⌥" }
        if flags.contains(.shift) { s += "⇧" }
        if flags.contains(.command) { s += "⌘" }
        return s
    }

    /// Имя клавиши по коду, независимо от текущей раскладки (иначе ⌘E на русской покажется как ⌘У).
    static func keyName(code: UInt16, fallback: String?) -> String {
        let table: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
            11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2",
            20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
            29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L", 38: "J",
            39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
            50: "`", 49: "Space", 36: "↩", 48: "⇥", 51: "⌫",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        ]
        return table[code] ?? fallback?.uppercased() ?? "#\(code)"
    }
}
