import AppKit
import ApplicationServices

/// Автовставка: имитирует ⌘V в активном приложении. Нужен «Универсальный доступ».
enum Paster {
    /// Для скриншотов: показывать интерфейс так, будто доступ уже выдан.
    static var assumeTrusted = false
    static var isTrusted: Bool { assumeTrusted || AXIsProcessTrusted() }

    /// Показывает системный запрос и добавляет Clipster в список «Универсального доступа».
    static func requestAccess() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    static func pressCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9 // V в ANSI; приложения сопоставляют ⌘-сочетания по коду клавиши
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
