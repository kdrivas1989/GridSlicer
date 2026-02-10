import SwiftUI
import AppKit
import PDFKit
import UniformTypeIdentifiers

/// Main view model for the GridSlicer app
class GridSlicerViewModel: ObservableObject {
    @Published var image: NSImage?
    @Published var imageName: String = ""
    @Published var gridState = GridState()
    @Published var outputFolderURL: URL?
    @Published var statusMessage: String = "Load an image to get started"
    @Published var isExporting: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    @Published var showExportPreview: Bool = false

    // PDF support
    @Published var currentPDFDocument: PDFDocument?
    @Published var currentPageIndex: Int = 0
    @Published var totalPages: Int = 0

    // Per-page grid states for PDFs
    private var pageGridStates: [Int: GridStateData] = [:]

    /// Data structure to store grid state for a page
    struct GridStateData {
        var verticalDividers: [CGFloat]
        var horizontalDividers: [CGFloat]
        var headerExclusion: CGFloat
        var footerExclusion: CGFloat
        var leftExclusion: CGFloat
        var rightExclusion: CGFloat
        var excludedRegions: Set<Int>

        init(from gridState: GridState) {
            self.verticalDividers = gridState.verticalDividers
            self.horizontalDividers = gridState.horizontalDividers
            self.headerExclusion = gridState.headerExclusion
            self.footerExclusion = gridState.footerExclusion
            self.leftExclusion = gridState.leftExclusion
            self.rightExclusion = gridState.rightExclusion
            self.excludedRegions = gridState.excludedRegions
        }

        func apply(to gridState: GridState) {
            gridState.verticalDividers = verticalDividers
            gridState.horizontalDividers = horizontalDividers
            gridState.headerExclusion = headerExclusion
            gridState.footerExclusion = footerExclusion
            gridState.leftExclusion = leftExclusion
            gridState.rightExclusion = rightExclusion
            gridState.excludedRegions = excludedRegions
        }
    }

    /// Load an image from a URL
    func loadImage(from url: URL) {
        let fileExtension = url.pathExtension.lowercased()

        // Check if it's a PDF
        if fileExtension == "pdf" {
            loadPDF(from: url)
            return
        }

        guard let loadedImage = NSImage(contentsOf: url) else {
            showError(message: "Failed to load image from: \(url.lastPathComponent)")
            return
        }

        currentPDFDocument = nil
        totalPages = 0
        currentPageIndex = 0
        image = loadedImage
        imageName = url.deletingPathExtension().lastPathComponent
        gridState.reset()
        updateStatus()
    }

    /// Load a PDF from a URL
    func loadPDF(from url: URL) {
        guard let pdfDocument = PDFDocument(url: url) else {
            showError(message: "Failed to load PDF from: \(url.lastPathComponent)")
            return
        }

        currentPDFDocument = pdfDocument
        totalPages = pdfDocument.pageCount
        currentPageIndex = 0
        imageName = url.deletingPathExtension().lastPathComponent

        // Clear all page states for new PDF
        pageGridStates.removeAll()

        renderCurrentPDFPage()
        gridState.reset()
        gridState.resetExclusions()
        updateStatus()
    }

    /// Save current page's grid state
    private func saveCurrentPageState() {
        guard isPDF else { return }
        pageGridStates[currentPageIndex] = GridStateData(from: gridState)
    }

    /// Load grid state for current page (or inherit from page 1 if none exists)
    private func loadCurrentPageState() {
        guard isPDF else { return }
        if let savedState = pageGridStates[currentPageIndex] {
            savedState.apply(to: gridState)
        } else if currentPageIndex > 0, let page1State = pageGridStates[0] {
            // Inherit from page 1's settings
            page1State.apply(to: gridState)
            // Clear excluded regions for new page (user may want different exclusions)
            gridState.excludedRegions = []
        } else if currentPageIndex > 0 {
            // Page 1 hasn't been saved yet, but copy current gridState settings
            // (which would be page 1's current state since we came from there)
            // Just clear excluded regions for new page
            gridState.excludedRegions = []
        } else {
            // Page 1 with no saved state - reset
            gridState.reset()
            gridState.resetExclusions()
        }
    }

    /// Copy current page's grid settings to all other pages
    func copySettingsToAllPages() {
        guard isPDF else { return }
        saveCurrentPageState()
        let currentState = GridStateData(from: gridState)

        for pageIndex in 0..<totalPages {
            pageGridStates[pageIndex] = currentState
        }

        statusMessage = "Copied settings to all \(totalPages) pages"
    }

    /// Check if a specific page has custom settings
    func pageHasSettings(_ pageIndex: Int) -> Bool {
        return pageGridStates[pageIndex] != nil
    }

    /// Get count of pages with settings configured
    var pagesWithSettingsCount: Int {
        // Include current page if it has any dividers
        var count = pageGridStates.count
        if !pageGridStates.keys.contains(currentPageIndex) &&
           (!gridState.verticalDividers.isEmpty || !gridState.horizontalDividers.isEmpty) {
            count += 1
        }
        return count
    }

