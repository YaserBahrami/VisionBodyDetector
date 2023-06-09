//
//  CameraPreviewView.swift
//  VisionBodyDetector
//
//  Created by Yaser on 7.06.2023.
//

import UIKit
import AVFoundation

class CameraPreviewView: UIView {
    private var overlayLayer = CAShapeLayer()
    private var pointsPath = UIBezierPath()
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("Expected 'AVCaptureVideoPreviewLayer' type for layer. check CameraPreviewView.layerClass implementation.")
        }
//        layer.videoGravity = .resizeAspect
        return layer
    }
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupOverlay()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupOverlay()
    }
    
    override func layoutSublayers(of layer: CALayer) {
        super.layoutSublayers(of: layer)
        if layer == videoPreviewLayer {
            overlayLayer.frame = layer.bounds
        }
    }

    private func setupOverlay() {
        videoPreviewLayer.addSublayer(overlayLayer)
    }
    
    func showPoints(_ points: [CGPoint], color: UIColor) {
        pointsPath.removeAllPoints()
        for point in points {
            pointsPath.move(to: point)
            pointsPath.addArc(withCenter: point, radius: 5, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        }
        overlayLayer.fillColor = color.cgColor
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        overlayLayer.path = pointsPath.cgPath
        CATransaction.commit()
    }
    
    
}
