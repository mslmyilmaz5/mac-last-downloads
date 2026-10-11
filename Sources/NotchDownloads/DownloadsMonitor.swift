import Foundation
import Darwin
import UniformTypeIdentifiers

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
    /// Sürükleme için öğe sağlayıcı. URL'yi dosya temsili yerine `public.file-url` verisi olarak
    /// verir; aksi halde SwiftUI dosyanın geçici bir kopyasını (~/Library/Caches/...SwiftUI.Drag-...)
    /// sürükler ve hedef uygulama asıl yolu değil o kopyanın yolunu alır.
    func dragItemProvider() -> NSItemProvider {
        let provider = NSItemProvider()
        let data = url.dataRepresentation
        provider.registerDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier, visibility: .all) { completion in
            completion(data, nil)
            return nil
        }
        provider.suggestedName = name
        return provider
    }

    var isScreenshot: Bool { ScreenshotSettings.isScreenshotName(name) }

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
    /// Ekran görüntüsü klasörü İndirilenler'den farklıysa onu da izleriz (yalnızca `queue` üzerinde dokunulur).
    private var screenshotURL: URL?
    private var screenshotSource: DispatchSourceFileSystemObject?
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
        queue.async { [weak self] in
            self?.screenshotSource?.cancel()
            self?.screenshotSource = nil
            self?.screenshotURL = nil
        }
    }

    func refresh() {
        // İzin başta reddedildiyse kaynak hiç kurulmamıştır; yeniden izlemeyi başlat.
        if source == nil {
            start()
        } else {
            scheduleRescan()
        }
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

    /// Ekran görüntüsü klasörünü (ayar değişmiş olabilir) izlemeye alır / bırakır.
    private func syncScreenshotSource() {
        let location = ScreenshotSettings.location.standardizedFileURL
        let wanted: URL? = location == directoryURL.standardizedFileURL ? nil : location
        guard wanted != screenshotURL else { return }

        screenshotSource?.cancel()
        screenshotSource = nil
        screenshotURL = nil
        guard let wanted else { return }

        let fd = open(wanted.path, O_EVTONLY)
        guard fd >= 0 else { return } // İzin yok: sessizce geç, sonraki taramada tekrar dene.
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .attrib, .extend],
            queue: queue
        )
        source.setEventHandler { [weak self] in self?.scheduleRescan() }
        source.setCancelHandler { close(fd) }
        screenshotSource = source
        screenshotURL = wanted
        source.resume()
    }

    private func rescan() {
        syncScreenshotSource()
        do {
            let files = try Self.scan(directoryURL, limit: limit, screenshotDirectory: screenshotURL)
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

    static func scan(
        _ directoryURL: URL,
        limit: Int,
        screenshotDirectory: URL? = nil
    ) throws -> [DownloadedFile] {
        let keys: [URLResourceKey] = [
            .fileSizeKey, .isDirectoryKey,
            .addedToDirectoryDateKey, .creationDateKey, .contentModificationDateKey
        ]
        let urls = try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )

        var filtered = urls.filter { url in
            if url.lastPathComponent.hasPrefix(".") { return false }
            if skippedExtensions.contains(url.pathExtension.lowercased()) { return false }
            return true
        }

        // Masaüstü vb. klasörden sadece ekran görüntüleri alınır.
        if let screenshotDirectory,
           let extra = try? FileManager.default.contentsOfDirectory(
               at: screenshotDirectory,
               includingPropertiesForKeys: keys,
               options: [.skipsHiddenFiles]
           ) {
            filtered += extra.filter { ScreenshotSettings.isScreenshotName($0.lastPathComponent) }
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
