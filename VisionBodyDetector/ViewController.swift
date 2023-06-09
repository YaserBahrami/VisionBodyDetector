//
//  ViewController.swift
//  VisionBodyDetector
//
//  Created by Yaser on 7.06.2023.
//

import UIKit
import SnapKit
import AVFoundation


class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {

    var multiCamSession = AVCaptureMultiCamSession()

    var frontCameraPreview = CameraPreviewView()
    var frontDeviceInput: AVCaptureDeviceInput?
    var frontVideoDataOutput = AVCaptureVideoDataOutput()
    var frontViewLayer: AVCaptureVideoPreviewLayer?


    var backCameraPreview = CameraPreviewView()
    var backDeviceInput: AVCaptureDeviceInput?
    var backVideoDataOutput = AVCaptureVideoDataOutput()
    var backViewLayer:AVCaptureVideoPreviewLayer?

    private let multiCamSessionQueue = DispatchQueue(label: "session queue")
    private let multiCamSessionOutputQueue = DispatchQueue(label: "session output queue")



    override func viewDidLoad() {
        super.viewDidLoad()

        setupPreview()
        

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupViews()

    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

#if targetEnvironment(simulator)

        let alertController = UIAlertController(title: "MultiCamera", message: "Please run on physical device", preferredStyle: .alert)

        alertController.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: { _ in
            exit(-1)
        }))

        self.present(alertController, animated: true, completion: nil)

        return
