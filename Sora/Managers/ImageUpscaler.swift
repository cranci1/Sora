//
//  ImageUpscaler.swift
//  Sulfur
//
//  Created by seiike on 26/05/2025.
//


import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision
import CoreML
import Kingfisher

public enum ImageUpscaler {
    /// Lanczos interpolation + unsharp mask for sharper upscaling.
    /// - Parameters:
    ///   - scale: The factor to upscale (e.g. 2.0 doubles width/height).
    ///   - sharpeningIntensity: The unsharp mask intensity (0...1).
    ///   - sharpeningRadius: The unsharp mask radius in pixels.
    public static func lanczosProcessor(
        scale: CGFloat,
        sharpeningIntensity: Float = 0.7,
        sharpeningRadius: Float = 2.0
    ) -> ImageProcessor {
        return LanczosUpscaleProcessor(
            scale: scale,
            sharpeningIntensity: sharpeningIntensity,
            sharpeningRadius: sharpeningRadius
        )
    }

    public static func superResolutionProcessor(modelURL: URL) -> ImageProcessor {
        return MLScaleProcessor(modelURL: modelURL)
    }
}

// MARK: - Lanczos + Unsharp Mask Processor
public struct LanczosUpscaleProcessor: ImageProcessor {
    public let scale: CGFloat
    public let sharpeningIntensity: Float
    public let sharpeningRadius: Float
    public var identifier: String {
        "com.yourapp.lanczos_\(scale)_sharp_\(sharpeningIntensity)_\(sharpeningRadius)"
    }

    public init(
        scale: CGFloat,
        sharpeningIntensity: Float = 0.7,
        sharpeningRadius: Float = 2.0
    ) {
        self.scale = scale
        self.sharpeningIntensity = sharpeningIntensity
        self.sharpeningRadius = sharpeningRadius
    }

    public func process(
        item: ImageProcessItem,
        options: KingfisherParsedOptionsInfo
    ) -> KFCrossPlatformImage? {
        
        let inputImage: KFCrossPlatformImage?
        switch item {
        case .image(let image):
            inputImage = image
        case .data(let data):
            inputImage = KFCrossPlatformImage(data: data)
        }
        guard let uiImage = inputImage,
              let cgImage = uiImage.cgImage else {
            return nil
        }

        let ciInput = CIImage(cgImage: cgImage)

        let scaleFilter = CIFilter.lanczosScaleTransform()
        scaleFilter.inputImage   = ciInput
        scaleFilter.scale        = Float(scale)
        scaleFilter.aspectRatio  = 1.0
        guard let scaledCI = scaleFilter.outputImage else {
            return uiImage
        }

        let unsharp = CIFilter.unsharpMask()
        unsharp.inputImage    = scaledCI
        unsharp.intensity     = sharpeningIntensity
        unsharp.radius        = sharpeningRadius
        guard let sharpCI = unsharp.outputImage else {
            return UIImage(ciImage: scaledCI)
        }

        let context = CIContext(options: nil)
        guard let outputCG = context.createCGImage(sharpCI, from: sharpCI.extent) else {
            return UIImage(ciImage: sharpCI)
        }
        return KFCrossPlatformImage(cgImage: outputCG)
    }
}

// MARK: - Core ML Super-Resolution Processor
public struct MLScaleProcessor: ImageProcessor {
    private let request: VNCoreMLRequest
    private let ciContext = CIContext()
    public let identifier: String

    public init(modelURL: URL) {

        self.identifier = "com.yourapp.ml_sr_\(modelURL.lastPathComponent)"
        guard let mlModel = try? MLModel(contentsOf: modelURL),
              let visionModel = try? VNCoreMLModel(for: mlModel) else {
            fatalError("Failed to load Core ML model at \(modelURL)")
        }
        let req = VNCoreMLRequest(model: visionModel)
        req.imageCropAndScaleOption = .scaleFill
        self.request = req
    }

    public func process(
        item: ImageProcessItem,
        options: KingfisherParsedOptionsInfo
    ) -> KFCrossPlatformImage? {

        let inputImage: KFCrossPlatformImage?
        switch item {
        case .image(let image):
            inputImage = image
        case .data(let data):
            inputImage = KFCrossPlatformImage(data: data)
        }
        guard let uiImage = inputImage,
              let cgImage = uiImage.cgImage else {
            return nil
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("[MLScaleProcessor] Vision error: \(error)")
            return uiImage
        }
        guard let obs = request.results?.first as? VNPixelBufferObservation else {
            return uiImage
        }

        let ciOutput = CIImage(cvPixelBuffer: obs.pixelBuffer)
        let rect = CGRect(
            origin: .zero,
            size: CGSize(
                width: CVPixelBufferGetWidth(obs.pixelBuffer),
                height: CVPixelBufferGetHeight(obs.pixelBuffer)
            )
        )
        guard let finalCG = ciContext.createCGImage(ciOutput, from: rect) else {
            return uiImage
        }
        return KFCrossPlatformImage(cgImage: finalCG)
    }
}

// the sweet spot (for mediainfoview poster)
//    .setProcessor(ImageUpscaler.lanczosProcessor(scale: 3.2,
//                                                 sharpeningIntensity: 0.75,
//                                                 sharpeningRadius: 2.25))
