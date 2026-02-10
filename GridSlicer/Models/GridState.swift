import Foundation
import CoreGraphics

/// Manages the grid divider positions and computes crop regions
class GridState: ObservableObject {
    /// Vertical divider positions (X coordinates, normalized 0-1)
    @Published var verticalDividers: [CGFloat] = []

    /// Horizontal divider positions (Y coordinates, normalized 0-1)
    @Published var horizontalDividers: [CGFloat] = []

    /// Header exclusion zone (top area to skip, normalized 0-1)
    @Published var headerExclusion: CGFloat = 0.0

    /// Footer exclusion zone (bottom area to skip, normalized 0-1)
    @Published var footerExclusion: CGFloat = 0.0

    /// Left margin exclusion (normalized 0-1)
    @Published var leftExclusion: CGFloat = 0.0

    /// Right margin exclusion (normalized 0-1)
    @Published var rightExclusion: CGFloat = 0.0

    /// Set of excluded region indices (1-based, matching the display numbers)
    @Published var excludedRegions: Set<Int> = []

    /// Compute all crop regions based on current dividers (excluding header/footer)
    var cropRegions: [CropRegion] {
        // Filter dividers to only include those within the crop area
        let effectiveVertical = verticalDividers.filter { $0 > leftExclusion && $0 < (1.0 - rightExclusion) }
        let effectiveHorizontal = horizontalDividers.filter { $0 > headerExclusion && $0 < (1.0 - footerExclusion) }

        // Add boundaries (respecting exclusions)
        let xPositions = ([leftExclusion] + effectiveVertical.sorted() + [1.0 - rightExclusion])
        let yPositions = ([headerExclusion] + effectiveHorizontal.sorted() + [1.0 - footerExclusion])

        var regions: [CropRegion] = []

        for row in 0..<(yPositions.count - 1) {
            for col in 0..<(xPositions.count - 1) {
                let x = xPositions[col]
                let y = yPositions[row]
                let width = xPositions[col + 1] - x
                let height = yPositions[row + 1] - y

                // Skip regions that are too small
                guard width > 0.001 && height > 0.001 else { continue }

                let region = CropRegion(
                    row: row,
                    column: col,
                    normalizedRect: CGRect(x: x, y: y, width: width, height: height)
                )
                regions.append(region)
            }
        }

        return regions
    }

    /// Number of columns (vertical dividers + 1, within crop area)
    var columnCount: Int {
        let effectiveVertical = verticalDividers.filter { $0 > leftExclusion && $0 < (1.0 - rightExclusion) }
        return effectiveVertical.count + 1
    }

    /// Number of rows (horizontal dividers + 1, within crop area)
    var rowCount: Int {
        let effectiveHorizontal = horizontalDividers.filter { $0 > headerExclusion && $0 < (1.0 - footerExclusion) }
        return effectiveHorizontal.count + 1
    }

    /// Total number of regions
    var regionCount: Int {
        cropRegions.count
    }

    /// Number of exportable regions (excluding excluded ones)
    var exportableRegionCount: Int {
        exportableRegions.count
    }

    /// Number of excluded regions
    var excludedRegionCount: Int {
        excludedRegions.count
    }

    /// Add a vertical divider at the specified position
    func addVerticalDivider(at position: CGFloat = 0.5) {
        let clampedPosition = min(max(position, 0.01), 0.99)
        verticalDividers.append(clampedPosition)
        verticalDividers.sort()
    }

    /// Add a horizontal divider at the specified position
    func addHorizontalDivider(at position: CGFloat = 0.5) {
        let clampedPosition = min(max(position, 0.01), 0.99)
        horizontalDividers.append(clampedPosition)
        horizontalDividers.sort()
    }

    /// Remove a vertical divider at the specified index
    func removeVerticalDivider(at index: Int) {
        guard index >= 0 && index < verticalDividers.count else { return }
        verticalDividers.remove(at: index)
    }

    /// Remove a horizontal divider at the specified index
    func removeHorizontalDivider(at index: Int) {
        guard index >= 0 && index < horizontalDividers.count else { return }
        horizontalDividers.remove(at: index)
    }

    /// Move a vertical divider to a new position
    func moveVerticalDivider(at index: Int, to position: CGFloat) {
        guard index >= 0 && index < verticalDividers.count else { return }
        let clampedPosition = min(max(position, 0.01), 0.99)
        verticalDividers[index] = clampedPosition
    }

    /// Move a horizontal divider to a new position
    func moveHorizontalDivider(at index: Int, to position: CGFloat) {
        guard index >= 0 && index < horizontalDividers.count else { return }
        let clampedPosition = min(max(position, 0.01), 0.99)
        horizontalDividers[index] = clampedPosition
    }

    /// Move all vertical dividers by a delta amount
    func moveAllVerticalDividers(by delta: CGFloat) {
        for i in 0..<verticalDividers.count {
            let newPosition = verticalDividers[i] + delta
            verticalDividers[i] = min(max(newPosition, 0.01), 0.99)
        }
    }

    /// Move all horizontal dividers by a delta amount
    func moveAllHorizontalDividers(by delta: CGFloat) {
        for i in 0..<horizontalDividers.count {
            let newPosition = horizontalDividers[i] + delta
            horizontalDividers[i] = min(max(newPosition, 0.01), 0.99)
        }
    }

    /// Toggle exclusion for a region
    func toggleExclusion(for regionNumber: Int) {
        if excludedRegions.contains(regionNumber) {
            excludedRegions.remove(regionNumber)
        } else {
            excludedRegions.insert(regionNumber)
        }
    }

    /// Check if a region is excluded
    func isExcluded(_ regionNumber: Int) -> Bool {
        excludedRegions.contains(regionNumber)
    }

    /// Get crop regions excluding the ones marked as excluded
    var exportableRegions: [CropRegion] {
        cropRegions.enumerated().compactMap { index, region in
            excludedRegions.contains(index + 1) ? nil : region
        }
    }

    /// Reset to default state
    func reset() {
        verticalDividers = []
        horizontalDividers = []
        excludedRegions = []
    }

    /// Clear only excluded regions (useful when grid changes)
    func clearExcludedRegions() {
        excludedRegions = []
    }

    /// Reset exclusions
    func resetExclusions() {
        headerExclusion = 0.0
        footerExclusion = 0.0
        leftExclusion = 0.0
        rightExclusion = 0.0
    }

    /// Create evenly spaced vertical dividers
    func createEvenVerticalDividers(count: Int) {
        verticalDividers = (1...count).map { CGFloat($0) / CGFloat(count + 1) }
    }

    /// Create evenly spaced horizontal dividers
    func createEvenHorizontalDividers(count: Int) {
        horizontalDividers = (1...count).map { CGFloat($0) / CGFloat(count + 1) }
    }
}
