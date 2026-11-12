import SwiftUI

/// Portada que se descarga a través de `ImageDataCache`. Recibe varias URL
/// en orden de preferencia y usa la primera que tenga imagen.
/// Si ya se vio antes aparece al instante; si no, muestra el placeholder
/// generado y funde a la imagen real cuando llega.
/// Es decorativa: la etiqueta accesible la pone la vista que la contiene.
struct RemoteCoverView: View {
    let urls: [URL]
    let title: String
    let author: String?
    /// Tamaño máximo en píxeles al decodificar. Las miniaturas no necesitan más.
    var maxPixelSize = 600

    @State private var image: UIImage?

    init(urls: [URL], title: String, author: String?, maxPixelSize: Int = 600) {
        self.urls = urls
        self.title = title
        self.author = author
        self.maxPixelSize = maxPixelSize
        _image = State(initialValue: urls.lazy.compactMap {
            DecodedImageCache.shared.image(for: Self.cacheKey($0, maxPixelSize))
        }.first)
    }

    init(url: URL?, title: String, author: String?, maxPixelSize: Int = 600) {
        self.init(urls: url.map { [$0] } ?? [], title: title, author: author, maxPixelSize: maxPixelSize)
    }

    var body: some View {
        Color.clear
            .aspectRatio(DS.Layout.coverAspectRatio, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                } else {
                    CoverPlaceholderView(title: title, author: author, colorHex: DS.CoverPalette.hex(for: title))
                }
            }
            .coverStyle()
            .accessibilityHidden(true)
            .task(id: urls) { await load() }
    }

    private func load() async {
        for url in urls {
            let key = Self.cacheKey(url, maxPixelSize)
            if let cached = DecodedImageCache.shared.image(for: key) {
                image = cached
                return
            }
            guard let data = await ImageDataCache.shared.imageData(for: url) else { continue }
            let size = maxPixelSize
            let decoded = await Task.detached(priority: .userInitiated) {
                ImageDecoding.image(from: data, maxPixelSize: size)
            }.value
            guard let decoded, !Task.isCancelled else { return }
            DecodedImageCache.shared.insert(decoded, for: key)
            withAnimation(DS.Motion.spring) { image = decoded }
            return
        }
    }

    private static func cacheKey(_ url: URL, _ maxPixelSize: Int) -> String {
        "\(url.absoluteString)@\(maxPixelSize)"
    }
}
