import AppKit
import ImageIO
import SwiftUI

struct HistoryView: View {
    @ObservedObject var model: PanelModel
    @ObservedObject var store: HistoryStore
    @FocusState private var searchFocused: Bool

    var body: some View {
        let items = model.visibleItems()

        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                TextField("Поиск в истории", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18))
                    .focused($searchFocused)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            HStack(spacing: 6) {
                tabButton("История", tab: .history, count: store.items.filter { !$0.pinned }.count)
                tabButton("Закреплённые", tab: .pinned, count: store.items.filter(\.pinned).count)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider()

            if items.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                ClipRow(item: item, index: index,
                                        isSelected: index == model.selection, store: store)
                                    .id(item.id)
                                    .onTapGesture {
                                        model.selection = index
                                        model.onChoose?(item, true)
                                    }
                                    .contextMenu {
                                        Button("Вставить") { model.onChoose?(item, true) }
                                        Button("Только скопировать") { model.onChoose?(item, false) }
                                        Button(item.pinned ? "Открепить" : "Закрепить") { store.togglePin(item) }
                                        Divider()
                                        Button("Удалить") { store.remove(item) }
                                    }
                            }
                        }
                        .padding(6)
                    }
                    .onChange(of: model.selection) { _, newValue in
                        let current = model.visibleItems()
                        if current.indices.contains(newValue) {
                            proxy.scrollTo(current[newValue].id)
                        }
                    }
                }
            }

            Divider()
            footer
        }
        .frame(width: PanelController.size.width, height: PanelController.size.height)
        .background(VisualEffectBackground())
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onAppear { searchFocused = true }
        .onChange(of: model.focusToken) { searchFocused = true }
        .onChange(of: items.count) { model.clamp() }
    }

    private func tabButton(_ title: String, tab: PanelModel.Tab, count: Int) -> some View {
        Button {
            model.tab = tab
        } label: {
            Text("\(title)  \(count)")
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(model.tab == tab ? Color.accentColor.opacity(0.25) : Color.clear)
                )
                .foregroundStyle(model.tab == tab ? .primary : .secondary)
        }
        .buttonStyle(.plain)
        .focusable(false)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: model.tab == .pinned ? "pin" : "doc.on.clipboard")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text(emptyText)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyText: String {
        if !model.query.isEmpty { return "Ничего не найдено" }
        return model.tab == .pinned ? "Закреплённых нет. ⌘P на элементе — закрепить" : "История пуста. Скопируй что-нибудь"
    }

    private var footer: some View {
        HStack(spacing: 14) {
            if Paster.isTrusted {
                hint("↩", "вставить")
                hint("⌥↩", "скопировать")
            } else {
                Button("Автовставка выключена — разрешить доступ") { Paster.openAccessibilitySettings() }
                    .buttonStyle(.link)
                    .focusable(false)
                hint("↩", "скопировать")
            }
            hint("⌘P", "закрепить")
            hint("⌘⌫", "удалить")
            hint("⇥", "вкладки")
            Spacer()
        }
        .font(.system(size: 11))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func hint(_ key: String, _ text: String) -> some View {
        HStack(spacing: 4) {
            Text(key).fontWeight(.semibold)
            Text(text)
        }
        .foregroundStyle(.secondary)
    }
}

struct ClipRow: View {
    let item: ClipItem
    let index: Int
    let isSelected: Bool
    let store: HistoryStore

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.unitsStyle = .short
        return f
    }()

    var body: some View {
        HStack(spacing: 10) {
            icon
                .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if index < 9 {
                Text("⌘\(index + 1)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.28) : Color.clear)
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var icon: some View {
        switch item.kind {
        case .image:
            if let thumb = Thumbnails.image(for: item, store: store) {
                Image(nsImage: thumb)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 30, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: "photo").foregroundStyle(.secondary)
            }
        case .files:
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.filePaths.first ?? "/"))
                .resizable()
                .scaledToFit()
        case .text:
            Image(systemName: "text.alignleft")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if let app = item.sourceApp { parts.append(app) }
        parts.append(Self.relative.localizedString(for: item.date, relativeTo: Date()))
        switch item.kind {
        case .files where item.filePaths.count > 1:
            parts.append("файлов: \(item.filePaths.count)")
        case .text where item.text.count > 300:
            parts.append("\(item.text.count) симв.")
        default:
            break
        }
        return parts.joined(separator: " · ")
    }
}

/// Маленькие превью картинок: декодировать каждый раз полноразмерный PNG дорого.
enum Thumbnails {
    private static let cache = NSCache<NSUUID, NSImage>()

    static func image(for item: ClipItem, store: HistoryStore) -> NSImage? {
        if let cached = cache.object(forKey: item.id as NSUUID) { return cached }
        guard let rep = item.reps.first else { return nil }
        let url = store.blobsURL.appendingPathComponent(rep.file)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 96,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let image = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        cache.setObject(image, forKey: item.id as NSUUID)
        return image
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
