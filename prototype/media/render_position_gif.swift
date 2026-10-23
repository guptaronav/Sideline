import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

private func scaled(_ image: CGImage, width: Int) -> CGImage? {
    let height = Int((Double(image.height) / Double(image.width)) * Double(width))
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()
}

private func writePNG(_ image: CGImage, to url: URL) {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else { return }
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
}

@main
private struct PositionGIFRenderer {
    static func main() async throws {
        guard CommandLine.arguments.count == 4 else {
            fputs("usage: render_position_gif INPUT.mp4 OUTPUT.gif PREVIEW.png\n", stderr)
            exit(2)
        }

        let input = URL(fileURLWithPath: CommandLine.arguments[1])
        let output = URL(fileURLWithPath: CommandLine.arguments[2])
        let preview = URL(fileURLWithPath: CommandLine.arguments[3])
        let asset = AVURLAsset(url: input)
        let duration = try await asset.load(.duration).seconds
        let videoTrack = try await asset.loadTracks(withMediaType: .video).first
        let naturalSize = try await videoTrack?.load(.naturalSize) ?? .zero
        let preferredTransform = try await videoTrack?.load(.preferredTransform) ?? .identity
        let transformedSize = naturalSize.applying(preferredTransform)
        let fps = 12.0
        let frameCount = max(Int(duration * fps), 1)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        guard let destination = CGImageDestinationCreateWithURL(
            output as CFURL,
            UTType.gif.identifier as CFString,
            frameCount,
            nil
        ) else { throw NSError(domain: "SidelineGIF", code: 1) }

        let gifProperties: CFDictionary = [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
        ] as CFDictionary
        CGImageDestinationSetProperties(destination, gifProperties)

        for index in 0..<frameCount {
            let seconds = min(Double(index) / fps, max(duration - 0.001, 0))
            let time = CMTime(seconds: seconds, preferredTimescale: 600)
            let image = try await generator.image(at: time).image
            guard let frame = scaled(image, width: 660) else { continue }
            let frameProperties: CFDictionary = [
                kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1 / fps]
            ] as CFDictionary
            CGImageDestinationAddImage(destination, frame, frameProperties)

            if index == 0 {
                writePNG(frame, to: preview)
            }
        }

        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "SidelineGIF", code: 2)
        }
        let durationText = String(format: "%.2f", duration)
        print(
            "Rendered \(frameCount) frames at \(Int(fps)) fps from " +
            "\(durationText) s video " +
            "(\(Int(abs(transformedSize.width)))x\(Int(abs(transformedSize.height))))"
        )
    }
}
