import Foundation
import UIKit
import ImageIO

enum RecipeImageLoader {
    static func loadImage(named name: String, targetPixelSize: CGSize? = nil) -> UIImage? {
        if let docImage = loadFromDocuments(named: name, targetPixelSize: targetPixelSize) {
            return docImage
        }
        if let asset = UIImage(named: name) {
            return asset
        }
        if let stripped = stripExtension(from: name), stripped != name {
            return UIImage(named: stripped)
        }
        return nil
    }

    private static func loadFromDocuments(named name: String, targetPixelSize: CGSize?) -> UIImage? {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        guard let dirPath = urls.first else { return nil }

        for filename in candidateFilenames(for: name) {
            let imageURL = dirPath.appendingPathComponent(filename)
            guard FileManager.default.fileExists(atPath: imageURL.path) else { continue }

            if let target = targetPixelSize {
                if let downsampled = downsample(imageAt: imageURL, to: target, scale: 2.0) {
                    return downsampled
                }
            }

            if let image = UIImage(contentsOfFile: imageURL.path) {
                return image
            }
        }

        return nil
    }

    private static func candidateFilenames(for name: String) -> [String] {
        let sanitizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitizedName.contains(".") {
            return [sanitizedName]
        }
        return [
            "\(sanitizedName).jpg",
            "\(sanitizedName).jpeg",
            "\(sanitizedName).png",
            "\(sanitizedName).heic"
        ]
    }

    private static func stripExtension(from name: String) -> String? {
        let url = URL(fileURLWithPath: name)
        return url.pathExtension.isEmpty ? nil : url.deletingPathExtension().lastPathComponent
    }

    private static func downsample(imageAt url: URL, to pointSize: CGSize, scale: CGFloat) -> UIImage? {
        let maxDimension = max(pointSize.width, pointSize.height) * scale
        guard maxDimension > 0 else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxDimension)
        ]

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }

        return UIImage(cgImage: cgImage)
    }
}
