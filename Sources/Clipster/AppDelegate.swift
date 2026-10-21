import AppKit
import Combine
import ServiceManagement
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = Settings.shared
    private var store: HistoryStore!
    private var monitor: ClipboardMonitor!
    private var panel: PanelController!
    private var hotKey: HotKey!
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var pruneTimer: Timer?
    private var subscriptions = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        store = HistoryStore(settings: settings)

        monitor = ClipboardMonitor()
        monitor.onChange = { [weak self] pb in
            guard let self else { return }
            if let draft = PasteboardIO.capture(pb, maxBytes: self.settings.maxBytes,
                                                recordConcealed: self.settings.recordConcealed) {
                self.store.add(draft)
            }
        }
        monitor.start()

        panel = PanelController(store: store) { [weak self] item, paste in
            self?.choose(item, paste: paste)
        }

        hotKey = HotKey { [weak self] in self?.panel.toggle() }
        applyHotKey()

        setUpStatusItem()

        // 3-дневный срок истекает и без новых копирований.
        let timer = Timer(timeInterval: 15 * 60, repeats: true) { [weak self] _ in self?.store.prune() }
        RunLoop.main.add(timer, forMode: .common)
        pruneTimer = timer

        settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.applyHotKey()
                self?.store.prune()
            }
            .store(in: &subscriptions)

        firstLaunchSetup()
    }

    private func applyHotKey() {
        if settings.isRecordingHotKey {
            hotKey.unregister()
        } else {
            hotKey.register(keyCode: settings.hotKeyCode, modifiers: settings.hotKeyModifiers)
        }
    }

    private func firstLaunchSetup() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "didFirstLaunch") else { return }
        defaults.set(true, forKey: "didFirstLaunch")
        do {
            try SMAppService.mainApp.register()
        } catch {
            NSLog("Clipster: автозапуск не включён: \(error)")
        }
        if !Paster.isTrusted { Paster.requestAccess() }
    }

    // MARK: - Выбор элемента

    private func choose(_ item: ClipItem, paste: Bool) {
        panel.hide()
        PasteboardIO.write(item, store: store)
        monitor.skipCurrent()
        store.touch(item)
        guard paste, Paster.isTrusted else { return }
        // Даём панели скрыться, чтобы ⌘V ушёл в приложение под ней.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            Paster.pressCommandV()
        }
    }

    // MARK: - Строка меню

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipster")

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    @objc private func openHistory() {
        panel.show()
    }

    @objc private func clearHistory() {
        store.clearUnpinned()
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(settings: settings)))
            window.title = "Настройки Clipster"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        settingsWindow?.center()
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

extension AppDelegate: NSMenuDelegate {
    /// Пересобираем меню при открытии, чтобы хоткей в подписи был актуальным.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(item("Открыть историю   \(settings.hotKeyDisplay)", #selector(openHistory)))
        menu.addItem(.separator())
        menu.addItem(item("Очистить историю (кроме закреплённых)", #selector(clearHistory)))
        menu.addItem(item("Настройки…", #selector(openSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(item("Выйти из Clipster", #selector(quit), key: "q"))
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }
}
