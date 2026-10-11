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
        .onHover { viewModel.setHovering($0) }
        .animation(.easeOut(duration: 0.18), value: viewModel.state)
        // Cam (Material) her zaman koyu görünsün; açık sistem temasında beyaza dönmesin.
        .preferredColorScheme(.dark)
    }

    private var panelShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: cornerRadius,
            bottomTrailingRadius: cornerRadius,
            topTrailingRadius: 0
        )
    }

    @ViewBuilder
    private var panelBackground: some View {
        if case .idle = viewModel.state {
            // Çentiğin üzerinde: mat siyah — kamera bölmesiyle bütünleşik kalmalı.
            panelShape.fill(Color(white: 0.02))
        } else {
            // Açık durum: koyu cam + hafif karartma + ince border.
            panelShape
                .fill(.regularMaterial)
                .overlay(panelShape.fill(Color.black.opacity(0.30)))
                .overlay(panelShape.strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
        }
    }

    private var cornerRadius: CGFloat {
        if case .idle = viewModel.state { return 7 }
        return 14
    }

    /// Kapalı durum: pencere çentiği kaplar (siyah üstüne siyah, görünmez);
    /// yalnızca alttaki dilimde küçük bir indirme ikonu görünür.
    private var idleContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            Image(systemName: "arrow.down")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white.opacity(0.5))
                .frame(height: NotchLayout.idleChinHeight)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { viewModel.expand() }
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
                Text("\(file.isScreenshot ? "Ekran görüntüsü" : "İndirildi") · \(file.formattedSize)")
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
            Text("SON İNDİRİLENLER")
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
            .help("İndirilenler Klasörünü Aç")
        }
        .padding(.horizontal, 14)
        .frame(height: 28)
    }

    private var emptyView: some View {
        Text("İndirilenler klasöründe dosya yok")
            .font(.system(size: 11.5))
            .foregroundStyle(.white.opacity(0.45))
            .frame(maxWidth: .infinity)
            .frame(height: NotchLayout.rowHeight)
    }

    private var permissionView: some View {
        VStack(spacing: 8) {
            Text("İndirilenler klasörüne erişim izni gerekli")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))

            HStack(spacing: 8) {
                Button("Sistem Ayarları'nı Aç") {
                    viewModel.openPrivacySettings()
                }
                Button("Yeniden Dene") {
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
