import Foundation
import Darwin

/// İndirilenler klasöründeki tek bir dosyayı temsil eder.
struct DownloadedFile: Identifiable, Hashable {
    let url: URL
    let name: String
    let size: Int64
    let isDirectory: Bool
    let addedDate: Date

    var id: URL { url }

    init(url: URL) {
        let values = try? url.resourceValues(forKeys: [
            .fileSizeKey, .isDirectoryKey,
            .addedToDirectoryDateKey, .creationDateKey, .contentModificationDateKey
        ])
        self.url = url
        self.name = url.lastPathComponent
        self.isDirectory = values?.isDirectory ?? false
        self.size = Int64(values?.fileSize ?? 0)
        self.addedDate = values?.addedToDirectoryDate
            ?? values?.creationDate
            ?? values?.contentModificationDate
            ?? .distantPast
    }

    var formattedSize: String {
        if isDirectory { return "Klasör" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: addedDate, relativeTo: Date())
    }

    /// Son 2 dakika içinde eklenmişse "yeni" sayılır.
    var isRecent: Bool {
        Date().timeIntervalSince(addedDate) < 120
    }
}

/// ~/Downloads klasörünü DispatchSource (vnode) ile izler.
/// Tarayıcıların yarım kalan indirme dosyalarını (.download, .crdownload...) filtreler.
final class DownloadsMonitor {
    /// Yarım / devam eden indirmeleri göstermemek için atlanan uzantılar.
    private static let skippedExtensions: Set<String> = [
        "download", "crdownload", "part", "partial", "partialdownload", "tmp", "filepart"
    ]

    let directoryURL: URL
    private let limit: Int
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private let queue = DispatchQueue(label: "notchdownloads.monitor", qos: .utility)
    private var debounceWorkItem: DispatchWorkItem?

    /// Ana kuyrukta çağrılır. Liste her değiştiğinde güncel sıralı listeyi verir.
    var onChange: (([DownloadedFile]) -> Void)?
    /// İndirilenler klasörüne erişim reddedildiğinde bir kez çağrılır.
    var onPermissionDenied: (() -> Void)?

    init(directoryURL: URL? = nil, limit: Int = 5) {
        self.directoryURL = directoryURL
            ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        self.limit = limit
    }

    func start() {
        guard source == nil else { return }
        fileDescriptor = open(directoryURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            DispatchQueue.main.async { [weak self] in self?.onPermissionDenied?() }
            return
        }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete, .attrib, .extend],
            queue: queue
        )
        source.setEventHandler { [weak self] in
            self?.scheduleRescan()
        }
        let fd = fileDescriptor
        source.setCancelHandler {
            close(fd)
        }
        self.source = source
        source.resume()
        scheduleRescan()
    }

    func stop() {
        debounceWorkItem?.cancel()
        source?.cancel()
        source = nil
        fileDescriptor = -1
    }

    func refresh() {
        scheduleRescan()
    }

    /// Ardışık olayları (tek indirmede düzinelerce vnode eventi gelir) tek taramaya indirger.
    private func scheduleRescan() {
        debounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.rescan()
        }
        debounceWorkItem = work
        queue.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    private func rescan() {
        do {
            let files = try Self.scan(directoryURL, limit: limit)
            dlog("Monitor: \(files.count) dosya bulundu: \(files.map(\.name))")
            DispatchQueue.main.async { [weak self] in
                self?.onChange?(files)
            }
        } catch let error as NSError {
            dlog("Monitor: tarama hatası \(error.domain) \(error.code)")
            if error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoPermissionError {
                DispatchQueue.main.async { [weak self] in
                    self?.onPermissionDenied?()
                }
            }
        }
    }

    static func scan(_ directoryURL: URL, limit: Int) throws -> [DownloadedFile] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [
                .fileSizeKey, .isDirectoryKey,
                .addedToDirectoryDateKey, .creationDateKey, .contentModificationDateKey
            ],
            options: [.skipsHiddenFiles]
        )

        let filtered = urls.filter { url in
            if url.lastPathComponent.hasPrefix(".") { return false }
            if skippedExtensions.contains(url.pathExtension.lowercased()) { return false }
            return true
        }

        return filtered
            .map(DownloadedFile.init)
            .sorted { lhs, rhs in
                if lhs.addedDate != rhs.addedDate { return lhs.addedDate > rhs.addedDate }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            .prefix(limit)
            .map { $0 }
    }
}
