import AppKit
import CryptoKit

/// Следит за системным буфером: macOS не присылает уведомлений, поэтому опрашиваем changeCount.
final class ClipboardMonitor {
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?
    var onChange: ((NSPasteboard) -> Void)?

    init() {
        lastChangeCount = pasteboard.changeCount
    }

    func start() {
        let timer = Timer(timeInterval: 0.4, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Вызываем после собственной записи в буфер, чтобы не ловить её как новое копирование.
    func skipCurrent() {
        lastChangeCount = pasteboard.changeCount
    }

    private func tick() {
        let count = pasteboard.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count
        onChange?(pasteboard)
    }
}

enum PasteboardIO {
    /// Снимок буфера. Порядок: файлы → текст → картинка (Word/Excel кладут к тексту ещё и картинку-превью).
    static func capture(_ pb: NSPasteboard, maxBytes: Int, recordConcealed: Bool) -> ClipDraft? {
        let types = pb.types ?? []
        // Метки nspasteboard.org: так 1Password, Bitwarden и «Пароли» просят не сохранять содержимое.
        let secretTypes: Set<String> = ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType"]
        if !recordConcealed, types.contains(where: { secretTypes.contains($0.rawValue) }) { return nil }
        let source = NSWorkspace.shared.frontmostApplication?.localizedName

        if types.contains(.fileURL),
           let urls = pb.readObjects(forClasses: [NSURL.self],
                                     options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            let paths = urls.map(\.path)
            let joined = paths.joined(separator: "\n")
            return ClipDraft(kind: .files, text: joined, blobs: [], filePaths: paths,
                             hash: sha("files:" + joined), sourceApp: source)
        }

        if let string = pb.string(forType: .string), !string.isEmpty {
            var blobs: [(type: String, data: Data)] = []
            var size = string.utf8.count
            for type in [NSPasteboard.PasteboardType.rtf, .html] {
                if let data = pb.data(forType: type) {
                    blobs.append((type.rawValue, data))
                    size += data.count
                }
            }
            guard size <= maxBytes else { return nil }
            return ClipDraft(kind: .text, text: string, blobs: blobs, filePaths: [],
                             hash: sha("text:" + string), sourceApp: source)
        }

        if let raw = pb.data(forType: .png) ?? pb.data(forType: .tiff) {
            guard raw.count <= maxBytes, let rep = NSBitmapImageRep(data: raw) else { return nil }
            let png = types.contains(.png) ? raw : (rep.representation(using: .png, properties: [:]) ?? raw)
            guard png.count <= maxBytes else { return nil }
            let text = "Изображение \(rep.pixelsWide)×\(rep.pixelsHigh)"
            return ClipDraft(kind: .image, text: text,
                             blobs: [(NSPasteboard.PasteboardType.png.rawValue, png)],
                             filePaths: [], hash: sha(png), sourceApp: source)
        }

        return nil
    }

    static func write(_ item: ClipItem, store: HistoryStore, to pb: NSPasteboard = .general) {
        pb.clearContents()
        switch item.kind {
        case .files:
            pb.writeObjects(item.filePaths.map { URL(fileURLWithPath: $0) as NSURL })
        case .text:
            let pi = NSPasteboardItem()
            pi.setString(item.text, forType: .string)
            for rep in item.reps {
                if let data = store.blobData(item, type: rep.type) {
                    pi.setData(data, forType: .init(rep.type))
                }
            }
            pb.writeObjects([pi])
        case .image:
            guard let png = store.blobData(item, type: NSPasteboard.PasteboardType.png.rawValue) else { return }
            let pi = NSPasteboardItem()
            pi.setData(png, forType: .png)
            // Многие приложения читают только TIFF.
            if let tiff = NSImage(data: png)?.tiffRepresentation {
                pi.setData(tiff, forType: .tiff)
            }
            pb.writeObjects([pi])
        }
    }

    private static func sha(_ string: String) -> String { sha(Data(string.utf8)) }

    private static func sha(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