#endif

    }

    func setupViews() {

        view.addSubview(backCameraPreview)
        view.addSubview(frontCameraPreview)

        frontCameraPreview.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.width.equalToSuperview()
            make.height.equalToSuperview().dividedBy(2)
        }

        backCameraPreview.snp.makeConstraints { make in
            make.top.equalTo(frontCameraPreview.snp.bottom)
            make.bottom.equalToSuperview()
            make.width.equalToSuperview()
            make.height.equalToSuperview().dividedBy(2)
        }
    }



    func checkAuthorization() {

        switch AVCaptureDevice.authorizationStatus(for: .video) {

        case .authorized:
            // The user has previously granted access to the camera.
            configureDualVideo()
            break

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in

                if granted {
                    self.configureDualVideo()

                }

            })

            break


        default:

            // The user has previously denied access.

            DispatchQueue.main.async {

                let changePrivacySetting = "Device doesn't have permission to use the camera, please change privacy settings"

                let message = NSLocalizedString(changePrivacySetting, comment: "Alert message when the user has denied access to the camera")

                let alertController = UIAlertController(title: "Error", message: message, preferredStyle: .alert)

                alertController.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))

                alertController.addAction(UIAlertAction(title: "Settings", style: .default, handler: { _ in

                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {

                        UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)

                    }

                }))


                self.present(alertController, animated: true, completion: nil)

            }

        }
    }

    func setupPreview() {
        
        // Set up the back and front video preview views.
        
        backCameraPreview.videoPreviewLayer.setSessionWithNoConnection(multiCamSession)
        frontCameraPreview.videoPreviewLayer.setSessionWithNoConnection(multiCamSession)

        // Store the back and front video preview layers so we can connect them to their inputs
        backViewLayer = backCameraPreview.videoPreviewLayer
        frontViewLayer = frontCameraPreview.videoPreviewLayer
        
        backViewLayer?.videoGravity = .resizeAspectFill
        frontViewLayer?.videoGravity = .resizeAspectFill

        // Keep the screen awake
        UIApplication.shared.isIdleTimerDisabled = true

        checkAuthorization()
    }

    func configureDualVideo() {
        addObservers()
        multiCamSessionQueue.async {
            self.setupSession()
        }
    }

    func setupSession() {

        if !AVCaptureMultiCamSession.isMultiCamSupported {

            DispatchQueue.main.async {

                let alertController = UIAlertController(title: "Error", message: "Device is not supporting multicam feature", preferredStyle: .alert)

                alertController.addAction(UIAlertAction(title: "OK",style: .cancel, handler: nil))

                self.present(alertController, animated: true, completion: nil)

            }
            return
        }

        guard setupBackCamera() else{

          DispatchQueue.main.async {
           let alertController = UIAlertController(title: "Error", message: "issue while setuping back camera", preferredStyle: .alert)
           alertController.addAction(UIAlertAction(title: "OK",style: .cancel, handler: nil))
           self.present(alertController, animated: true, completion: nil)
          }
          return

        }

        guard setupFrontCamera() else{
            DispatchQueue.main.async {
                let alertController = UIAlertController(title: "Error", message: "issue while setuping front camera", preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "OK",style: .cancel, handler: nil))
                self.present(alertController, animated: true, completion: nil)
            }
            return
        }

        multiCamSessionQueue.async {
            self.multiCamSession.startRunning()
        }

    }


    func setupBackCamera() -> Bool {
        // Start configuring multi cam session
        multiCamSession.beginConfiguration()

        defer {
            //save config setting
            multiCamSession.commitConfiguration()
        }

        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("no back camera")
            return false
        }

        do {
            backDeviceInput = try AVCaptureDeviceInput(device: backCamera)

            guard let backInput = backDeviceInput, multiCamSession.canAddInput(backInput) else {
                print("no back camera device input")
                return false
            }

            multiCamSession.addInputWithNoConnections(backInput)
        } catch {
            print("no back camera device input: \(error)")
            return false
        }

        //back video port

        guard let backDeviceInput = backDeviceInput,
              let backVideoPort = backDeviceInput.ports(for: .video, sourceDeviceType: backCamera.deviceType, sourceDevicePosition: backCamera.position).first
        else {
            print("No back camera input's video port")
            return false
        }

        //append back video output

        guard multiCamSession.canAddOutput(backVideoDataOutput) else {
            print("no back camera output")
            return false
        }

        multiCamSession.addOutputWithNoConnections(backVideoDataOutput)

        backVideoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_32BGRA)]
        backVideoDataOutput.setSampleBufferDelegate(self, queue: multiCamSessionOutputQueue)


        //connect back output
        let backOutputConnection = AVCaptureConnection(inputPorts: [backVideoPort], output: backVideoDataOutput)

        guard multiCamSession.canAddConnection(backOutputConnection) else {
            print("no connection to the back camera video data output")
            return false
        }
        multiCamSession.addConnection(backOutputConnection)

        backOutputConnection.videoOrientation = .portrait

        //connect back input to back layer
        guard let backLayer = backViewLayer else {
            return false
        }

        let backConnection = AVCaptureConnection(inputPort: backVideoPort, videoPreviewLayer: backLayer)

        guard multiCamSession.canAddConnection(backConnection) else {
            print("no connection to the back camera video preview layer")
            return false
        }

        multiCamSession.addConnection(backConnection)

        return true
    }
    
    func setupFrontCamera() -> Bool{

        //start configuring dual video session
        multiCamSession.beginConfiguration()
        defer {
            //save configuration setting
            multiCamSession.commitConfiguration()
        }

        //search front camera for dual video session
        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            print("no front camera")
            return false
        }

        // append front camera input to dual video session
        do {
            frontDeviceInput = try AVCaptureDeviceInput(device: frontCamera)

            guard let frontInput = frontDeviceInput, multiCamSession.canAddInput(frontInput) else {
                print("no front camera input")
                return false
            }
            multiCamSession.addInputWithNoConnections(frontInput)
        } catch {
            print("no front input: \(error)")
            return false
        }

        // search front video port for dual video session
        guard let frontDeviceInput = frontDeviceInput,
              let frontVideoPort = frontDeviceInput.ports(for: .video, sourceDeviceType: frontCamera.deviceType, sourceDevicePosition: frontCamera.position).first else {
            print("no front camera device input's video port")
            return false
        }

        // append front video output to dual video session
        guard multiCamSession.canAddOutput(frontVideoDataOutput) else {
            print("no the front camera video output")
            return false
        }
        multiCamSession.addOutputWithNoConnections(frontVideoDataOutput)
        frontVideoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        frontVideoDataOutput.setSampleBufferDelegate(self, queue: multiCamSessionOutputQueue)

        // connect front output to dual video session
        let frontOutputConnection = AVCaptureConnection(inputPorts: [frontVideoPort], output: frontVideoDataOutput)
        guard multiCamSession.canAddConnection(frontOutputConnection) else {
            print("no connection to the front video output")
            return false
        }
        multiCamSession.addConnection(frontOutputConnection)
        frontOutputConnection.videoOrientation = .portrait
        frontOutputConnection.automaticallyAdjustsVideoMirroring = false
        frontOutputConnection.isVideoMirrored = true

        // connect front input to front layer
        guard let frontLayer = frontViewLayer else {
            return false
        }
        let frontLayerConnection = AVCaptureConnection(inputPort: frontVideoPort, videoPreviewLayer: frontLayer)
        guard multiCamSession.canAddConnection(frontLayerConnection) else {
            print("no connection to front layer")
            return false
        }
        
        multiCamSession.addConnection(frontLayerConnection)
        frontLayerConnection.automaticallyAdjustsVideoMirroring = false
        frontLayerConnection.isVideoMirrored = true

        return true
    }

    func addObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(sessionRuntimeError), name: .AVCaptureSessionRuntimeError,object: multiCamSession)
        NotificationCenter.default.addObserver(self, selector: #selector(sessionWasInterrupted), name: .AVCaptureSessionWasInterrupted, object: multiCamSession)
        NotificationCenter.default.addObserver(self, selector: #selector(sessionInterruptionEnded), name: .AVCaptureSessionInterruptionEnded, object: multiCamSession)
    }

    @objc func sessionWasInterrupted(notification: NSNotification) {
                print("Session was interrupted")
    }

    @objc func sessionInterruptionEnded(notification: NSNotification) {
        print("Session interrupt ended")
    }

    @objc func sessionRuntimeError(notification: NSNotification) {
        guard let errorValue = notification.userInfo?[AVCaptureSessionErrorKey] as? NSError else {
            return
        }

        let error = AVError(_nsError: errorValue)
        print("Capture session runtime error: \(error)")

        /*
         Automatically try to restart the session running if media services were
         reset and the last start running succeeded. Otherwise, enable the user
         to try to resume the session running.
         */
        if error.code == .mediaServicesWereReset {
            //Manage according to condition
        } else {
            //Manage according to condition
        }
    }





}
