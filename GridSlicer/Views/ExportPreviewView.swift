import SwiftUI

/// Model for a single export item with customizable filename
class ExportItem: Identifiable, ObservableObject {
    let id = UUID()
    let region: CropRegion
    let previewImage: NSImage?
    @Published var filename: String
    @Published var isSelected: Bool = true

    init(region: CropRegion, previewImage: NSImage?, defaultFilename: String) {
        self.region = region
        self.previewImage = previewImage
        self.filename = defaultFilename
    }
}

/// Preview dialog for export with rename capability
struct ExportPreviewView: View {
    @ObservedObject var viewModel: GridSlicerViewModel
    @Binding var isPresented: Bool
    @State private var exportItems: [ExportItem] = []
    @State private var isExporting = false
    @State private var exportProgress: Double = 0
    @State private var baseFilename: String = ""

    let sourceImage: NSImage
    let regions: [CropRegion]
    let outputFolder: URL

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Export Preview")
                    .font(.headline)
                Spacer()
                Text("\(selectedCount) of \(exportItems.count) selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Base filename editor
            HStack {
                Text("Base name:")
                    .foregroundColor(.secondary)
                TextField("filename", text: $baseFilename)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                Button("Apply to All") {
                    applyBaseFilename()
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // List of export items
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(exportItems) { item in
                        ExportItemRow(item: item)
                    }
                }
                .padding()
            }

            Divider()

            // Footer with actions
            HStack {
                Button("Select All") {
                    exportItems.forEach { $0.isSelected = true }
                }
                .buttonStyle(.bordered)

                Button("Select None") {
                    exportItems.forEach { $0.isSelected = false }
                }
                .buttonStyle(.bordered)

                Spacer()

                if isExporting {
                    ProgressView(value: exportProgress)
                        .frame(width: 100)
                    Text("Exporting...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .buttonStyle(.bordered)

                    Button("Export \(selectedCount) Files") {
                        performExport()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedCount == 0)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .frame(width: 600, height: 500)
        .onAppear {
            setupExportItems()
        }
    }

    private var selectedCount: Int {
        exportItems.filter { $0.isSelected }.count
    }

    private func setupExportItems() {
        let baseName = viewModel.imageName.isEmpty ? "image" : viewModel.imageName
        baseFilename = "\(baseName)-1"

        // Create preview images and export items with sequential numbering
        exportItems = regions.enumerated().map { index, region in
            let defaultName = "\(baseName)-\(index + 1)"
            let preview = createPreviewImage(for: region)
            return ExportItem(region: region, previewImage: preview, defaultFilename: defaultName)
        }
    }

    private func createPreviewImage(for region: CropRegion) -> NSImage? {
        let sourceSize = sourceImage.size
        let cropRect = region.pixelRect(for: sourceSize)

        // Create a small thumbnail
        let maxSize: CGFloat = 60
        let scale = min(maxSize / cropRect.width, maxSize / cropRect.height, 1.0)
        let thumbSize = NSSize(width: cropRect.width * scale, height: cropRect.height * scale)

        let thumbnail = NSImage(size: thumbSize)
        thumbnail.lockFocus()

        let sourceRect = NSRect(
            x: cropRect.origin.x,
            y: sourceSize.height - cropRect.origin.y - cropRect.height,
            width: cropRect.width,
            height: cropRect.height
        )
        let destRect = NSRect(origin: .zero, size: thumbSize)

        sourceImage.draw(in: destRect, from: sourceRect, operation: .copy, fraction: 1.0)

        thumbnail.unlockFocus()
        return thumbnail
    }

    private func applyBaseFilename() {
        // Parse the base filename to extract prefix and starting value (letter or number)
        let parsed = parseFilename(baseFilename)

        for (index, item) in exportItems.enumerated() {
            switch parsed {
            case .number(let prefix, let start):
                // Increment numbers: 1, 2, 3...
                item.filename = "\(prefix)\(start + index)"
            case .letter(let prefix, let startChar):
                // Increment letters: A, B, C...
                if let nextChar = incrementLetter(startChar, by: index) {
                    item.filename = "\(prefix)\(nextChar)"
                } else {
                    // Fallback if we exceed Z
                    item.filename = "\(prefix)\(startChar)\(index + 1)"
                }
            case .plain(let prefix):
                // No number or letter found, append sequential number
                item.filename = "\(prefix)-\(index + 1)"
            }
        }
    }

    /// Result of parsing a filename
    private enum FilenamePattern {
        case number(prefix: String, start: Int)
        case letter(prefix: String, start: Character)
        case plain(prefix: String)
    }

    /// Parse filename to extract prefix and trailing number or letter
    /// e.g., "FS-21" returns .number("FS-", 21)
    /// e.g., "FS-A" returns .letter("FS-", "A")
    /// e.g., "image" returns .plain("image")
    private func parseFilename(_ filename: String) -> FilenamePattern {
        guard !filename.isEmpty else { return .plain(prefix: filename) }

        // Check for trailing digits first
        var digits = ""
        for char in filename.reversed() {
            if char.isNumber {
                digits = String(char) + digits
            } else {
                break
            }
        }

        if !digits.isEmpty, let number = Int(digits) {
            let prefix = String(filename.dropLast(digits.count))
            return .number(prefix: prefix, start: number)
        }

        // Check for trailing letter (A-Z or a-z)
        if let lastChar = filename.last, lastChar.isLetter {
            // Make sure it's a single letter at the end (after a separator like - or _)
            let prefix = String(filename.dropLast(1))
            if prefix.isEmpty || !prefix.last!.isLetter {
                return .letter(prefix: prefix, start: lastChar)
            }
        }

        return .plain(prefix: filename)
    }

    /// Increment a letter by a given amount (A + 1 = B, A + 2 = C, etc.)
    private func incrementLetter(_ char: Character, by amount: Int) -> Character? {
        let isUppercase = char.isUppercase
        let base: Character = isUppercase ? "A" : "a"

        guard let baseValue = base.asciiValue,
              let charValue = char.asciiValue else { return nil }

        let offset = Int(charValue - baseValue)
        let newOffset = offset + amount

        // Check if we exceed Z/z (26 letters)
        guard newOffset < 26 else { return nil }

        let newValue = baseValue + UInt8(newOffset)
        return Character(UnicodeScalar(newValue))
    }

    private func performExport() {
        let selectedItems = exportItems.filter { $0.isSelected }
        guard !selectedItems.isEmpty else { return }

        isExporting = true
        exportProgress = 0

        DispatchQueue.global(qos: .userInitiated).async {
            var exported = 0
            let total = selectedItems.count

            for item in selectedItems {
                // Create the cropped image
                if let croppedImage = cropImage(sourceImage, to: item.region) {
                    let filename = item.filename.hasSuffix(".png") ? item.filename : "\(item.filename).png"
                    let fileURL = outputFolder.appendingPathComponent(filename)

                    if let tiffData = croppedImage.tiffRepresentation,
                       let bitmapRep = NSBitmapImageRep(data: tiffData),
                       let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                        try? pngData.write(to: fileURL)
                        exported += 1
                    }
                }

                DispatchQueue.main.async {
                    exportProgress = Double(exported) / Double(total)
                }
            }

            DispatchQueue.main.async {
                isExporting = false
                viewModel.statusMessage = "Exported \(exported) files to \(outputFolder.lastPathComponent)"
                isPresented = false
            }
        }
    }

    private func cropImage(_ image: NSImage, to region: CropRegion) -> NSImage? {
        let sourceSize = image.size
        let cropRect = region.pixelRect(for: sourceSize)

        guard cropRect.width > 0 && cropRect.height > 0 else { return nil }

        let croppedImage = NSImage(size: NSSize(width: cropRect.width, height: cropRect.height))
        croppedImage.lockFocus()

        let sourceRect = NSRect(
            x: cropRect.origin.x,
            y: sourceSize.height - cropRect.origin.y - cropRect.height,
            width: cropRect.width,
            height: cropRect.height
        )
        let destRect = NSRect(origin: .zero, size: NSSize(width: cropRect.width, height: cropRect.height))

        image.draw(in: destRect, from: sourceRect, operation: .copy, fraction: 1.0)

        croppedImage.unlockFocus()
        return croppedImage
    }
}

/// Row view for a single export item
struct ExportItemRow: View {
    @ObservedObject var item: ExportItem

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Toggle("", isOn: $item.isSelected)
                .toggleStyle(.checkbox)
                .labelsHidden()

            // Preview thumbnail
            if let preview = item.previewImage {
                Image(nsImage: preview)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .cornerRadius(4)
            }

            // Region info
            VStack(alignment: .leading, spacing: 2) {
                Text("Row \(item.region.row + 1), Col \(item.region.column + 1)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                let rect = item.region.normalizedRect
                Text("\(Int(rect.width * 100))% × \(Int(rect.height * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .frame(width: 100, alignment: .leading)

            // Filename editor
            TextField("Filename", text: $item.filename)
                .textFieldStyle(.roundedBorder)
                .disabled(!item.isSelected)
                .opacity(item.isSelected ? 1.0 : 0.5)

            Text(".png")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(item.isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }
}

#Preview {
    ExportPreviewView(
        viewModel: GridSlicerViewModel(),
        isPresented: .constant(true),
        sourceImage: NSImage(),
        regions: [],
        outputFolder: URL(fileURLWithPath: "/tmp")
    )
}
