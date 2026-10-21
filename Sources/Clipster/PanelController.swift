import AppKit
import SwiftUI

/// Панель, которая принимает клавиатуру, не активируя Clipster: активным остаётся приложение,
/// куда потом вставляем.
final class KeyPanel: NSPanel {
    var keyHandler: ((NSEvent) -> Bool)?
    var onResignKey: (() -> Void)?

    override var canBecomeKey: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, keyHandler?(event) == true { return }
        super.sendEvent(event)
    }

    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }
}

final class PanelModel: ObservableObject {
    enum Tab { case history, pinned }

    @Published var query = "" { didSet { if query != oldValue { selection = 0 } } }
    @Published var tab: Tab = .history { didSet { if tab != oldValue { selection = 0 } } }
    @Published var selection = 0
    /// Меняется при каждом показе, чтобы вернуть фокус в поле поиска.
    @Published var focusToken = 0

    let store: HistoryStore
    var onChoose: ((ClipItem, Bool) -> Void)?

    init(store: HistoryStore) {
        self.store = store
    }

    /// Поиск по словам: регистр не важен, все слова должны встречаться в любом порядке.
    func visibleItems() -> [ClipItem] {
        let base = store.items.filter { tab == .pinned ? $0.pinned : !$0.pinned }
        let words = query.lowercased().split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return base }
        return base.filter { item in
            let haystack = item.text.lowercased()
            return words.allSatisfy { haystack.contains($0) }
        }
    }

    var selectedItem: ClipItem? {
        let items = visibleItems()
        return items.indices.contains(selection) ? items[selection] : nil
    }

    func move(_ delta: Int) {
        let count = visibleItems().count
        guard count > 0 else { return }
        selection = min(max(selection + delta, 0), count - 1)
    }

    func clamp() {
        let count = visibleItems().count
        selection = count == 0 ? 0 : min(selection, count - 1)
    }
}

final class PanelController {
    static let size = NSSize(width: 640, height: 460)

    private let panel: KeyPanel
    let model: PanelModel
    private let store: HistoryStore

    var isVisible: Bool { panel.isVisible }

    init(store: HistoryStore, onChoose: @escaping (ClipItem, Bool) -> Void) {
        self.store = store
        model = PanelModel(store: store)
        model.onChoose = onChoose

        panel = KeyPanel(contentRect: NSRect(origin: .zero, size: Self.size),
                         styleMask: [.nonactivatingPanel, .borderless],
                         backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: HistoryView(model: model, store: store))

        panel.keyHandler = { [weak self] event in self?.handle(event) ?? false }
        panel.onResignKey = { [weak self] in self?.hide() }
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        model.query = ""
        model.tab = .history
        model.selection = 0
        model.focusToken += 1

        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            // Чуть выше центра, как Spotlight.
            let origin = NSPoint(x: frame.midX - Self.size.width / 2,
                                 y: frame.midY - Self.size.height / 2 + frame.height * 0.08)
            panel.setFrame(NSRect(origin: origin, size: Self.size), display: false)
        }
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
    }

    // MARK: - Клавиатура

    private static let digitKeyCodes: [UInt16: Int] = [18: 0, 19: 1, 20: 2, 21: 3, 23: 4, 22: 5, 26: 6, 28: 7, 25: 8]

    private func handle(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let pasteNow = !flags.contains(.option)

        switch event.keyCode {
        case 53: // Esc
            hide()
            return true
        case 125: // ↓
            model.move(1)
            return true
        case 126: // ↑
            model.move(-1)
            return true
        case 36, 76: // Return, Enter
            if let item = model.selectedItem { model.onChoose?(item, pasteNow) }
            return true
        case 48: // Tab
            model.tab = model.tab == .history ? .pinned : .history
            return true
        default:
            break
        }

        guard flags.contains(.command) else { return false }

        if let n = Self.digitKeyCodes[event.keyCode] {
            let items = model.visibleItems()
            if items.indices.contains(n) { model.onChoose?(items[n], pasteNow) }
            return true
        }

        switch event.keyCode {
        case 51: // ⌘⌫
            if let item = model.selectedItem {
                store.remove(item)
                model.clamp()
            }
            return true
        case 35: // ⌘P
            if let item = model.selectedItem {
                store.togglePin(item)
                model.clamp()
            }
            return true
        // У приложения без активного меню стандартные сочетания поля ввода надо отправлять вручную.
        case 0: return send(#selector(NSText.selectAll(_:)))
        case 8: return send(#selector(NSText.copy(_:)))
        case 9: return send(#selector(NSText.paste(_:)))
        case 7: return send(#selector(NSText.cut(_:)))
        case 6: return send(Selector(("undo:")))
        default:
            return false
        }
    }

    private func send(_ action: Selector) -> Bool {
        NSApp.sendAction(action, to: nil, from: nil)
        return true
    }
}
