import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: Settings
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var trusted = Paster.isTrusted

    var body: some View {
        Form {
            Section {
                LabeledContent("Горячая клавиша") {
                    HotKeyRecorder(settings: settings)
                }
            }
            Section("История") {
                Stepper("Хранить элементов: \(settings.maxItems)", value: $settings.maxItems, in: 10...1000, step: 10)
                Stepper("Хранить дней: \(settings.maxDays)", value: $settings.maxDays, in: 1...365)
                Stepper("Не сохранять больше \(settings.maxMegabytes) МБ", value: $settings.maxMegabytes, in: 1...200)
                Text("Закреплённые элементы не удаляются никогда.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Записывать пароли из менеджеров паролей", isOn: $settings.recordConcealed)
                Text("История хранится на диске без шифрования.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Система") {
                Toggle("Запускать при входе в систему", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            NSLog("Clipster: автозапуск: \(error)")
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                LabeledContent("Автовставка") {
                    if trusted {
                        Label("Разрешена", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("Разрешить в «Универсальном доступе»…") {
                            Paster.requestAccess()
                            Paster.openAccessibilitySettings()
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize()
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            trusted = Paster.isTrusted
        }
    }
}

struct HotKeyRecorder: View {
    @ObservedObject var settings: Settings
    @State private var monitor: Any?

    var body: some View {
        Button(settings.isRecordingHotKey ? "Нажми сочетание… (Esc — отмена)" : settings.hotKeyDisplay) {
            settings.isRecordingHotKey ? stop() : start()
        }
        .onDisappear { stop() }
    }

    private func start() {
        settings.isRecordingHotKey = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                stop()
                return nil
            }
            let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
            // Без модификатора сочетание перехватит обычный набор текста.
            guard !mods.isEmpty else { return nil }
            settings.hotKeyCode = Int(event.keyCode)
            settings.hotKeyModifiers = KeyNames.carbonModifiers(mods)
            settings.hotKeyDisplay = KeyNames.symbols(mods)
                + KeyNames.keyName(code: event.keyCode, fallback: event.charactersIgnoringModifiers)
            stop()
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if settings.isRecordingHotKey { settings.isRecordingHotKey = false }
    }
}
