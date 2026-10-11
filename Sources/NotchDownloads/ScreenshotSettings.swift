import Foundation

/// macOS ekran görüntüsü ayarları (`com.apple.screencapture`).
enum ScreenshotSettings {
    private static let domain = "com.apple.screencapture" as CFString
    private static let thumbnailKey = "show-thumbnail" as CFString

    /// Ekran görüntülerinin kaydedildiği klasör (varsayılan: Masaüstü).
    static var location: URL {
        if let path = CFPreferencesCopyAppValue("location" as CFString, domain) as? String, !path.isEmpty {
            return URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
        }
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
    }

    /// Yüzen küçük resim kapalıysa dosya çekildiği anda kaydedilir.
    static var isInstantSaveEnabled: Bool {
        (CFPreferencesCopyAppValue(thumbnailKey, domain) as? Bool) == false
    }

    /// Açıkken küçük resmi kapatır; kapatırken anahtarı silip sistem varsayılanına döner.
    static func setInstantSave(_ enabled: Bool) {
        CFPreferencesSetAppValue(thumbnailKey, enabled ? kCFBooleanFalse : nil, domain)
        CFPreferencesAppSynchronize(domain)
    }

    private static let namePrefixes = [
        "Screenshot", "Screen Shot", "Screen Recording",
        "Ekran Resmi", "Ekran Görüntüsü", "Ekran Kaydı"
    ]
    private static let extensions: Set<String> = [
        "png", "jpg", "jpeg", "heic", "tiff", "gif", "pdf", "mov", "mp4"
    ]

    /// Masaüstü gibi karışık klasörlerde yalnızca ekran görüntülerini ayıklamak için.
    static func isScreenshotName(_ fileName: String) -> Bool {
        var prefixes = namePrefixes
        if let custom = CFPreferencesCopyAppValue("name" as CFString, domain) as? String, !custom.isEmpty {
            prefixes.append(custom)
        }
        let ext = (fileName as NSString).pathExtension.lowercased()
        return extensions.contains(ext) && prefixes.contains { fileName.hasPrefix($0) }
    }
}
