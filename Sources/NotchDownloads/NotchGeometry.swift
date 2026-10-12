import AppKit

/// Çentiğin (veya çentiksiz ekranda sanal karşılığının) ekran koordinatlarındaki konumu.
struct NotchInfo {
    /// Çentik alanı. `minY` menü çubuğunun / çentiğin alt kenarıdır; panel buradan aşağı sarkar.
    let notchRect: CGRect
    let hasPhysicalNotch: Bool
    let screen: NSScreen

    var hangY: CGFloat { notchRect.minY }
    var centerX: CGFloat { notchRect.midX }
    var notchWidth: CGFloat { notchRect.width }
}

enum NotchGeometry {
    /// Panelin tutunacağı ekranı ve çentik konumunu hesaplar.
    static func current() -> NotchInfo? {
        guard let screen = preferredScreen() else {
            dlog("NotchGeometry: no screen")
            return nil
        }

        dlog("NotchGeometry: screen.frame=\(screen.frame) safeAreaInsets=\(screen.safeAreaInsets) left=\(String(describing: screen.auxiliaryTopLeftArea)) right=\(String(describing: screen.auxiliaryTopRightArea))")

        // Fiziksel çentik: safeAreaInsets.top > 0 ve yardımcı menü çubuğu alanları arasında boşluk var.
        if let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea,
           screen.safeAreaInsets.top > 0 {
            let gap = right.minX - left.maxX
            if gap > 50 {
                let height = screen.safeAreaInsets.top
                let rect = CGRect(
                    x: left.maxX,
                    y: screen.frame.maxY - height,
                    width: gap,
                    height: height
                )
                dlog("NotchGeometry: physical notch rect=\(rect)")
                return NotchInfo(notchRect: rect, hasPhysicalNotch: true, screen: screen)
            }
        }

        // Çentiksiz ekran: menü çubuğunun altında ortalanmış sanal bir alan.
        let menuBarHeight = NSStatusBar.system.thickness
        let width: CGFloat = 160
        let rect = CGRect(
            x: screen.frame.midX - width / 2,
            y: screen.frame.maxY - menuBarHeight,
            width: width,
            height: menuBarHeight
        )
        return NotchInfo(notchRect: rect, hasPhysicalNotch: false, screen: screen)
    }

    /// Çentikli ekranı tercih eder; yoksa ana ekranı kullanır.
    private static func preferredScreen() -> NSScreen? {
        let screens = NSScreen.screens
        func hasNotch(_ screen: NSScreen) -> Bool {
            screen.safeAreaInsets.top > 0 && screen.auxiliaryTopLeftArea != nil
        }
        if let main = NSScreen.main, hasNotch(main) { return main }
        if let notched = screens.first(where: hasNotch) { return notched }
        return NSScreen.main ?? screens.first
    }
}
