#if os(macOS)
import AppKit
#else
import UIKit
#endif
import CoreImage
import Accelerate

/// Detects borders/grid lines in an image
class BorderDetector {

    /// Detect horizontal and vertical divider positions in an image
    /// Returns normalized positions (0-1) for vertical and horizontal lines
    static func detectBorders(in image: PlatformImage, maxLines: Int = 8, minSpacing: CGFloat = 0.08) -> (vertical: [CGFloat], horizontal: [CGFloat]) {
        #if os(macOS)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            // Try alternative method to get CGImage
            guard let tiffData = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let cg = bitmap.cgImage else {
                return ([], [])
            }
            return detectBordersInCGImage(cg, maxLines: maxLines, minSpacing: minSpacing)
        }
        return detectBordersInCGImage(cgImage, maxLines: maxLines, minSpacing: minSpacing)
        #else
        guard let cgImage = image.cgImage else {
            return ([], [])
        }
        return detectBordersInCGImage(cgImage, maxLines: maxLines, minSpacing: minSpacing)
        #endif
    }

    private static func detectBordersInCGImage(_ cgImage: CGImage, maxLines: Int, minSpacing: CGFloat) -> (vertical: [CGFloat], horizontal: [CGFloat]) {
        let width = cgImage.width
        let height = cgImage.height

        // Create grayscale bitmap
        guard let grayscale = createGrayscaleBitmap(from: cgImage) else {
            return ([], [])
        }

        // Detect edges
        let edges = detectEdges(in: grayscale, width: width, height: height)

        // Find vertical lines (scan columns) - use minimum spacing based on image width
        let minVerticalDistance = Int(CGFloat(width) * minSpacing)
        let verticalLines = findVerticalLines(in: edges, width: width, height: height, minDistance: minVerticalDistance, maxLines: maxLines)

        // Find horizontal lines (scan rows) - use minimum spacing based on image height
        let minHorizontalDistance = Int(CGFloat(height) * minSpacing)
        let horizontalLines = findHorizontalLines(in: edges, width: width, height: height, minDistance: minHorizontalDistance, maxLines: maxLines)

        return (verticalLines, horizontalLines)
    }

    /// Convert image to grayscale pixel array
    private static func createGrayscaleBitmap(from cgImage: CGImage) -> [UInt8]? {
        let width = cgImage.width
        let height = cgImage.height

        var pixels = [UInt8](repeating: 0, count: width * height)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels
    }

    /// Simple edge detection using gradient magnitude
    private static func detectEdges(in pixels: [UInt8], width: Int, height: Int) -> [Float] {
        var edges = [Float](repeating: 0, count: width * height)

        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let idx = y * width + x

                // Sobel-like gradient
                let gx = Float(pixels[idx + 1]) - Float(pixels[idx - 1])
                let gy = Float(pixels[idx + width]) - Float(pixels[idx - width])

                edges[idx] = sqrt(gx * gx + gy * gy)
            }
        }

        return edges
    }

    /// Find vertical lines by analyzing column edge density
    private static func findVerticalLines(in edges: [Float], width: Int, height: Int, minDistance: Int, maxLines: Int) -> [CGFloat] {
        var columnScores = [Float](repeating: 0, count: width)

        // Sum edge values for each column
        for x in 0..<width {
            var sum: Float = 0
            for y in 0..<height {
                sum += edges[y * width + x]
            }
            columnScores[x] = sum / Float(height)
        }

        // Find the strongest peaks with minimum spacing
        let peaks = findStrongestPeaks(in: columnScores, minDistance: minDistance, maxPeaks: maxLines)

        // Convert to normalized positions, excluding edges
        let normalizedLines = peaks
            .map { CGFloat($0) / CGFloat(width) }
            .filter { $0 > 0.03 && $0 < 0.97 }

        return normalizedLines
    }

    /// Find horizontal lines by analyzing row edge density
    private static func findHorizontalLines(in edges: [Float], width: Int, height: Int, minDistance: Int, maxLines: Int) -> [CGFloat] {
        var rowScores = [Float](repeating: 0, count: height)

        // Sum edge values for each row
        for y in 0..<height {
            var sum: Float = 0
            for x in 0..<width {
                sum += edges[y * width + x]
            }
            rowScores[y] = sum / Float(width)
        }

        // Find the strongest peaks with minimum spacing
        let peaks = findStrongestPeaks(in: rowScores, minDistance: minDistance, maxPeaks: maxLines)

        // Convert to normalized positions, excluding edges
        let normalizedLines = peaks
            .map { CGFloat($0) / CGFloat(height) }
            .filter { $0 > 0.03 && $0 < 0.97 }

        return normalizedLines
    }

    /// Find the N strongest peaks with minimum spacing between them
    private static func findStrongestPeaks(in signal: [Float], minDistance: Int, maxPeaks: Int) -> [Int] {
        // First, find all local maxima
        var allPeaks: [(index: Int, value: Float)] = []

        for i in 1..<(signal.count - 1) {
            // Check if this is a local maximum
            if signal[i] > signal[i - 1] && signal[i] > signal[i + 1] {
                allPeaks.append((index: i, value: signal[i]))
            }
        }

        // Sort by strength (descending)
        allPeaks.sort { $0.value > $1.value }

        // Select peaks ensuring minimum distance
        var selectedPeaks: [Int] = []

        for peak in allPeaks {
            // Check if this peak is far enough from all selected peaks
            let isFarEnough = selectedPeaks.allSatisfy { abs($0 - peak.index) >= minDistance }

            if isFarEnough {
                selectedPeaks.append(peak.index)
                if selectedPeaks.count >= maxPeaks {
                    break
                }
            }
        }

        // Sort by position
        return selectedPeaks.sorted()
    }

    /// Detect borders with default settings for typical grid images
    /// - Parameters:
    ///   - image: The image to analyze
    ///   - columns: Expected number of columns (vertical lines = columns - 1)
    ///   - rows: Expected number of rows (horizontal lines = rows - 1)
    static func detectGridBorders(in image: PlatformImage, columns: Int = 5, rows: Int = 5) -> (vertical: [CGFloat], horizontal: [CGFloat]) {
        // Calculate minimum spacing based on expected grid size
        let minSpacing: CGFloat = 1.0 / CGFloat(max(columns, rows) + 1) * 0.8
        return detectBorders(in: image, maxLines: max(columns, rows) - 1, minSpacing: minSpacing)
    }
}
