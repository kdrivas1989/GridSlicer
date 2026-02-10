import SwiftUI

#if os(macOS)
import AppKit
public typealias PlatformImage = NSImage
public typealias PlatformColor = NSColor

extension PlatformColor {
    static var systemGray6: NSColor { .controlBackgroundColor }
}
#else
import UIKit
public typealias PlatformImage = UIImage
public typealias PlatformColor = UIColor
#endif

// Cross-platform image extensions
extension PlatformImage {
    #if os(macOS)
    var cgImageRepresentation: CGImage? {
        cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    convenience init?(cgImageSource: CGImage) {
        self.init(cgImage: cgImageSource, size: NSSize(width: cgImageSource.width, height: cgImageSource.height))
    }
    #else
    var cgImageRepresentation: CGImage? {
        cgImage
    }

    var size: CGSize {
        return CGSize(width: self.size.width, height: self.size.height)
    }

    convenience init?(cgImageSource: CGImage) {
        self.init(cgImage: cgImageSource)
    }
    #endif
}

// SwiftUI Image extension for cross-platform
extension Image {
    init(platformImage: PlatformImage) {
        #if os(macOS)
        self.init(nsImage: platformImage)
        #else
        self.init(uiImage: platformImage)
        #endif
    }
}
