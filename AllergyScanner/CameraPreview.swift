//
//  CameraPreview.swift
//  AllergyScanner
//
//  Created by Dina Bravo Stojakovic on 10/06/2025.
//

import SwiftUI
import AVFoundation

/// A SwiftUI UIViewRepresentable that shows the live camera feed, with match-highlight
/// boxes drawn directly on the preview layer.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    /// Vision-normalized rects (bottom-left origin, 0...1) to highlight.
    var matchedBoxes: [CGRect] = []

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.session = session
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.matchedBoxes = matchedBoxes
    }

    /// A UIView subclass whose backing layer is AVCaptureVideoPreviewLayer.
    class PreviewView: UIView {
        /// Use AVCaptureVideoPreviewLayer for this view's layer.
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        /// Convenience accessor
        private var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }

        private var highlightLayers: [CAShapeLayer] = []

        /// Maps a Vision bounding box (normalized, bottom-left origin, in the *upright*
        /// portrait image that Vision was told to read via its `.right` orientation hint)
        /// into AVFoundation's metadata-output space, which
        /// `layerRectConverted(fromMetadataOutputRect:)` expects: normalized, top-left
        /// origin, and relative to the sensor's *native* landscape orientation. The preview
        /// layer applies its own `.portrait` rotation during that conversion, so the
        /// portrait rotation Vision already applied has to be undone here first —
        /// otherwise the box gets rotated twice and ends up tall, narrow, and misplaced.
        /// (Same two-step transform Apple uses in its "Reading Phone Numbers in Real Time"
        /// Vision sample.)
        private static let visionToMetadataOutputTransform: CGAffineTransform = {
            // 1. Bottom-left origin -> top-left origin.
            let bottomToTop = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -1)
            // 2. Upright portrait -> native landscape (inverse of the `.right` rotation).
            let uprightToNative = CGAffineTransform(translationX: 0, y: 1).rotated(by: -.pi / 2)
            return bottomToTop.concatenating(uprightToNative)
        }()

        /// Set the session and configure orientation/gravity
        var session: AVCaptureSession? {
            get { previewLayer.session }
            set {
                previewLayer.session = newValue
                // .resizeAspectFill fills the screen edge-to-edge (matching every other
                // camera UI), cropping evenly rather than leaving letterboxed bars. Match
                // highlight boxes are converted through the same layer below, so they stay
                // aligned with whatever crop this produces.
                previewLayer.videoGravity = .resizeAspectFill
                if let conn = previewLayer.connection, conn.isVideoOrientationSupported {
                    conn.videoOrientation = .portrait
                }
            }
        }

        var matchedBoxes: [CGRect] = [] {
            didSet { updateHighlights() }
        }

        /// Ensure the preview layer always matches the view's bounds
        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer.frame = bounds
            updateHighlights()
        }

        /// Draws `matchedBoxes` as rounded outlines, converting each from Vision's
        /// coordinate space into AVFoundation's metadata-output space (see
        /// `visionToMetadataOutputTransform`), then into this layer's own coordinate space
        /// via `layerRectConverted(fromMetadataOutputRect:)` — which accounts for the
        /// preview's video gravity (aspect-fill cropping) and orientation for us.
        private func updateHighlights() {
            highlightLayers.forEach { $0.removeFromSuperlayer() }
            highlightLayers.removeAll()

            for box in matchedBoxes {
                let metadataBox = box.applying(Self.visionToMetadataOutputTransform)
                let converted = previewLayer.layerRectConverted(fromMetadataOutputRect: metadataBox)

                let shape = CAShapeLayer()
                shape.path = UIBezierPath(roundedRect: converted, cornerRadius: 6).cgPath
                shape.fillColor = UIColor.clear.cgColor
                shape.strokeColor = UIColor.warning.cgColor
                shape.lineWidth = 3
                shape.shadowColor = UIColor.warning.cgColor
                shape.shadowOpacity = 0.6
                shape.shadowRadius = 4
                shape.shadowOffset = .zero
                layer.addSublayer(shape)
                highlightLayers.append(shape)
            }
        }
    }
}
