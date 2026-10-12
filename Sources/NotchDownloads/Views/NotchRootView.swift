import SwiftUI

/// Panelin kök görünümü: çentiğin devamı gibi duran siyah zemin + duruma göre içerik.
struct NotchRootView: View {
    @ObservedObject var viewModel: NotchViewModel

    var body: some View {
        ZStack(alignment: .top) {
            panelBackground

            Group {
                switch viewModel.state {
                case .idle:
                    idleContent
                case .peek(let file):
                    PeekView(file: file)
                        .contentShape(Rectangle())
                        .onTapGesture { viewModel.expand() }
                        .onDrag {
                            viewModel.dragStarted()
                            return file.dragItemProvider()
                        }
                case .expanded:
                    ExpandedListView(viewModel: viewModel)
                }
            }
            .id(viewModel.state)
            .transition(.opacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(panelShape)
        .onHover { hovering in
            viewModel.setHovering(hovering)
            syncIdleCursor()
        }
        .onChange(of: viewModel.state) { _ in
            syncIdleCursor()
        }
        .onDisappear {
            NSCursor.arrow.set()
        }
        .animation(.easeOut(duration: 0.2), value: viewModel.isHovering)
        .animation(.easeOut(duration: 0.18), value: viewModel.state)
        // Cam (Material) her zaman koyu görünsün; açık sistem temasında beyaza dönmesin.
        .preferredColorScheme(.dark)
    }

    /// Kapalı çene tıklanabilir; imleç bunu el olarak gösterir.
    private func syncIdleCursor() {
        if viewModel.isHovering, case .idle = viewModel.state {
            NSCursor.pointingHand.set()
        } else {
            NSCursor.arrow.set()
        }
    }

    private var isOpen: Bool {
        if case .idle = viewModel.state { return false }
        return true
    }

    private var panelShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: isOpen ? NotchLayout.openCornerRadius : 0,
            bottomLeadingRadius: isOpen ? NotchLayout.openCornerRadius : (viewModel.isHovering ? 11 : 7),
            bottomTrailingRadius: isOpen ? NotchLayout.openCornerRadius : (viewModel.isHovering ? 11 : 7),
            topTrailingRadius: isOpen ? NotchLayout.openCornerRadius : 0
        )
    }

    private var notchWidth: CGFloat {
        NotchGeometry.current()?.notchWidth ?? NotchLayout.fallbackChinSize.width
    }

    @ViewBuilder
    private var panelBackground: some View {
        if isOpen {
            // Saydam cam. Üst kenarın ortası çentiğe yapışık kaldığı için
            // parlak çizgi yalnızca sol üst ve sağ üst omuzda görünür.
            panelShape
                .fill(.ultraThinMaterial)
                .overlay(panelShape.fill(Color.black.opacity(0.16)))
                .overlay(
                    panelShape.strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
                )
                .overlay {
                    panelShape
                        .strokeBorder(Color.white.opacity(0.92), lineWidth: 1)
                        .mask(
                            TopShoulderMask(
                                radius: NotchLayout.openCornerRadius,
                                notchWidth: notchWidth
                            )
                        )
                }
        } else {
            // Çentiğin üzerinde: mat siyah — kamera bölmesiyle bütünleşik kalmalı.
            panelShape.fill(Color(white: 0.02))
        }
    }

    /// Kapalı durum: pencere çentiği kaplar (siyah üstüne siyah, görünmez);
    /// yalnızca alttaki dilimde küçük bir indirme ikonu görünür.
    /// Hover çeneyi biraz uzatır; liste tıklayınca açılır.
    private var idleContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(viewModel.isHovering ? 0.1 : 0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                Image(systemName: "arrow.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(viewModel.isHovering ? 0.95 : 0.38))
                    .padding(.bottom, viewModel.isHovering ? 7 : 3)
                Capsule()
                    .fill(Color.white.opacity(viewModel.isHovering ? 0.9 : 0))
                    .frame(width: viewModel.isHovering ? 28 : 10, height: 2)
                    .padding(.bottom, 3)
            }
            .frame(maxWidth: .infinity)
            .frame(height: NotchLayout.idleChinHoverHeight)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { viewModel.expand() }
    }
}

/// Açık panelde sol üst ve sağ üst köşe çizgisini maskeler.
/// Çentiğin tam altındaki düz kenar boş kalır; çizgi köşeye doğru belirginleşir.
private struct TopShoulderMask: View {
    var radius: CGFloat
    var notchWidth: CGFloat

    var body: some View {
        GeometryReader { geo in
            let shoulder = min(
                geo.size.width / 2,
                max(radius + 16, (geo.size.width - notchWidth) / 2)
            )
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    LinearGradient(
                        colors: [.white, .white, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: shoulder)
                    Spacer(minLength: 0)
                    LinearGradient(
                        colors: [.clear, .white, .white],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: shoulder)
                }
                .frame(height: radius + 28)
                Spacer(minLength: 0)
            }
        }
    }
}

/// Yeni indirme geldiğinde birkaç saniye görünen küçük bildirim bandı.
struct PeekView: View {
    let file: DownloadedFile

    var body: some View {
        HStack(spacing: 10) {
            FileIconView(url: file.url, size: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(file.isScreenshot ? "Screenshot" : "Downloaded") · \(file.formattedSize)")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Son 5 indirilen dosyanın listelendiği geniş panel içeriği.
struct ExpandedListView: View {
    @ObservedObject var viewModel: NotchViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if viewModel.permissionDenied {
                permissionView
            } else if viewModel.files.isEmpty {
                emptyView
            } else {
                ForEach(viewModel.files) { file in
                    FileRowView(file: file, viewModel: viewModel)
                }
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        HStack {
            Text("RECENT DOWNLOADS")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
                .kerning(0.8)
            Spacer()
            Button(action: viewModel.openDownloadsFolder) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Open Downloads Folder")
        }
        .padding(.horizontal, 14)
        .frame(height: 28)
    }

    private var emptyView: some View {
        Text("No files in Downloads")
            .font(.system(size: 11.5))
            .foregroundStyle(.white.opacity(0.45))
            .frame(maxWidth: .infinity)
            .frame(height: NotchLayout.rowHeight)
    }

    private var permissionView: some View {
        VStack(spacing: 8) {
            Text("Downloads folder access is required")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))

            HStack(spacing: 8) {
                Button("Open System Settings") {
                    viewModel.openPrivacySettings()
                }
                Button("Try Again") {
                    viewModel.retryAccess()
                }
            }
            .font(.system(size: 11, weight: .medium))
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.white)
        }
        .frame(maxWidth: .infinity)
        .frame(height: NotchLayout.rowHeight * 2)
    }
}
