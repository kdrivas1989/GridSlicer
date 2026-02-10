import SwiftUI
import UniformTypeIdentifiers

/// Main canvas view displaying the image with grid overlay
struct ImageCanvasView: View {
    @ObservedObject var viewModel: GridSlicerViewModel
    @State private var optionKeyPressed = false
    @State private var isDropTargeted = false
    @State private var zoomScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var lastPanOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color(nsColor: .windowBackgroundColor)

                if let image = viewModel.image {
                    // Centered zoomable image with grid overlay
                    ScrollViewReader { scrollProxy in
                        ScrollView([.horizontal, .vertical], showsIndicators: true) {
                            ZStack {
                                // Invisible spacer to enable scrolling when zoomed
                                Color.clear
                                    .frame(
                                        width: max(geometry.size.width, geometry.size.width * zoomScale),
                                        height: max(geometry.size.height, geometry.size.height * zoomScale)
                                    )

                                // Centered image with grid
                                imageWithGrid(image: image, containerSize: geometry.size)
                                    .scaleEffect(zoomScale)
                                    .id("centerImage")
                            }
                        }
                        .onChange(of: zoomScale) { _ in
                            withAnimation(.easeInOut(duration: 0.1)) {
                                scrollProxy.scrollTo("centerImage", anchor: .center)
                            }
                        }
                    }
                } else {
                    // Drop zone placeholder
                    dropZonePlaceholder
                }

                // Drop target highlight
                if isDropTargeted {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.accentColor, lineWidth: 4)
                        .background(Color.accentColor.opacity(0.1))
                        .padding(8)
                }

                // Zoom controls
                if viewModel.image != nil {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            zoomControls
                                .padding()
                        }
                    }
                }
            }
        }
        .onDrop(of: [.image, .pdf, .fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
        .onAppear {
            setupKeyMonitor()
        }
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    zoomScale = max(0.5, min(5.0, value))
                }
        )
    }

    private var zoomControls: some View {
        HStack(spacing: 8) {
            Button(action: { zoomScale = max(0.5, zoomScale - 0.25) }) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.title3)
            }
            .buttonStyle(.bordered)
            .help("Zoom out")

            Text("\(Int(zoomScale * 100))%")
                .font(.caption)
                .monospacedDigit()
                .frame(width: 50)

            Button(action: { zoomScale = min(5.0, zoomScale + 0.25) }) {
                Image(systemName: "plus.magnifyingglass")
                    .font(.title3)
            }
            .buttonStyle(.bordered)
            .help("Zoom in")

            Button(action: { zoomScale = 1.0 }) {
                Image(systemName: "1.magnifyingglass")
                    .font(.title3)
            }
            .buttonStyle(.bordered)
            .help("Reset zoom to 100%")
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.9))
                .shadow(radius: 4)
        )
    }

    @ViewBuilder
    private func imageWithGrid(image: NSImage, containerSize: CGSize) -> some View {
        let imageSize = image.size
        let scaledSize = calculateFitSize(imageSize: imageSize, containerSize: containerSize)

        ZStack {
            // Checkerboard background for transparency
            CheckerboardView()
                .frame(width: scaledSize.width, height: scaledSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            // The image
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: scaledSize.width, height: scaledSize.height)

            // Grid overlay
            GridOverlayView(
                gridState: viewModel.gridState,
                containerSize: scaledSize,
                optionKeyPressed: optionKeyPressed
            )
            .frame(width: scaledSize.width, height: scaledSize.height)
        }
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }

    private var dropZonePlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("Drop an image or PDF here")
                .font(.title2)
                .foregroundColor(.secondary)

            Text("or click \"Open Image\" in the toolbar")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [10, 5]))
                .foregroundColor(.secondary.opacity(0.5))
                .padding(20)
        )
    }

    private func calculateFitSize(imageSize: CGSize, containerSize: CGSize) -> CGSize {
        let padding: CGFloat = 40
        let availableWidth = containerSize.width - padding * 2
        let availableHeight = containerSize.height - padding * 2

        let widthRatio = availableWidth / imageSize.width
        let heightRatio = availableHeight / imageSize.height
        let scale = min(widthRatio, heightRatio, 1.0)

        return CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        // Try to load as file URL first (handles both images and PDFs)
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                guard error == nil,
                      let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    return
                }

                DispatchQueue.main.async {
                    viewModel.loadImage(from: url)
                }
            }
            return true
        }

        // Try to load as PDF data
        if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.pdf.identifier, options: nil) { item, error in
                guard error == nil else { return }

                if let url = item as? URL {
                    DispatchQueue.main.async {
                        viewModel.loadPDF(from: url)
                    }
                }
            }
            return true
        }

        // Try to load as image data
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, error in
                guard error == nil else { return }

                var image: NSImage?
                var name = "Dropped Image"

                if let nsImage = item as? NSImage {
                    image = nsImage
                } else if let data = item as? Data {
                    image = NSImage(data: data)
                } else if let url = item as? URL {
                    image = NSImage(contentsOf: url)
                    name = url.deletingPathExtension().lastPathComponent
                }

                if let image = image {
                    DispatchQueue.main.async {
                        viewModel.loadImage(image, name: name)
                    }
                }
            }
            return true
        }

        return false
    }

    private func setupKeyMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            optionKeyPressed = event.modifierFlags.contains(.option)
            return event
        }
    }
}

/// Checkerboard pattern for showing transparency
struct CheckerboardView: View {
    let squareSize: CGFloat = 10

    var body: some View {
        Canvas { context, size in
            let rows = Int(ceil(size.height / squareSize))
            let cols = Int(ceil(size.width / squareSize))

            for row in 0..<rows {
                for col in 0..<cols {
                    let isLight = (row + col) % 2 == 0
                    let rect = CGRect(
                        x: CGFloat(col) * squareSize,
                        y: CGFloat(row) * squareSize,
                        width: squareSize,
                        height: squareSize
                    )
                    context.fill(
                        Path(rect),
                        with: .color(isLight ? .white : Color(white: 0.85))
                    )
                }
            }
        }
    }
}

#Preview {
    ImageCanvasView(viewModel: GridSlicerViewModel())
        .frame(width: 800, height: 600)
}
