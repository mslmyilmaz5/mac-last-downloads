import SwiftUI

/// Dosya ikonu — NSWorkspace'in gerçek (Quick Look destekli) ikonunu kullanır.
struct FileIconView: View {
    let url: URL
    let size: CGFloat

    var body: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
            .resizable()
            .frame(width: size, height: size)
    }
}

/// Listedeki tek bir dosya satırı.
/// - Tık: aç
/// - Sürükle: dosyayı Finder'a / başka uygulamaya taşır
/// - Hover: hızlı aksiyon düğmeleri
/// - Sağ tık: tüm aksiyonlar
struct FileRowView: View {
    let file: DownloadedFile
    @ObservedObject var viewModel: NotchViewModel
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            FileIconView(url: file.url, size: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 4) {
                    if file.isRecent {
                        Circle()
                            .fill(.green)
                            .frame(width: 5, height: 5)
                    }
                    Text("\(file.formattedSize) · \(file.relativeDate)")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if isHovering {
                HStack(spacing: 4) {
                    QuickActionButton(systemName: "folder", help: "Finder'da Göster") {
                        viewModel.reveal(file)
                    }
                    QuickActionButton(systemName: "doc.on.doc", help: "Kopyala") {
                        viewModel.copy(file)
                    }
                    QuickActionButton(systemName: "square.and.arrow.up", help: "Paylaş…") {
                        viewModel.share(file)
                    }
                    QuickActionButton(systemName: "trash", help: "Çöp Kutusuna Taşı") {
                        viewModel.trash(file)
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: NotchLayout.rowHeight)
        .background(isHovering ? Color.white.opacity(0.08) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            viewModel.open(file)
        }
        .onDrag {
            NSItemProvider(object: file.url as NSURL)
        }
        .contextMenu {
            Button("Aç") { viewModel.open(file) }
            Button("Finder'da Göster") { viewModel.reveal(file) }
            Divider()
            Button("Kopyala") { viewModel.copy(file) }
            Button("Paylaş…") { viewModel.share(file) }
            Divider()
            Button("Çöp Kutusuna Taşı", role: .destructive) { viewModel.trash(file) }
        }
    }
}

/// Satır hover'ında görünen küçük kare aksiyon düğmesi.
struct QuickActionButton: View {
    let systemName: String
    let help: String
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(isHovering ? 1 : 0.7))
                .frame(width: 24, height: 24)
                .background(
                    Color.white.opacity(isHovering ? 0.18 : 0.10),
                    in: RoundedRectangle(cornerRadius: 6)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(help)
    }
}
