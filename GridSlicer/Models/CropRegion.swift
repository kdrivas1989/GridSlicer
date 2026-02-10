import Foundation
import CoreGraphics

/// Represents a single crop region defined by normalized coordinates (0-1)
struct CropRegion: Identifiable, Equatable {
    let id = UUID()
    let row: Int
    let column: Int
    let normalizedRect: CGRect

    /// Convert normalized coordinates to pixel coordinates for a given image size
    func pixelRect(for imageSize: CGSize) -> CGRect {
        CGRect(
            x: normalizedRect.origin.x * imageSize.width,
            y: normalizedRect.origin.y * imageSize.height,
            width: normalizedRect.width * imageSize.width,
            height: normalizedRect.height * imageSize.height
        )
    }

    /// Generate filename for this region
    func filename(baseName: String) -> String {
        "\(baseName)_row\(row + 1)_col\(column + 1).png"
    }
}
