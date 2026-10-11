import AppKit
import Combine

/// Panel ve görünümler arasında paylaşılan UI ölçüleri.
enum NotchLayout {
    static let rowHeight: CGFloat = 52
    static let headerHeight: CGFloat = 34
    static let verticalPadding: CGFloat = 16
    static let expandedWidth: CGFloat = 460
    static let peekSize = CGSize(width: 340, height: 60)
    static let idleChinHeight: CGFloat = 14
    static let fallbackChinSize = CGSize(width: 140, height: idleChinHeight)
}

/// Uygulamanın tüm UI durumunu yönetir: dosya listesi, panel durumu ve dosya aksiyonları.
@MainActor
final class NotchViewModel: ObservableObject {
    enum PanelState: Hashable {
        /// Çentiğin altında ince siyah "çene" — her zaman görünür, hover ile genişler.
        case idle
        /// Yeni dosya indiğinde birkaç saniyeliğine görünen bildirim bandı.
        case peek(DownloadedFile)
        /// Son 5 indirilenin listelendiği tam panel.
        case expanded
    }

    @Published private(set) var files: [DownloadedFile] = [] {
        didSet { onLayoutChange?() }
    }
    @Published private(set) var state: PanelState = .idle {
        didSet { onLayoutChange?() }
    }
    @Published var permissionDenied = false {
        didSet { onLayoutChange?() }
    }

    /// Yerleşimi etkileyen bir değer değiştikten SONRA çağrılır (@Published willSet
    /// zamanlamasına takılmamak için didSet üzerinden). Panel controller buradan haberdar olur.
    var onLayoutChange: (() -> Void)?

    /// Paylaş menüsünün konumlanacağı görünüm (panel içeriği).
    weak var shareAnchor: NSView?

    let downloadsURL: URL
    private let monitor: DownloadsMonitor
    private var hasLoadedOnce = false
    private var isHovering = false
    private var autoCollapseTask: Task<Void, Never>?
    private var expandTask: Task<Void, Never>?

    init(monitor: DownloadsMonitor = DownloadsMonitor()) {
        self.monitor = monitor
        self.downloadsURL = monitor.directoryURL

        monitor.onChange = { [weak self] files in
            Task { @MainActor [weak self] in
                self?.handleUpdate(files)
            }
        }
        monitor.onPermissionDenied = { [weak self] in
            Task { @MainActor [weak self] in
                self?.permissionDenied = true
            }
        }
    }

    func start() {
        monitor.start()
    }

    // MARK: - Liste güncellemesi

    private func handleUpdate(_ newFiles: [DownloadedFile]) {
        let isInitialLoad = !hasLoadedOnce
        hasLoadedOnce = true
        let previousTop = files.first
        permissionDenied = false

        files = newFiles
        dlog("ViewModel: liste güncellendi (\(newFiles.count) dosya, initial=\(isInitialLoad))")

        // İlk açılışta bildirim gösterme; sadece gerçekten yeni bir dosya geldiğinde göster.
        guard !isInitialLoad,
              let top = newFiles.first,
              top.id != previousTop?.id,
              // Üstteki dosya silinince alttaki eski dosya "yeni indirildi" diye gösterilmesin.
              previousTop == nil || top.addedDate > previousTop!.addedDate else { return }

        dlog("ViewModel: yeni dosya → \(top.name)")

        switch state {
        case .expanded:
            break // Kullanıcı zaten listeye bakıyor.
        case .idle, .peek:
            if isHovering {
                expand()
            } else {
                showPeek(for: top)
            }
        }
    }

    // MARK: - Panel durumu

    private func showPeek(for file: DownloadedFile) {
        autoCollapseTask?.cancel()
        state = .peek(file)
        scheduleCollapse(after: 4.5)
    }

    func expand() {
        expandTask?.cancel()
        autoCollapseTask?.cancel()
        state = .expanded
    }

    /// Menü çubuğundan tetiklenince: aç, fare gelmezse bir süre sonra kapat.
    func expandTemporarily() {
        expand()
        scheduleCollapse(after: 8)
    }

    /// Sürükleme sırasında panel küçülmesin (küçülürse sürükleme yarıda kesilir).
    /// Fare panelden çıkınca `setHovering(false)` normal kapanma sürecini başlatır.
    func dragStarted() {
        autoCollapseTask?.cancel()
        scheduleCollapse(after: 10)
    }

    func setHovering(_ hovering: Bool) {
        guard hovering != isHovering else { return }
        isHovering = hovering

        if hovering {
            autoCollapseTask?.cancel()
            if state == .idle {
                // Yanlışlıkla geçişlerde açılmaması için kısa bir gecikme.
                expandTask = Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 160_000_000)
                    guard !Task.isCancelled, let self, self.isHovering, self.state == .idle else { return }
                    self.expand()
                }
            }
        } else {
            expandTask?.cancel()
            switch state {
            case .expanded: scheduleCollapse(after: 0.5)
            case .peek: scheduleCollapse(after: 1.0)
            case .idle: break
            }
        }
    }

    private func scheduleCollapse(after delay: TimeInterval) {
        autoCollapseTask?.cancel()
        autoCollapseTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self, !self.isHovering else { return }
            self.state = .idle
        }
    }

    // MARK: - Dosya aksiyonları

    func open(_ file: DownloadedFile) {
        NSWorkspace.shared.open(file.url)
    }

    func reveal(_ file: DownloadedFile) {
        NSWorkspace.shared.activateFileViewerSelecting([file.url])
    }

    func trash(_ file: DownloadedFile) {
        NSWorkspace.shared.recycle([file.url]) { _, _ in }
    }

    func copy(_ file: DownloadedFile) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([file.url as NSURL])
    }

    func share(_ file: DownloadedFile) {
        guard let anchor = shareAnchor else { return }
        let picker = NSSharingServicePicker(items: [file.url])
        picker.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
    }

    func openDownloadsFolder() {
        NSWorkspace.shared.open(downloadsURL)
    }

    // MARK: - Erişim izni

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders") {
            NSWorkspace.shared.open(url)
        }
    }

    func retryAccess() {
        permissionDenied = false
        monitor.refresh()
    }
}
