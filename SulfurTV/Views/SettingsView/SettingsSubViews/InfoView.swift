//
//  InfoView.swift
//  Sulfur
//
//  Created by Dominic on 22.04.25.
//

import SwiftUI
import CoreImage

struct InfoView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let urlString: String

    var body: some View {
        NavigationView {
            HStack(spacing: 80) {
                if let qrImage = generateQRCode(from: urlString) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 300, height: 300)
                        .padding()
                        .background(.primary)
                        .cornerRadius(30)
                }

                // Text + Close Button
                VStack(alignment: .leading, spacing: 40) {
                    Text("Scan to Visit")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.primary)

                    Text("Links cannot be openend on tvOS. But you can either Scan the QR-Code or type in the following URL into the Browser of your choosing: \n\n\(urlString)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: 500)

                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accentColor)
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle(title)
        }
    }

    func generateQRCode(from string: String) -> UIImage? {
        let data = Data(string.utf8)
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("Q", forKey: "inputCorrectionLevel")

        guard let ciImage = filter.outputImage else { return nil }

        // Scale the image up
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledCIImage = ciImage.transformed(by: transform)

        // Render CIImage into CGImage
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledCIImage, from: scaledCIImage.extent) else { return nil }

        return UIImage(cgImage: cgImage)
    }
}
