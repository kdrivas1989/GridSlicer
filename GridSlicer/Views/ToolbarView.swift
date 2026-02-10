import SwiftUI

/// Toolbar with controls for the GridSlicer app
struct ToolbarView: View {
    @ObservedObject var viewModel: GridSlicerViewModel
    @State private var showExclusionPopover = false
    @State private var showAutoDetectPopover = false
    @State private var detectColumns: Int = 4
    @State private var detectRows: Int = 4

    var body: some View {
        HStack(spacing: 12) {
            // Open Image button
            Button(action: viewModel.openImagePicker) {
                Label("Open", systemImage: "photo")
            }
            .help("Open an image or PDF file")

            Divider()
                .frame(height: 20)

            // Add Horizontal Line button
            Button(action: viewModel.addHorizontalDivider) {
                Label("H Line", systemImage: "minus")
            }
            .disabled(viewModel.image == nil)
            .help("Add a horizontal divider")

            // Add Vertical Line button
            Button(action: viewModel.addVerticalDivider) {
                Label("V Line", systemImage: "line.vertical")
            }
            .disabled(viewModel.image == nil)
            .help("Add a vertical divider")

            // Auto-detect borders button with settings
            Button(action: { showAutoDetectPopover.toggle() }) {
                Label("Auto Detect", systemImage: "wand.and.stars")
            }
            .disabled(viewModel.image == nil)
            .help("Automatically detect borders in the image")
            .popover(isPresented: $showAutoDetectPopover, arrowEdge: .bottom) {
                AutoDetectSettingsView(
                    columns: $detectColumns,
                    rows: $detectRows,
                    onDetect: {
                        viewModel.autoDetectBorders(columns: detectColumns, rows: detectRows)
                        showAutoDetectPopover = false
                    }
                )
            }

            // Margins/Exclusion button
            Button(action: { showExclusionPopover.toggle() }) {
                Label("Margins", systemImage: "rectangle.dashed")
            }
            .disabled(viewModel.image == nil)
            .help("Set header/footer/margin exclusion zones")
            .popover(isPresented: $showExclusionPopover, arrowEdge: .bottom) {
                ExclusionSettingsView(gridState: viewModel.gridState)
            }

            // Clear button
            Button(action: viewModel.clearDividers) {
                Label("Clear", systemImage: "xmark.circle")
            }
            .disabled(viewModel.image == nil || (viewModel.gridState.verticalDividers.isEmpty && viewModel.gridState.horizontalDividers.isEmpty))
            .help("Remove all dividers")

            // PDF page navigation (only shown for PDFs)
            if viewModel.isPDF {
                Divider()
                    .frame(height: 20)

                Button(action: viewModel.previousPage) {
                    Image(systemName: "chevron.left")
                }
                .disabled(!viewModel.canGoPreviousPage)
                .help("Previous page")

                Text("Page \(viewModel.currentPageIndex + 1)/\(viewModel.totalPages)")
                    .font(.caption)
                    .monospacedDigit()
                    .frame(minWidth: 70)

                Button(action: viewModel.nextPage) {
                    Image(systemName: "chevron.right")
                }
                .disabled(!viewModel.canGoNextPage)
                .help("Next page")

                Divider()
                    .frame(height: 20)

                // Copy settings to all pages button
                Button(action: viewModel.copySettingsToAllPages) {
                    Label("Copy to All", systemImage: "doc.on.doc.fill")
                }
                .disabled(viewModel.gridState.verticalDividers.isEmpty && viewModel.gridState.horizontalDividers.isEmpty)
                .help("Copy current page's grid and margins to all pages")

                // Export all pages button
                Button(action: viewModel.exportAllPages) {
                    Label("Export All", systemImage: "square.and.arrow.up.on.square")
                }
                .disabled(viewModel.isExporting)
                .help("Export all PDF pages")
            }

            Divider()
                .frame(height: 20)

            // Output folder button
            Button(action: viewModel.selectOutputFolder) {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                    if let url = viewModel.outputFolderURL {
                        Text(url.lastPathComponent)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: 100)
                    } else {
                        Text("Output...")
                    }
                }
            }
            .help("Select output folder for exported images")

            Spacer()

            // Export button
            Button(action: viewModel.exportRegions) {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .disabled(viewModel.image == nil || viewModel.isExporting)
            .help("Export all regions as separate images")

            if viewModel.isExporting {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 20)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

/// Popover view for exclusion zone settings
struct ExclusionSettingsView: View {
    @ObservedObject var gridState: GridState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Exclusion Zones")
                .font(.headline)

            Text("Areas to exclude from cropping")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                ExclusionSlider(label: "Header (Top)", value: $gridState.headerExclusion, icon: "arrow.up.to.line")
                ExclusionSlider(label: "Footer (Bottom)", value: $gridState.footerExclusion, icon: "arrow.down.to.line")
                ExclusionSlider(label: "Left Margin", value: $gridState.leftExclusion, icon: "arrow.left.to.line")
                ExclusionSlider(label: "Right Margin", value: $gridState.rightExclusion, icon: "arrow.right.to.line")
            }

            Divider()

            HStack {
                Button("Reset All") {
                    gridState.resetExclusions()
                }
                .buttonStyle(.bordered)

                Spacer()

                Text("\(Int(gridState.headerExclusion * 100 + gridState.footerExclusion * 100 + gridState.leftExclusion * 100 + gridState.rightExclusion * 100))% excluded")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

struct ExclusionSlider: View {
    let label: String
    @Binding var value: CGFloat
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundColor(.secondary)

            Text(label)
                .frame(width: 100, alignment: .leading)

            Slider(value: $value, in: 0...0.4)
                .frame(width: 100)

            Text("\(Int(value * 100))%")
                .font(.caption)
                .monospacedDigit()
                .frame(width: 35, alignment: .trailing)
        }
    }
}

/// Settings popover for auto-detect
struct AutoDetectSettingsView: View {
    @Binding var columns: Int
    @Binding var rows: Int
    let onDetect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Auto Detect Grid")
                .font(.headline)

            Text("Specify expected grid size to improve detection")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            HStack {
                Text("Columns:")
                    .frame(width: 70, alignment: .leading)
                Stepper("\(columns)", value: $columns, in: 2...20)
                    .frame(width: 100)
            }

            HStack {
                Text("Rows:")
                    .frame(width: 70, alignment: .leading)
                Stepper("\(rows)", value: $rows, in: 2...20)
                    .frame(width: 100)
            }

            Divider()

            HStack {
                Text("Will detect up to \(columns - 1) vertical and \(rows - 1) horizontal lines")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Detect") {
                    onDetect()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 280)
    }
}

#Preview {
    ToolbarView(viewModel: GridSlicerViewModel())
        .frame(width: 800)
}
