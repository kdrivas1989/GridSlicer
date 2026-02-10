#if os(macOS)
import AppKit
#else
import UIKit
#endif
import CoreGraphics

/// Handles cropping and exporting image regions
class ImageExporter {

    enum ExportError: LocalizedError {
        case invalidImage
        case cropFailed(region: CropRegion)
        case saveFailed(filename: String, reason: String)
        case noRegions

        var errorDescription: String? {
            switch self {
            case .invalidImage:
                return "The image could not be processed."
            case .cropFailed(let region):
                return "Failed to crop region at row \(region.row + 1), column \(region.column + 1)."
            case .saveFailed(let filename, let reason):
                return "Failed to save file: \(filename). \(reason)"
            case .noRegions:
                return "No regions to export."
            }
        }
    }

    /// Export all crop regions to the specified folder
    static func exportRegions(
        from image: PlatformImage,
        regions: [CropRegion],
        to folderURL: URL,
        baseName: String
    ) throws -> Int {
        guard !regions.isEmpty else {
            throw ExportError.noRegions
        }

        #if os(macOS)
        return try exportRegionsMacOS(from: image, regions: regions, to: folderURL, baseName: baseName)
        #else
        return try exportRegionsiOS(from: image, regions: regions, to: folderURL, baseName: baseName)
        #endif
    }

    #if os(macOS)
    private static func exportRegionsMacOS(
        from image: NSImage,
        regions: [CropRegion],
        to folderURL: URL,
        baseName: String
    ) throws -> Int {
        guard let bitmapRep = getBitmapRepresentation(from: image) else {
            throw ExportError.invalidImage
        }

        let imageSize = CGSize(width: bitmapRep.pixelsWide, height: bitmapRep.pixelsHigh)
        var exportedCount = 0

        for region in regions {
            let pixelRect = region.pixelRect(for: imageSize)

            let clampedRect = CGRect(
                x: max(0, floor(pixelRect.origin.x)),
                y: max(0, floor(pixelRect.origin.y)),
                width: min(ceil(pixelRect.width), imageSize.width - floor(pixelRect.origin.x)),
                height: min(ceil(pixelRect.height), imageSize.height - floor(pixelRect.origin.y))
            )

            guard clampedRect.width > 0 && clampedRect.height > 0 else { continue }

            guard let croppedImage = cropBitmap(bitmapRep, to: clampedRect) else {
                throw ExportError.cropFailed(region: region)
            }

            let filename = region.filename(baseName: baseName)
            let fileURL = folderURL.appendingPathComponent(filename)

            do {
                try savePNG(image: croppedImage, to: fileURL)
                exportedCount += 1
            } catch {
                throw ExportError.saveFailed(filename: filename, reason: error.localizedDescription)
            }
        }

        return exportedCount
    }

    private static func getBitmapRepresentation(from image: NSImage) -> NSBitmapImageRep? {
        for rep in image.representations {
            if let bitmapRep = rep as? NSBitmapImageRep {
                return bitmapRep
            }
        }

        let size = image.size
        guard size.width > 0 && size.height > 0 else { return nil }

        let pixelWidth = Int(size.width)
        let pixelHeight = Int(size.height)

        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)

        image.draw(in: NSRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight),
                   from: NSRect(x: 0, y: 0, width: size.width, height: size.height),
                   operation: .copy,
                   fraction: 1.0)

        NSGraphicsContext.restoreGraphicsState()

        return bitmapRep
    }

    private static func cropBitmap(_ bitmapRep: NSBitmapImageRep, to rect: CGRect) -> NSImage? {
        let width = Int(rect.width)
        let height = Int(rect.height)

        guard width > 0 && height > 0 else { return nil }

        guard let croppedRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: croppedRep)

        let sourceRect = NSRect(x: rect.origin.x, y: CGFloat(bitmapRep.pixelsHigh) - rect.origin.y - rect.height,
                                width: rect.width, height: rect.height)
        let destRect = NSRect(x: 0, y: 0, width: width, height: height)

        let sourceImage = NSImage(size: NSSize(width: bitmapRep.pixelsWide, height: bitmapRep.pixelsHigh))
        sourceImage.addRepresentation(bitmapRep)

        sourceImage.draw(in: destRect, from: sourceRect, operation: .copy, fraction: 1.0)

        NSGraphicsContext.restoreGraphicsState()

        let resultImage = NSImage(size: NSSize(width: width, height: height))
        resultImage.addRepresentation(croppedRep)

        return resultImage
    }

    private static func savePNG(image: NSImage, to url: URL) throws {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "ImageExporter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create PNG data"])
        }

        try pngData.write(to: url)
    }
    #else
    // iOS implementation
    private static func exportRegionsiOS(
        from image: UIImage,
        regions: [CropRegion],
        to folderURL: URL,
        baseName: String
    ) throws -> Int {
        let imageSize = image.size
        var exportedCount = 0

        for region in regions {
            let pixelRect = region.pixelRect(for: imageSize)

            let clampedRect = CGRect(
                x: max(0, floor(pixelRect.origin.x)),
                y: max(0, floor(pixelRect.origin.y)),
                width: min(ceil(pixelRect.width), imageSize.width - floor(pixelRect.origin.x)),
                height: min(ceil(pixelRect.height), imageSize.height - floor(pixelRect.origin.y))
            )

            guard clampedRect.width > 0 && clampedRect.height > 0 else { continue }

            guard let cgImage = image.cgImage,
                  let croppedCGImage = cgImage.cropping(to: clampedRect) else {
                throw ExportError.cropFailed(region: region)
            }

            let croppedImage = UIImage(cgImage: croppedCGImage)

            let filename = region.filename(baseName: baseName)
            let fileURL = folderURL.appendingPathComponent(filename)

            do {
                guard let pngData = croppedImage.pngData() else {
                    throw NSError(domain: "ImageExporter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create PNG data"])
                }
                try pngData.write(to: fileURL)
                exportedCount += 1
            } catch {
                throw ExportError.saveFailed(filename: filename, reason: error.localizedDescription)
            }
        }

        return exportedCount
    }
    #endif
}
