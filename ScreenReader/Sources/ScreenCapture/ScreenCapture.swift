import ScreenCaptureKit
import Foundation
import Cocoa
import AVFoundation
import CoreGraphics

protocol ScreenCapture {
    func captureSelectedArea(_ rect: CGRect, completion: @escaping (NSImage?) -> Void)
}

class SCStreamScreenCapture: NSObject, ScreenCapture, SCStreamOutput {
    private let imageLock = NSLock()
    private var _capturedImage: NSImage?
    private var capturedImage: NSImage? {
        get {
            imageLock.lock()
            defer { imageLock.unlock() }
            return _capturedImage
        }
        set {
            imageLock.lock()
            defer { imageLock.unlock() }
            _capturedImage = newValue
        }
    }

    func captureSelectedArea(_ rect: CGRect, completion: @escaping (NSImage?) -> Void) {
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, 
                                                                                 onScreenWindowsOnly: true)
                guard let display = content.displays.first else {
                    completion(nil)
                    return
                }

                // 修改缩放计算，处理全屏情况
                let screenFrame = NSScreen.main?.frame ?? .zero
                let scale = CGFloat(display.width) / screenFrame.width
                let scaledRect: CGRect
                
                if rect == screenFrame {
                    // 全屏截图特殊处理
                    scaledRect = CGRect(origin: .zero, size: CGSize(width: display.width, height: display.height))
                } else {
                    scaledRect = CGRect(
                        x: rect.origin.x * scale,
                        y: (screenFrame.height - rect.origin.y - rect.height) * scale,
                        width: rect.width * scale,
                        height: rect.height * scale
                    )
                }
                
                let filter = SCContentFilter(display: display, excludingWindows: [])
                let config = SCStreamConfiguration()
                config.sourceRect = scaledRect
                config.width = Int(scaledRect.width)
                config.height = Int(scaledRect.height)
                // 设置高质量参数
                config.pixelFormat = kCVPixelFormatType_32BGRA
                config.scalesToFit = true
                config.showsCursor = false
                config.queueDepth = 5
                config.minimumFrameInterval = CMTime(value: 1, timescale: 60) // 60fps
                
                let stream = SCStream(filter: filter, configuration: config, delegate: nil)
                
                try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: nil)
                try await stream.startCapture()
                
                // 增加延迟时间到0.5秒确保捕获
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    stream.stopCapture()
                    completion(self?.capturedImage)
                }
            } catch {
                print("Capture error: \(error)")
                completion(nil)
            }
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let rep = NSCIImageRep(ciImage: ciImage)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        self.capturedImage = nsImage
    }
}

class AVScreenCapture: NSObject, ScreenCapture {
    private var session: AVCaptureSession?
    private var output: AVCaptureVideoDataOutput?
    private var completion: ((NSImage?) -> Void)?
    
    func captureSelectedArea(_ rect: CGRect, completion: @escaping (NSImage?) -> Void) {
        self.completion = completion
        
        let session = AVCaptureSession()
        session.sessionPreset = .high
        
        // 设置屏幕输入
        guard let screenInput = AVCaptureScreenInput(displayID: CGMainDisplayID()) else {
            completion(nil)
            return
        }
        screenInput.cropRect = rect
        screenInput.scaleFactor = 1.0
        
        // 设置视频输出
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: .userInitiated))
        
        // 配置会话
        if session.canAddInput(screenInput) {
            session.addInput(screenInput)
        }
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        
        self.session = session
        self.output = output
        
        // 开始捕获
        session.startRunning()
        
        // 设置超时
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.session?.stopRunning()
            self?.completion?(self?.capturedImage)
            self?.session = nil
            self?.output = nil
        }
    }
    
    private var capturedImage: NSImage?
}

extension AVScreenCapture: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, 
                     didOutput sampleBuffer: CMSampleBuffer,
                     from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let rep = NSCIImageRep(ciImage: ciImage)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        
        self.capturedImage = nsImage
    }
}