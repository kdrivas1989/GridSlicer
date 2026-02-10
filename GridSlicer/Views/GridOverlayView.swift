import SwiftUI

/// Overlay view that displays and manages the grid dividers
struct GridOverlayView: View {
    @ObservedObject var gridState: GridState
    let containerSize: CGSize
    let optionKeyPressed: Bool

    @State private var dragStartPositions: [CGFloat] = []

    var body: some View {
        ZStack {
            // Exclusion zones (header/footer/margins)
            if gridState.headerExclusion > 0 {
                ExclusionBorder(
                    type: .header,
                    position: gridState.headerExclusion,
                    containerSize: containerSize,
                    onDrag: { gridState.headerExclusion = $0 }
                )
            }

            if gridState.footerExclusion > 0 {
                ExclusionBorder(
                    type: .footer,
                    position: gridState.footerExclusion,
                    containerSize: containerSize,
                    onDrag: { gridState.footerExclusion = $0 }
                )
            }

            if gridState.leftExclusion > 0 {
                ExclusionBorder(
                    type: .left,
                    position: gridState.leftExclusion,
                    containerSize: containerSize,
                    onDrag: { gridState.leftExclusion = $0 }
                )
            }

            if gridState.rightExclusion > 0 {
                ExclusionBorder(
                    type: .right,
                    position: gridState.rightExclusion,
                    containerSize: containerSize,
                    onDrag: { gridState.rightExclusion = $0 }
                )
            }

            // Region labels with exclusion toggle
            ForEach(Array(gridState.cropRegions.enumerated()), id: \.element.id) { index, region in
                RegionLabel(
                    number: index + 1,
                    isExcluded: gridState.isExcluded(index + 1),
                    onToggleExclusion: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            gridState.toggleExclusion(for: index + 1)
                        }
                    }
                )
                .position(
                    x: (region.normalizedRect.midX) * containerSize.width,
                    y: (region.normalizedRect.midY) * containerSize.height
                )
            }

            // Vertical dividers
            ForEach(Array(gridState.verticalDividers.enumerated()), id: \.offset) { index, position in
                DividerLine(
                    isVertical: true,
                    position: position,
                    containerSize: containerSize,
                    onDrag: { newPosition in
                        handleVerticalDrag(index: index, newPosition: newPosition)
                    },
                    onDragEnd: {
                        dragStartPositions = []
                    },
                    onDelete: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            gridState.removeVerticalDivider(at: index)
                        }
                    }
                )
            }

            // Horizontal dividers
            ForEach(Array(gridState.horizontalDividers.enumerated()), id: \.offset) { index, position in
                DividerLine(
                    isVertical: false,
                    position: position,
                    containerSize: containerSize,
                    onDrag: { newPosition in
                        handleHorizontalDrag(index: index, newPosition: newPosition)
                    },
                    onDragEnd: {
                        dragStartPositions = []
                    },
                    onDelete: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            gridState.removeHorizontalDivider(at: index)
                        }
                    }
                )
            }
        }
        .frame(width: containerSize.width, height: containerSize.height)
    }

    private func handleVerticalDrag(index: Int, newPosition: CGFloat) {
        if optionKeyPressed {
            // Move all vertical dividers together
            if dragStartPositions.isEmpty {
                dragStartPositions = gridState.verticalDividers
            }
            let delta = newPosition - dragStartPositions[index]
            for i in 0..<gridState.verticalDividers.count {
                let targetPosition = dragStartPositions[i] + delta
                gridState.verticalDividers[i] = min(max(targetPosition, 0.01), 0.99)
            }
        } else {
            // Move single divider
            gridState.moveVerticalDivider(at: index, to: newPosition)
        }
    }

    private func handleHorizontalDrag(index: Int, newPosition: CGFloat) {
        if optionKeyPressed {
            // Move all horizontal dividers together
            if dragStartPositions.isEmpty {
                dragStartPositions = gridState.horizontalDividers
            }
            let delta = newPosition - dragStartPositions[index]
            for i in 0..<gridState.horizontalDividers.count {
                let targetPosition = dragStartPositions[i] + delta
                gridState.horizontalDividers[i] = min(max(targetPosition, 0.01), 0.99)
            }
        } else {
            // Move single divider
            gridState.moveHorizontalDivider(at: index, to: newPosition)
        }
    }
}

/// Label showing region number with exclusion toggle
struct RegionLabel: View {
    let number: Int
    let isExcluded: Bool
    let onToggleExclusion: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 4) {
            Text("\(number)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(isExcluded ? .gray : .white)
                .strikethrough(isExcluded, color: .red)

            // X button to toggle exclusion
            if isHovered || isExcluded {
                Button(action: onToggleExclusion) {
                    Image(systemName: isExcluded ? "plus.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(isExcluded ? .green : .red)
                }
                .buttonStyle(.plain)
                .help(isExcluded ? "Include this region" : "Exclude this region")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(isExcluded ? Color.gray.opacity(0.4) : Color.black.opacity(0.6))
        )
        .overlay(
            Capsule()
                .stroke(isExcluded ? Color.red.opacity(0.6) : Color.clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @StateObject private var gridState = GridState()

        var body: some View {
            ZStack {
                Color.blue.opacity(0.3)
                GridOverlayView(
                    gridState: gridState,
                    containerSize: CGSize(width: 600, height: 400),
                    optionKeyPressed: false
                )
            }
            .frame(width: 600, height: 400)
            .onAppear {
                gridState.verticalDividers = [0.33, 0.66]
                gridState.horizontalDividers = [0.5]
                gridState.headerExclusion = 0.1
            }
        }
    }
    return PreviewWrapper()
}