    /// Render the current PDF page to an NSImage
    func renderCurrentPDFPage() {
        guard let pdfDocument = currentPDFDocument,
              let page = pdfDocument.page(at: currentPageIndex) else {
            return
        }

        let pageRect = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0 // Render at 2x for better quality
        let scaledSize = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)

        let image = NSImage(size: scaledSize)
        image.lockFocus()

        if let context = NSGraphicsContext.current?.cgContext {
            // Fill with white background
            context.setFillColor(NSColor.white.cgColor)
            context.fill(CGRect(origin: .zero, size: scaledSize))

            // Scale and draw the PDF page
            context.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: context)
        }

        image.unlockFocus()
        self.image = image
    }

    /// Go to next PDF page
    func nextPage() {
        guard currentPDFDocument != nil, currentPageIndex < totalPages - 1 else { return }
        saveCurrentPageState()
        currentPageIndex += 1
        renderCurrentPDFPage()
        loadCurrentPageState()
        updateStatus()
    }

    /// Go to previous PDF page
    func previousPage() {
        guard currentPDFDocument != nil, currentPageIndex > 0 else { return }
        saveCurrentPageState()
        currentPageIndex -= 1
        renderCurrentPDFPage()
        loadCurrentPageState()
        updateStatus()
    }

    /// Check if we have a multi-page PDF loaded
    var isPDF: Bool {
        currentPDFDocument != nil
    }

    /// Check if we can go to next page
    var canGoNextPage: Bool {
        currentPDFDocument != nil && currentPageIndex < totalPages - 1
    }

    /// Check if we can go to previous page
    var canGoPreviousPage: Bool {
        currentPDFDocument != nil && currentPageIndex > 0
    }

    /// Load an image from NSImage (for drag and drop)
    func loadImage(_ nsImage: NSImage, name: String) {
        image = nsImage
        imageName = name
        gridState.reset()
        updateStatus()
    }

    /// Open file picker to load an image or PDF
    func openImagePicker() {
        let panel = NSOpenPanel()
        // Allow all files - we'll check the type when loading
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Select an image or PDF to slice"
        panel.title = "Open Image or PDF"
        panel.treatsFilePackagesAsDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            let ext = url.pathExtension.lowercased()
            let validExtensions = ["pdf", "png", "jpg", "jpeg", "tiff", "tif", "bmp", "gif", "heic", "webp"]

            if validExtensions.contains(ext) || NSImage(contentsOf: url) != nil {
                loadImage(from: url)
            } else {
                showError(message: "Please select an image or PDF file")
            }
        }
    }

    /// Select output folder for export
    func selectOutputFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.message = "Select output folder for exported images"

        if panel.runModal() == .OK, let url = panel.url {
            outputFolderURL = url
            updateStatus()
        }
    }

    /// Export all regions - shows preview dialog for renaming
    func exportRegions() {
        guard image != nil else {
            showError(message: "No image loaded")
            return
        }

        guard outputFolderURL != nil else {
            // Prompt for folder selection first
            selectOutputFolder()
            guard outputFolderURL != nil else { return }
            exportRegions()
            return
        }

        // Show the export preview dialog
        showExportPreview = true
    }

    /// Direct export without preview (for "All Pages" export)
    func exportRegionsDirect() {
        guard let image = image else {
            showError(message: "No image loaded")
            return
        }

        guard let folderURL = outputFolderURL else {
            return
        }

        let regions = gridState.exportableRegions

        isExporting = true
        statusMessage = "Exporting..."

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            do {
                let count = try ImageExporter.exportRegions(
                    from: image,
                    regions: regions,
                    to: folderURL,
                    baseName: self.imageName.isEmpty ? "image" : self.imageName
                )

                DispatchQueue.main.async {
                    self.isExporting = false
                    self.statusMessage = "Successfully exported \(count) images"
                }
            } catch {
                DispatchQueue.main.async {
                    self.isExporting = false
                    self.showError(message: error.localizedDescription)
                }
            }
        }
    }

    /// Add a vertical divider
    func addVerticalDivider() {
        // Find a good position for the new divider
        let existingPositions = [0.0] + gridState.verticalDividers.sorted() + [1.0]
        var maxGap: CGFloat = 0
        var bestPosition: CGFloat = 0.5

        for i in 0..<(existingPositions.count - 1) {
            let gap = existingPositions[i + 1] - existingPositions[i]
            if gap > maxGap {
                maxGap = gap
                bestPosition = (existingPositions[i] + existingPositions[i + 1]) / 2
            }
        }

        gridState.addVerticalDivider(at: bestPosition)
        updateStatus()
    }

    /// Add a horizontal divider
    func addHorizontalDivider() {
        // Find a good position for the new divider
        let existingPositions = [0.0] + gridState.horizontalDividers.sorted() + [1.0]
        var maxGap: CGFloat = 0
        var bestPosition: CGFloat = 0.5

        for i in 0..<(existingPositions.count - 1) {
            let gap = existingPositions[i + 1] - existingPositions[i]
            if gap > maxGap {
                maxGap = gap
                bestPosition = (existingPositions[i] + existingPositions[i + 1]) / 2
            }
        }

        gridState.addHorizontalDivider(at: bestPosition)
        updateStatus()
    }

    /// Remove all dividers
    func clearDividers() {
        gridState.reset()
        updateStatus()
    }

    /// Auto-detect borders in the image and create dividers
    /// - Parameters:
    ///   - columns: Expected number of columns in the grid
    ///   - rows: Expected number of rows in the grid
    func autoDetectBorders(columns: Int = 4, rows: Int = 4) {
        guard let image = image else {
            showError(message: "No image loaded")
            return
        }

        statusMessage = "Detecting borders..."

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let (vertical, horizontal) = BorderDetector.detectGridBorders(in: image, columns: columns, rows: rows)

            DispatchQueue.main.async {
                guard let self = self else { return }

                // Set detected dividers
                self.gridState.verticalDividers = vertical
                self.gridState.horizontalDividers = horizontal

                let totalLines = vertical.count + horizontal.count
                if totalLines > 0 {
                    self.statusMessage = "Detected \(vertical.count) vertical and \(horizontal.count) horizontal lines"
                } else {
                    self.statusMessage = "No borders detected. Try adding lines manually."
                }
                self.updateStatus()
            }
        }
    }

    /// Export all PDF pages with their individual grid settings
    func exportAllPages() {
        guard let pdfDocument = currentPDFDocument else {
            showError(message: "No PDF loaded")
            return
        }

        guard let folderURL = outputFolderURL else {
            selectOutputFolder()
            guard outputFolderURL != nil else { return }
            exportAllPages()
            return
        }

        // Save current page state first
        saveCurrentPageState()

        let baseName = imageName.isEmpty ? "pdf" : imageName
        let savedPageStates = pageGridStates
        let currentGridState = GridStateData(from: gridState)

        isExporting = true
        statusMessage = "Exporting all pages..."

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var totalExported = 0
            var failedPages: [Int] = []

            for pageIndex in 0..<pdfDocument.pageCount {
                guard let page = pdfDocument.page(at: pageIndex) else {
                    failedPages.append(pageIndex + 1)
                    continue
                }

                // Get the grid state for this page (or use current if not set)
                let pageState = savedPageStates[pageIndex] ?? currentGridState

                // Create a temporary GridState to compute regions
                let tempGridState = GridState()
                pageState.apply(to: tempGridState)
                let regions = tempGridState.exportableRegions

                // Skip pages with no regions defined
                if regions.isEmpty {
                    continue
                }

                // Render the page
                let pageRect = page.bounds(for: .mediaBox)
                let scale: CGFloat = 2.0
                let scaledSize = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)

                let pageImage = NSImage(size: scaledSize)
                pageImage.lockFocus()

                if let context = NSGraphicsContext.current?.cgContext {
                    context.setFillColor(NSColor.white.cgColor)
                    context.fill(CGRect(origin: .zero, size: scaledSize))
                    context.scaleBy(x: scale, y: scale)
                    page.draw(with: .mediaBox, to: context)
                }

                pageImage.unlockFocus()

                // Export regions for this page
                let pageBaseName = "\(baseName)_page\(pageIndex + 1)"

                do {
                    let count = try ImageExporter.exportRegions(
                        from: pageImage,
                        regions: regions,
                        to: folderURL,
                        baseName: pageBaseName
                    )
                    totalExported += count
                } catch {
                    failedPages.append(pageIndex + 1)
                }

                // Update progress
                DispatchQueue.main.async {
                    self.statusMessage = "Exporting page \(pageIndex + 1)/\(pdfDocument.pageCount)..."
                }
            }

            DispatchQueue.main.async {
                self.isExporting = false
                if failedPages.isEmpty {
                    self.statusMessage = "Exported \(totalExported) images from \(pdfDocument.pageCount) pages"
                } else {
                    self.statusMessage = "Exported \(totalExported) images. Failed pages: \(failedPages.map(String.init).joined(separator: ", "))"
                }
            }
        }
    }

    /// Update status message
    private func updateStatus() {
        if image == nil {
            statusMessage = "Load an image or PDF to get started"
        } else {
            let regionCount = gridState.regionCount
            let folderName = outputFolderURL?.lastPathComponent ?? "Not selected"
            var status = "\(regionCount) region\(regionCount == 1 ? "" : "s")"

            if isPDF {
                status += " | Page \(currentPageIndex + 1)/\(totalPages)"
            }

            status += " | Output: \(folderName)"
            statusMessage = status
        }
    }

    /// Show error message
    private func showError(message: String) {
        errorMessage = message
        showError = true
        statusMessage = "Error: \(message)"
    }
}
