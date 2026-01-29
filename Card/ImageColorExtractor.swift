//
//  ImageColorExtractor.swift
//  Card
//
//  Extracts dominant colors from images for dynamic gradient backgrounds
//

import UIKit
import SwiftUI

// MARK: - Extracted Colors

/// Colors extracted from an image
struct ImageColors {
    let primary: UIColor      // Most dominant color
    let secondary: UIColor    // Second most dominant
    let background: UIColor   // Background color (often edge color)
    let detail: UIColor       // Accent/detail color

    /// Convert to array for gradient use
    var asArray: [UIColor] {
        [primary, secondary, background, detail]
    }

    /// Default dark colors when extraction fails
    static let defaultDark = ImageColors(
        primary: UIColor(red: 45/255, green: 20/255, blue: 60/255, alpha: 1),
        secondary: UIColor(red: 80/255, green: 40/255, blue: 90/255, alpha: 1),
        background: UIColor(red: 20/255, green: 10/255, blue: 30/255, alpha: 1),
        detail: UIColor(red: 60/255, green: 30/255, blue: 70/255, alpha: 1)
    )
}

// MARK: - Color Extractor

/// Extracts dominant colors from UIImage
class ImageColorExtractor {

    /// Quality level for color extraction (lower = faster but less accurate)
    enum Quality: CGFloat {
        case low = 50      // 50px - fastest
        case medium = 100  // 100px - balanced
        case high = 250    // 250px - most accurate
    }

    /// Extract dominant colors from an image
    /// - Parameters:
    ///   - image: The source image
    ///   - quality: Extraction quality (default: medium)
    /// - Returns: Extracted colors or default if extraction fails
    static func extractColors(from image: UIImage, quality: Quality = .medium) -> ImageColors {
        guard let cgImage = image.cgImage else {
            return .defaultDark
        }

        // Scale image for performance
        let scale = quality.rawValue / max(image.size.width, image.size.height)
        let scaledSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )

        guard scaledSize.width > 0 && scaledSize.height > 0 else {
            return .defaultDark
        }

        // Create bitmap context
        let width = Int(scaledSize.width)
        let height = Int(scaledSize.height)
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bitsPerComponent = 8

        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return .defaultDark
        }

        context.draw(cgImage, in: CGRect(origin: .zero, size: scaledSize))

        // Count color occurrences
        var colorCounts: [UInt32: Int] = [:]

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * bytesPerPixel
                let r = pixelData[offset]
                let g = pixelData[offset + 1]
                let b = pixelData[offset + 2]
                let a = pixelData[offset + 3]

                // Skip transparent pixels
                guard a > 127 else { continue }

                // Quantize colors to reduce unique count (group similar colors)
                let quantizedR = (r / 32) * 32
                let quantizedG = (g / 32) * 32
                let quantizedB = (b / 32) * 32

                let colorKey = UInt32(quantizedR) << 16 | UInt32(quantizedG) << 8 | UInt32(quantizedB)
                colorCounts[colorKey, default: 0] += 1
            }
        }

        // Sort by frequency
        let sortedColors = colorCounts.sorted { $0.value > $1.value }

        // Filter out colors that are too similar or too gray
        var distinctColors: [UIColor] = []
        for (colorKey, _) in sortedColors {
            let r = CGFloat((colorKey >> 16) & 0xFF) / 255.0
            let g = CGFloat((colorKey >> 8) & 0xFF) / 255.0
            let b = CGFloat(colorKey & 0xFF) / 255.0

            let color = UIColor(red: r, green: g, blue: b, alpha: 1.0)

            // Skip if too similar to existing colors
            let isDuplicate = distinctColors.contains { existing in
                colorDistance(color, existing) < 0.15
            }

            // Skip very gray colors (low saturation)
            let saturation = colorSaturation(r: r, g: g, b: b)
            let isGray = saturation < 0.1

            if !isDuplicate && !isGray {
                distinctColors.append(color)
            }

            if distinctColors.count >= 4 {
                break
            }
        }

        // Pad with darker variants if not enough colors
        while distinctColors.count < 4 {
            if let last = distinctColors.last {
                distinctColors.append(last.darker(by: 30) ?? last)
            } else {
                distinctColors.append(.black)
            }
        }

        return ImageColors(
            primary: distinctColors[0],
            secondary: distinctColors[1],
            background: distinctColors[2],
            detail: distinctColors[3]
        )
    }

    /// Extract colors asynchronously
    static func extractColors(
        from image: UIImage,
        quality: Quality = .medium,
        completion: @escaping (ImageColors) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let colors = extractColors(from: image, quality: quality)
            DispatchQueue.main.async {
                completion(colors)
            }
        }
    }

    // MARK: - Private Helpers

    /// Calculate distance between two colors (0-1)
    private static func colorDistance(_ c1: UIColor, _ c2: UIColor) -> CGFloat {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

        c1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        c2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        let dr = r1 - r2
        let dg = g1 - g2
        let db = b1 - b2

        return sqrt(dr*dr + dg*dg + db*db) / sqrt(3)
    }

    /// Calculate saturation of a color
    private static func colorSaturation(r: CGFloat, g: CGFloat, b: CGFloat) -> CGFloat {
        let maxVal = max(r, max(g, b))
        let minVal = min(r, min(g, b))
        return maxVal == 0 ? 0 : (maxVal - minVal) / maxVal
    }
}

// MARK: - UIColor Extension

extension UIColor {
    /// Create a darker version of this color
    func darker(by percentage: CGFloat = 20) -> UIColor? {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }

        let factor = 1 - (percentage / 100)
        return UIColor(
            red: max(r * factor, 0),
            green: max(g * factor, 0),
            blue: max(b * factor, 0),
            alpha: a
        )
    }

    /// Create a lighter version of this color
    func lighter(by percentage: CGFloat = 20) -> UIColor? {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }

        let factor = percentage / 100
        return UIColor(
            red: min(r + (1 - r) * factor, 1),
            green: min(g + (1 - g) * factor, 1),
            blue: min(b + (1 - b) * factor, 1),
            alpha: a
        )
    }
}

// MARK: - SwiftUI Image Extension

extension Image {
    /// Get UIImage from SwiftUI Image (for asset images only)
    func asUIImage(named name: String) -> UIImage? {
        return UIImage(named: name)
    }
}
