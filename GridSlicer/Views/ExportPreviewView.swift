import SwiftUI

/// Model for a single export item with customizable filename
class ExportItem: Identifiable, ObservableObject {
    let id = UUID()
    let region: CropRegion
    let previewImage: PlatformImage?
    @Published var filename: String
    @Published var isSelected: Bool = true

    init(region: CropRegion, previewImage: PlatformImage?, defaultFilename: String) {
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

    let sourceImage: PlatformImage
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
            .background(Color(PlatformColor.systemGray6))

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
            .background(Color(PlatformColor.systemGray6))
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

    private func createPreviewImage(for region: CropRegion) -> PlatformImage? {
        let sourceSize = sourceImage.size
        let cropRect = region.pixelRect(for: sourceSize)

        // Create a small thumbnail
        let maxSize: CGFloat = 60
        let scale = min(maxSize / cropRect.width, maxSize / cropRect.height, 1.0)
        let thumbSize = CGSize(width: cropRect.width * scale, height: cropRect.height * scale)

        #if os(macOS)
        let thumbnail = PlatformImage(size: thumbSize)
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
        #else
        guard let cgImage = sourceImage.cgImage else { return nil }
        let cropCGRect = CGRect(
            x: cropRect.origin.x,
            y: cropRect.origin.y,
            width: cropRect.width,
            height: cropRect.height
        )
        guard let croppedCG = cgImage.cropping(to: cropCGRect) else { return nil }
        let croppedImage = UIImage(cgImage: croppedCG)

        let renderer = UIGraphicsImageRenderer(size: thumbSize)
        return renderer.image { _ in
            croppedImage.draw(in: CGRect(origin: .zero, size: thumbSize))
        }
        #endif
    }

    private func applyBaseFilename() {
        let trimmed = baseFilename.trimmingCharacters(in: .whitespaces)

        // Check if the string ends with a single letter (with optional spaces before it)
        // e.g., "3 Way - A" or "3 Way -A" or "Test_B"
        if let lastChar = trimmed.last, lastChar.isLetter {
            // Check if it's a single letter at the end (preceded by non-letter)
            let withoutLast = trimmed.dropLast()
            let trimmedWithoutLast = withoutLast.trimmingCharacters(in: .whitespaces)

            if let charBefore = trimmedWithoutLast.last, !charBefore.isLetter {
                // Found pattern like "prefix- A" or "prefix-A"
                let prefix = String(withoutLast) // Keep original spacing
                for (index, item) in exportItems.enumerated() {
                    if let nextChar = incrementLetter(lastChar, by: index) {
                        item.filename = "\(prefix)\(nextChar)"
                    } else {
                        item.filename = "\(prefix)\(lastChar)\(index + 1)"
                    }
                }
                return
            }
        }

        // Check if string ends with a number
        var digits = ""
        for char in trimmed.reversed() {
            if char.isNumber {
                digits = String(char) + digits
            } else {
                break
            }
        }

        if !digits.isEmpty, let startNumber = Int(digits) {
            let prefix = String(trimmed.dropLast(digits.count))
            for (index, item) in exportItems.enumerated() {
                item.filename = "\(prefix)\(startNumber + index)"
            }
            return
        }

        // Default: just append -1, -2, -3
        for (index, item) in exportItems.enumerated() {
            item.filename = "\(trimmed)-\(index + 1)"
        }
    }

    /// Increment a letter by a given amount (A + 1 = B, A + 2 = C, etc.)
    private func incrementLetter(_ char: Character, by amount: Int) -> Character? {
        let isUppercase = char.isUppercase
        let baseScalar: UInt8 = isUppercase ? 65 : 97  // 'A' or 'a'

        guard let charValue = char.asciiValue else { return nil }

        let offset = Int(charValue) - Int(baseScalar)
        let newOffset = offset + amount

        // Check if we exceed Z/z (26 letters)
        guard newOffset >= 0 && newOffset < 26 else { return nil }

        return Character(UnicodeScalar(baseScalar + UInt8(newOffset)))
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
                if let croppedImage = self.cropImage(self.sourceImage, to: item.region) {
                    let filename = item.filename.hasSuffix(".png") ? item.filename : "\(item.filename).png"
                    let fileURL = self.outputFolder.appendingPathComponent(filename)

                    #if os(macOS)
                    if let tiffData = croppedImage.tiffRepresentation,
                       let bitmapRep = NSBitmapImageRep(data: tiffData),
                       let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                        try? pngData.write(to: fileURL)
                        exported += 1
                    }
                    #else
                    if let pngData = croppedImage.pngData() {
                        try? pngData.write(to: fileURL)
                        exported += 1
                    }
                    #endif
                }

                DispatchQueue.main.async {
                    self.exportProgress = Double(exported) / Double(total)
                }
            }

            DispatchQueue.main.async {
                isExporting = false
                viewModel.statusMessage = "Exported \(exported) files to \(outputFolder.lastPathComponent)"
                isPresented = false
            }
        }
    }

    private func cropImage(_ image: PlatformImage, to region: CropRegion) -> PlatformImage? {
        let sourceSize = image.size
        let cropRect = region.pixelRect(for: sourceSize)

        guard cropRect.width > 0 && cropRect.height > 0 else { return nil }

        #if os(macOS)
        let croppedImage = PlatformImage(size: NSSize(width: cropRect.width, height: cropRect.height))
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
        #else
        guard let cgImage = image.cgImage,
              let croppedCG = cgImage.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: croppedCG)
        #endif
    }
}

/// Row view for a single export item
struct ExportItemRow: View {
    @ObservedObject var item: ExportItem

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Toggle("", isOn: $item.isSelected)
                #if os(macOS)
                .toggleStyle(.checkbox)
                #endif
                .labelsHidden()

            // Preview thumbnail
            if let preview = item.previewImage {
                Image(platformImage: preview)
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
        sourceImage: PlatformImage(),
        regions: [],
        outputFolder: URL(fileURLWithPath: "/tmp")
    )
}
