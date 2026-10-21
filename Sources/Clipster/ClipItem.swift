import Foundation

struct ClipItem: Codable, Identifiable, Equatable {
    enum Kind: String, Codable { case text, image, files }

    /// Дополнительное представление (RTF, HTML, PNG), лежит отдельным файлом в blobs/.
    struct Rep: Codable, Equatable {
        var type: String
        var file: String
    }

    let id: UUID
    var kind: Kind
    /// Текст для поиска и показа: сам текст, пути файлов или «Изображение W×H».
    var text: String
    var reps: [Rep]
    var filePaths: [String]
    var hash: String
    var sourceApp: String?
    var date: Date
    var pinned: Bool

    var title: String {
        switch kind {
        case .files:
            return filePaths.map { ($0 as NSString).lastPathComponent }.joined(separator: ", ")
        case .image:
            return text
        case .text:
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let oneLine = trimmed.prefix(300)
                .replacingOccurrences(of: "\r\n", with: " ⏎ ")
                .replacingOccurrences(of: "\n", with: " ⏎ ")
                .replacingOccurrences(of: "\t", with: " ")
            return oneLine.isEmpty ? "(пробелы)" : oneLine
        }
    }
}

/// Результат захвата буфера до записи на диск: данные ещё в памяти.
struct ClipDraft {
    var kind: ClipItem.Kind
    var text: String
    var blobs: [(type: String, data: Data)]
    var filePaths: [String]
    var hash: String
    var sourceApp: String?
}
