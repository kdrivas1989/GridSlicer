import SwiftUI

/// A draggable handle for grid dividers
struct DividerHandle: View {
    let isHovered: Bool
    let size: CGFloat

    init(isHovered: Bool, size: CGFloat = 12) {
        self.isHovered = isHovered
        self.size = size
    }

    var body: some View {
        Circle()
            .fill(isHovered ? Color.accentColor : Color.white)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(Color.accentColor, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
    }
}

/// Delete button for dividers
struct DeleteButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(isHovered ? .red : .gray)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .help("Delete this divider")
    }
}

/// A draggable divider line (vertical or horizontal) with multiple handles
struct DividerLine: View {
    let isVertical: Bool
    let position: CGFloat
    let containerSize: CGSize
    let onDrag: (CGFloat) -> Void
    let onDragEnd: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false
    @State private var isDragging = false
    @GestureState private var dragOffset: CGFloat = 0

    private let lineWidth: CGFloat = 3
    private let hitAreaWidth: CGFloat = 24

    var body: some View {
        let linePosition = isVertical
            ? CGPoint(x: position * containerSize.width, y: containerSize.height / 2)
            : CGPoint(x: containerSize.width / 2, y: position * containerSize.height)

        ZStack {
            // Visible line
            Rectangle()
                .fill(isHovered || isDragging ? Color.accentColor : Color.yellow)
                .frame(
                    width: isVertical ? lineWidth : containerSize.width,
                    height: isVertical ? containerSize.height : lineWidth
                )
                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 0)
                .position(linePosition)

            // Multiple handles along the line
            ForEach(handlePositions, id: \.self) { handlePos in
                DividerHandle(isHovered: isHovered || isDragging, size: handlePos == 0.5 ? 14 : 10)
                    .position(
                        x: isVertical ? position * containerSize.width : handlePos * containerSize.width,
                        y: isVertical ? handlePos * containerSize.height : position * containerSize.height
                    )
                    .allowsHitTesting(false)
            }

            // Delete button at one end
            DeleteButton(action: onDelete)
                .position(
                    x: isVertical ? position * containerSize.width + 20 : containerSize.width - 20,
                    y: isVertical ? 20 : position * containerSize.height - 20
                )
                .opacity(isHovered || isDragging ? 1 : 0)

            // Invisible hit area for dragging - only around the line
            Rectangle()
                .fill(Color.white.opacity(0.001))
                .frame(
                    width: isVertical ? hitAreaWidth : containerSize.width,
                    height: isVertical ? containerSize.height : hitAreaWidth
                )
                .position(linePosition)
                .onHover { hovering in
                    isHovered = hovering
                    if hovering {
                        if isVertical {
                            NSCursor.resizeLeftRight.push()
                        } else {
                            NSCursor.resizeUpDown.push()
                        }
                    } else if !isDragging {
                        NSCursor.pop()
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            isDragging = true
                            let newPosition: CGFloat
                            if isVertical {
                                newPosition = value.location.x / containerSize.width
                            } else {
                                newPosition = value.location.y / containerSize.height
                            }
                            onDrag(newPosition)
                        }
                        .onEnded { _ in
                            isDragging = false
                            NSCursor.pop()
                            onDragEnd()
                        }
                )
        }
        .frame(width: containerSize.width, height: containerSize.height)
    }

    /// Positions for handles along the line (normalized 0-1)
    private var handlePositions: [CGFloat] {
        [0.15, 0.35, 0.5, 0.65, 0.85]
    }
}

/// Exclusion zone border (for header/footer/margins)
struct ExclusionBorder: View {
    enum BorderType {
        case header, footer, left, right
    }

    let type: BorderType
    let position: CGFloat
    let containerSize: CGSize
    let onDrag: (CGFloat) -> Void

    @State private var isHovered = false
    @State private var isDragging = false

    private let lineWidth: CGFloat = 4

    var body: some View {
        ZStack {
            // Shaded exclusion area
            exclusionArea

            // Border line
            Rectangle()
                .fill(isHovered || isDragging ? Color.red : Color.red.opacity(0.7))
                .frame(
                    width: isHorizontal ? containerSize.width : lineWidth,
                    height: isHorizontal ? lineWidth : containerSize.height
                )
                .position(linePosition)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 0)

            // Handle
            DividerHandle(isHovered: isHovered || isDragging, size: 14)
                .position(handlePosition)
                .allowsHitTesting(false)

            // Hit area
            Rectangle()
                .fill(Color.white.opacity(0.001))
                .frame(
                    width: isHorizontal ? containerSize.width : 20,
                    height: isHorizontal ? 20 : containerSize.height
                )
                .position(linePosition)
                .onHover { hovering in
                    isHovered = hovering
                    if hovering {
                        NSCursor.resizeUpDown.push()
                    } else if !isDragging {
                        NSCursor.pop()
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            isDragging = true
                            let newPosition: CGFloat
                            if isHorizontal {
                                newPosition = value.location.y / containerSize.height
                            } else {
                                newPosition = value.location.x / containerSize.width
                            }
                            // Adjust based on border type
                            switch type {
                            case .header, .left:
                                onDrag(max(0, min(0.4, newPosition)))
                            case .footer:
                                onDrag(max(0, min(0.4, 1.0 - newPosition)))
                            case .right:
                                onDrag(max(0, min(0.4, 1.0 - newPosition)))
                            }
                        }
                        .onEnded { _ in
                            isDragging = false
                            NSCursor.pop()
                        }
                )
        }
        .frame(width: containerSize.width, height: containerSize.height)
    }

    private var isHorizontal: Bool {
        type == .header || type == .footer
    }

    private var exclusionArea: some View {
        let rect: CGRect
        switch type {
        case .header:
            rect = CGRect(x: 0, y: 0, width: containerSize.width, height: position * containerSize.height)
        case .footer:
            rect = CGRect(x: 0, y: (1 - position) * containerSize.height, width: containerSize.width, height: position * containerSize.height)
        case .left:
            rect = CGRect(x: 0, y: 0, width: position * containerSize.width, height: containerSize.height)
        case .right:
            rect = CGRect(x: (1 - position) * containerSize.width, y: 0, width: position * containerSize.width, height: containerSize.height)
        }

        return Rectangle()
            .fill(Color.red.opacity(0.15))
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }

    private var linePosition: CGPoint {
        switch type {
        case .header:
            return CGPoint(x: containerSize.width / 2, y: position * containerSize.height)
        case .footer:
            return CGPoint(x: containerSize.width / 2, y: (1 - position) * containerSize.height)
        case .left:
            return CGPoint(x: position * containerSize.width, y: containerSize.height / 2)
        case .right:
            return CGPoint(x: (1 - position) * containerSize.width, y: containerSize.height / 2)
        }
    }

    private var handlePosition: CGPoint {
        linePosition
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
        DividerLine(
            isVertical: true,
            position: 0.5,
            containerSize: CGSize(width: 400, height: 300),
            onDrag: { _ in },
            onDragEnd: { },
            onDelete: { }
        )
    }
    .frame(width: 400, height: 300)
}
