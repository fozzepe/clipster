import AppKit

/// История буфера: список в history.json, тяжёлые данные в blobs/.
final class HistoryStore: ObservableObject {
    @Published private(set) var items: [ClipItem] = []

    private let settings: Settings
    private let fileURL: URL
    let blobsURL: URL

    init(settings: Settings) {
        self.settings = settings
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Clipster", isDirectory: true)
        // Приложение раньше называлось Buffer: забираем его историю.
        let legacy = base.deletingLastPathComponent().appendingPathComponent("Buffer", isDirectory: true)
        if !FileManager.default.fileExists(atPath: base.path),
           FileManager.default.fileExists(atPath: legacy.appendingPathComponent("history.json").path) {
            try? FileManager.default.moveItem(at: legacy, to: base)
        }
        fileURL = base.appendingPathComponent("history.json")
        blobsURL = base.appendingPathComponent("blobs", isDirectory: true)
        try? FileManager.default.createDirectory(at: blobsURL, withIntermediateDirectories: true)
        load()
        prune()
    }

    // MARK: - Изменения

    func add(_ draft: ClipDraft) {
        if let i = items.firstIndex(where: { $0.hash == draft.hash }) {
            // Уже есть: поднимаем наверх, срок хранения начинается заново.
            var existing = items.remove(at: i)
            existing.date = Date()
            existing.sourceApp = draft.sourceApp ?? existing.sourceApp
            items.insert(existing, at: 0)
        } else {
            let id = UUID()
            var reps: [ClipItem.Rep] = []
            for (n, blob) in draft.blobs.enumerated() {
                let name = "\(id.uuidString)-\(n)"
                do {
                    try blob.data.write(to: blobsURL.appendingPathComponent(name))
                    reps.append(.init(type: blob.type, file: name))
                } catch {
                    NSLog("Clipster: не удалось записать \(name): \(error)")
                }
            }
            let item = ClipItem(id: id, kind: draft.kind, text: draft.text, reps: reps,
                                filePaths: draft.filePaths, hash: draft.hash,
                                sourceApp: draft.sourceApp, date: Date(), pinned: false)
            items.insert(item, at: 0)
        }
        prune()
        save()
    }

    func touch(_ item: ClipItem) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        var it = items.remove(at: i)
        it.date = Date()
        items.insert(it, at: 0)
        save()
    }

    func togglePin(_ item: ClipItem) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[i].pinned.toggle()
        // Открепили — элемент снова живёт по общим лимитам, считая от текущего момента.
        if !items[i].pinned { items[i].date = Date() }
        items.sort { $0.date > $1.date }
        prune()
        save()
    }

    func remove(_ item: ClipItem) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        deleteBlobs(of: items.remove(at: i))
        save()
    }

    func clearUnpinned() {
        items.filter { !$0.pinned }.forEach(deleteBlobs)
        items.removeAll { !$0.pinned }
        save()
    }

    /// Убирает незакреплённое старше N дней и сверх N штук.
    func prune() {
        let cutoff = Date().addingTimeInterval(-Double(settings.maxDays) * 86_400)
        var kept: [ClipItem] = []
        var count = 0
        var changed = false
        for item in items {
            if item.pinned || (item.date >= cutoff && count < settings.maxItems) {
                if !item.pinned { count += 1 }
                kept.append(item)
            } else {
                deleteBlobs(of: item)
                changed = true
            }
        }
        if changed {
            items = kept
            save()
        }
    }

    // MARK: - Данные

    func blobData(_ item: ClipItem, type: String) -> Data? {
        guard let rep = item.reps.first(where: { $0.type == type }) else { return nil }
        return try? Data(contentsOf: blobsURL.appendingPathComponent(rep.file))
    }

    private func deleteBlobs(of item: ClipItem) {
        for rep in item.reps {
            try? FileManager.default.removeItem(at: blobsURL.appendingPathComponent(rep.file))
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            items = try JSONDecoder().decode([ClipItem].self, from: data)
                .sorted { $0.date > $1.date }
        } catch {
            NSLog("Clipster: history.json не читается: \(error)")
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("Clipster: не удалось сохранить историю: \(error)")
        }
    }
}
