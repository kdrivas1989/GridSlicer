import SwiftUI

/// Main content view for the GridSlicer app
struct ContentView: View {
    @StateObject private var viewModel = GridSlicerViewModel()

    var body: some View {
        VStack(spacing: 0) {
            #if os(macOS)
            // Toolbar (macOS)
            ToolbarView(viewModel: viewModel)

            Divider()
            #endif

            // Main canvas
            ImageCanvasView(viewModel: viewModel)
                .frame(minWidth: 600, minHeight: 400)

            #if os(macOS)
            Divider()

            // Status bar
            StatusBarView(viewModel: viewModel)
            #endif
        }
        #if os(macOS)
        .frame(minWidth: 700, minHeight: 500)
        #endif
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .sheet(isPresented: $viewModel.showExportPreview) {
            if let image = viewModel.image, let folder = viewModel.outputFolderURL {
                ExportPreviewView(
                    viewModel: viewModel,
                    isPresented: $viewModel.showExportPreview,
                    sourceImage: image,
                    regions: viewModel.gridState.exportableRegions,
                    outputFolder: folder
                )
            }
        }
        #if os(macOS)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            // Cleanup if needed
        }
        #endif
    }
}

#if os(macOS)
/// Status bar showing current state
struct StatusBarView: View {
    @ObservedObject var viewModel: GridSlicerViewModel

    var body: some View {
        HStack {
            // Grid info
            if viewModel.image != nil {
                HStack(spacing: 16) {
                    Label("\(viewModel.gridState.rowCount) rows", systemImage: "rectangle.split.1x2")
                    Label("\(viewModel.gridState.columnCount) cols", systemImage: "rectangle.split.2x1")

                    if viewModel.gridState.excludedRegionCount > 0 {
                        Label("\(viewModel.gridState.exportableRegionCount)/\(viewModel.gridState.regionCount) regions", systemImage: "rectangle.split.3x3")
                            .foregroundColor(.orange)
                    } else {
                        Label("\(viewModel.gridState.regionCount) regions", systemImage: "rectangle.split.3x3")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            // Status message
            Text(viewModel.statusMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
#endif

#Preview {
    ContentView()
}
