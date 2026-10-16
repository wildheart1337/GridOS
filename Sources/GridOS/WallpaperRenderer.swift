import AppKit
import CoreImage

/// Renders the current desktop picture of a display, optionally blurred, for the launcher's
/// backdrop. Results are cached until the picture, display size, or blur setting changes.
@MainActor
enum WallpaperRenderer {
    private static let context = CIContext(options: [.cacheIntermediates: false])
    private static var cache: [String: NSImage] = [:]

    static func image(for screen: NSScreen, blurred: Bool) -> NSImage? {
        guard let url = NSWorkspace.shared.desktopImageURL(for: screen) else { return nil }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            return nil
        }

        let size = screen.frame.size
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate?.timeIntervalSince1970 ?? 0
        let key = "\(url.path)|\(modified)|\(Int(size.width))x\(Int(size.height))|\(blurred)"
        if let cached = cache[key] { return cached }

        guard let source = CIImage(contentsOf: url),
              source.extent.width > 0, source.extent.height > 0 else {
            return nil
        }

        // Render at a reduced resolution: the result is blurred or shown behind the grid, and a
        // smaller image keeps the first presentation fast.
        let renderScale: CGFloat = blurred ? 0.5 : 1
        let target = CGSize(width: size.width * renderScale, height: size.height * renderScale)
        let fill = max(target.width / source.extent.width, target.height / source.extent.height)
        let scaled = source
            .transformed(by: CGAffineTransform(translationX: -source.extent.minX, y: -source.extent.minY))
            .transformed(by: CGAffineTransform(scaleX: fill, y: fill))
        let crop = CGRect(
            x: (scaled.extent.width - target.width) / 2,
            y: (scaled.extent.height - target.height) / 2,
            width: target.width,
            height: target.height
        )

        var output = scaled.cropped(to: crop)
        if blurred {
            output = output
                .clampedToExtent()
                .applyingGaussianBlur(sigma: 30)
                .cropped(to: crop)
        }

        guard let cgImage = context.createCGImage(output, from: crop) else { return nil }
        let image = NSImage(cgImage: cgImage, size: size)
        if cache.count > 4 {
            cache.removeAll()
        }
        cache[key] = image
        return image
    }
}
