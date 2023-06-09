//
//  CameraPreviewView.swift
//  VisionBodyDetector
//
//  Created by Yaser on 7.06.2023.
//

import UIKit
import AVFoundation

class CameraPreviewView: UIView {
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
    
}
