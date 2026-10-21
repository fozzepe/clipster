import AppKit
import SwiftUI

/// `Clipster --screenshots <папка>` рисует окна с демо-данными в PNG для README.
/// Настоящая история не трогается: демо-хранилище живёт во временной папке.
enum Screenshots {
    static func run(to output: URL) {
        // Настройки по умолчанию поверх пользовательских, чтобы на скринах были стандартные значения.
        UserDefaults.standard.setVolatileDomain([
            "maxItems": 100, "maxDays": 3, "maxMegabytes": 20, "recordConcealed": false,
            "hotKeyDisplay": "⌘E",
        ], forName: UserDefaults.argumentDomain)
        Paster.assumeTrusted = true

        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("clipster-demo-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let store = HistoryStore(settings: .shared, directory: tmp)
        DemoData.fill(store)
        try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        render(panel(store) { _ in }, appearance: .aqua, to: output.appendingPathComponent("history.png"))
        render(panel(store) { $0.query = "git" }, appearance: .darkAqua, to: output.appendingPathComponent("search.png"))
        render(panel(store) { $0.tab = .pinned }, appearance: .darkAqua, to: output.appendingPathComponent("pinned.png"))
        render(Backdrop { SettingsMock() }, appearance: .aqua, to: output.appendingPathComponent("settings.png"))
    }

    private static func panel(_ store: HistoryStore, configure: (PanelModel) -> Void) -> some View {
        let model = PanelModel(store: store)
        configure(model)
        model.selection = 0
        return Backdrop { HistoryView(model: model, store: store, opaqueBackground: true, autofocus: false) }
    }

    private static func render<V: View>(_ view: V, appearance: NSAppearance.Name, to url: URL) {
        let host = NSHostingView(rootView: view)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: appearance)
        window.contentView = host
        let size = host.fittingSize
        window.setContentSize(size)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))

        let scale: CGFloat = 2
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                         pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return }
        rep.size = size
        host.cacheDisplay(in: host.bounds, to: rep)
        do {
            try rep.representation(using: .png, properties: [:])?.write(to: url)
            print(url.path)
        } catch {
            print("Не удалось сохранить \(url.path): \(error)")
        }
    }
}

/// Градиентная подложка с тенью вокруг окна.
private struct Backdrop<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .shadow(color: .black.opacity(0.35), radius: 24, y: 10)
            .padding(56)
            .background(
                LinearGradient(colors: [Color(red: 0.33, green: 0.40, blue: 0.93),
                                        Color(red: 0.75, green: 0.35, blue: 0.85)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
    }
}

/// Окно настроек с нарисованным заголовком: у настоящего окна рамку рисует система.
private struct SettingsMock: View {
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("Настройки Clipster")
                    .font(.system(size: 13, weight: .semibold))
                HStack(spacing: 8) {
                    Circle().fill(Color(red: 1, green: 0.37, blue: 0.34))
                    Circle().fill(Color(red: 1, green: 0.74, blue: 0.18))
                    Circle().fill(Color(red: 0.16, green: 0.79, blue: 0.25))
                }
                .frame(height: 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 12)
            }
            .frame(height: 30)
            SettingsView(settings: .shared, launchAtLogin: true)
                .toggleStyle(DrawnSwitchStyle())
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// Системный NSSwitch вне экрана рисуется неактивным (серым), поэтому на скриншоте он нарисован.
private struct DrawnSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            Capsule()
                .fill(configuration.isOn ? Color.accentColor : Color.primary.opacity(0.1))
                .frame(width: 36, height: 20)
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle()
                        .fill(.white)
                        .shadow(color: .black.opacity(0.25), radius: 1, y: 0.5)
                        .padding(2)
                }
        }
    }
}

private enum DemoData {
    static func fill(_ store: HistoryStore) {
        let entries: [(draft: ClipDraft, minutesAgo: Double, pinned: Bool)] = [
            (text("git commit -m \"fix: поиск по нескольким словам\"", "Терминал"), 1, false),
            (image("Safari"), 6, false),
            (text("https://github.com/fozzepe/clipster", "Safari"), 12, false),
            (text("Добрый день! Высылаю счёт за октябрь, оплата до 31 числа.", "Почта"), 38, false),
            (files(["/Users/demo/Documents/Отчёт за квартал.pdf", "/Users/demo/Documents/Презентация.key"], "Finder"), 65, false),
            (text("#5E6AD2", "Figma"), 130, false),
            (text("SELECT name, email FROM users WHERE created_at > now() - interval '7 days';", "Visual Studio Code"), 190, false),
            (text("Встреча перенесена на четверг, 15:00", "Telegram"), 1_300, false),
            (text("npm run build && npm run deploy", "Терминал"), 2_000, false),
            (text("Москва, ул. Пушкина, д. 10, кв. 5", "Заметки"), 2_900, false),
            (text("С уважением,\nАлексей Смирнов\nhello@example.com", "Почта"), 20_000, true),
            (text("ИНН 7700000000, КПП 770001001, р/с 40702810000000000000", "Заметки"), 30_000, true),
            (text("ssh deploy@203.0.113.10", "Терминал"), 45_000, true),
        ]
        // add() кладёт элемент наверх, поэтому идём от старых к новым.
        for entry in entries.sorted(by: { $0.minutesAgo > $1.minutesAgo }) {
            store.add(entry.draft, date: Date().addingTimeInterval(-entry.minutesAgo * 60), pinned: entry.pinned)
        }
    }

    private static func text(_ string: String, _ app: String) -> ClipDraft {
        ClipDraft(kind: .text, text: string, blobs: [], filePaths: [], hash: UUID().uuidString, sourceApp: app)
    }

    private static func files(_ paths: [String], _ app: String) -> ClipDraft {
        ClipDraft(kind: .files, text: paths.joined(separator: "\n"), blobs: [], filePaths: paths,
                  hash: UUID().uuidString, sourceApp: app)
    }

    private static func image(_ app: String) -> ClipDraft {
        ClipDraft(kind: .image, text: "Изображение 1600×1000",
                  blobs: [(NSPasteboard.PasteboardType.png.rawValue, sunset())],
                  filePaths: [], hash: UUID().uuidString, sourceApp: app)
    }

    /// Нарисованный закат вместо чужой фотографии.
    private static func sunset() -> Data {
        let image = NSImage(size: NSSize(width: 1600, height: 1000), flipped: false) { rect in
            NSGradient(colors: [NSColor(calibratedRed: 1, green: 0.62, blue: 0.35, alpha: 1),
                                NSColor(calibratedRed: 0.45, green: 0.22, blue: 0.6, alpha: 1)])?
                .draw(in: rect, angle: 90)
            NSColor(calibratedRed: 1, green: 0.9, blue: 0.6, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: 650, y: 330, width: 300, height: 300)).fill()
            let hills = NSBezierPath()
            hills.move(to: NSPoint(x: 0, y: 0))
            for point in [(0, 300), (350, 560), (700, 330), (1050, 640), (1600, 280), (1600, 0)] {
                hills.line(to: NSPoint(x: point.0, y: point.1))
            }
            hills.close()
            NSColor(calibratedRed: 0.2, green: 0.13, blue: 0.3, alpha: 1).setFill()
            hills.fill()
            return true
        }
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return Data() }
        return png
    }
}
