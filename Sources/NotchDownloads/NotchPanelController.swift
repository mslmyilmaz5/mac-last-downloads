import AppKit
import SwiftUI
import QuartzCore

/// Çentiğin altına konumlanan, odak çalmayan (non-activating) yüzen paneli yönetir.
@MainActor
final class NotchPanelController: NSObject {
    private let viewModel: NotchViewModel
    private var panel: NSPanel?
    private var screenObserver: NSObjectProtocol?

    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        super.init()

        // Yerleşimi etkileyen her değişiklikte panel çerçevesini uyarla.
        viewModel.onLayoutChange = { [weak self] in
            self?.reposition(animated: true)
        }

        // Ekran takılıp çıkarılınca / çözünürlük değişince yeniden konumlan.
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.reposition(animated: false)
            }
        }
    }

    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }

    func show() {
        if panel == nil {
            panel = makePanel()
            viewModel.shareAnchor = panel?.contentView
        }
        reposition(animated: false)
        panel?.orderFrontRegardless()
    }

    // MARK: - Panel kurulumu

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        // Borderless pencerede gölge, içeriğin (yuvarlatılmış şeklin) silüetini takip eder.
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.isReleasedWhenClosed = false

        let hosting = NSHostingView(rootView: NotchRootView(viewModel: viewModel))
        hosting.autoresizingMask = [.width, .height]
        hosting.frame = NSRect(x: 0, y: 0, width: 1, height: 1)
        panel.contentView = hosting
        return panel
    }

    // MARK: - Konumlandırma

    private func reposition(animated: Bool) {
        guard let panel else { return }
        guard let notch = NotchGeometry.current() else {
            panel.orderOut(nil)
            return
        }

        let target = frame(for: viewModel.state, notch: notch)
        dlog("Panel: state=\(viewModel.state) target=\(target)")

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = viewModel.layoutDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(target, display: true)
            }
        } else {
            panel.setFrame(target, display: true)
        }
        panel.invalidateShadow()
    }

    private func frame(for state: NotchViewModel.PanelState, notch: NotchInfo) -> CGRect {
        let topY = notch.hangY

        switch state {
        case .idle:
            let chin = viewModel.chinHeight
            if notch.hasPhysicalNotch {
                // Çentiğin üzerine bin (siyah üstüne siyah = görünmez) ve altına
                // küçük bir dilim sarkıt → çentikle tek parça hissi.
                return CGRect(
                    x: notch.notchRect.minX,
                    y: notch.notchRect.minY - chin,
                    width: notch.notchRect.width,
                    height: notch.notchRect.height + chin
                )
            }
            let width = NotchLayout.fallbackChinSize.width
            return CGRect(
                x: notch.centerX - width / 2,
                y: topY - chin,
                width: width,
                height: chin
            )

        case .peek:
            return centeredFrame(size: NotchLayout.peekSize, topY: topY, notch: notch, clamp: true)

        case .expanded:
            let rows: CGFloat
            if viewModel.permissionDenied {
                rows = 2
            } else {
                rows = CGFloat(max(viewModel.files.count, 1))
            }
            let height = NotchLayout.headerHeight + NotchLayout.rowHeight * rows + NotchLayout.verticalPadding
            return centeredFrame(
                size: CGSize(width: NotchLayout.expandedWidth, height: height),
                topY: topY,
                notch: notch,
                clamp: true
            )
        }
    }

    private func centeredFrame(size: CGSize, topY: CGFloat, notch: NotchInfo, clamp: Bool) -> CGRect {
        var x = notch.centerX - size.width / 2
        if clamp {
            let visible = notch.screen.visibleFrame
            x = min(max(x, visible.minX + 12), visible.maxX - size.width - 12)
        }
        return CGRect(x: x, y: topY - size.height, width: size.width, height: size.height)
    }
}
