import ScreenCaptureKit
import Foundation
import Cocoa
import AVFoundation
import CoreGraphics

class AVScreenCapture: NSObject, ScreenCapture {
    private var session: AVCaptureSession?
    private var output: AVCaptureVideoDataOutput?
    private var completion: ((NSImage?) -> Void)?
    
    func captureSelectedArea(_ rect: CGRect?, in screen: NSScreen, completion: @escaping (NSImage?) -> Void) {
        self.completion = completion
        
        let session = AVCaptureSession()
        session.sessionPreset = .high
        
        // 直接从传入的screen获取displayID
        guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            completion(nil)
            return
        }
        
        // 设置屏幕输入
        guard let screenInput = AVCaptureScreenInput(displayID: displayID) else {
            completion(nil)
            return
        }
        
        // 转换为显示器坐标系中的相对位置
//        let displayBounds = getDisplayBounds(displayID)
//        let relativeRect = CGRect(
//            x: rect.origin.x - displayBounds.origin.x,
//            y: rect.origin.y - displayBounds.origin.y,
//            width: rect.width,
//            height: rect.height
//        )
        let cropRect = rect ?? CGDisplayBounds(displayID)
        
        screenInput.cropRect = cropRect
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
        // DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        //     self?.session?.stopRunning()
        //     self?.completion?(self?.capturedImage)
        //     self?.session = nil
        //     self?.output = nil
        // }
    }
    
    private var capturedImage: NSImage?
}

extension AVScreenCapture: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // 创建高质量图像
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let context = CIContext(options: [.useSoftwareRenderer: false])
        
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            self.capturedImage = nsImage
            self.completion?(nsImage)  // 立即返回图片
            self.session?.stopRunning()  // 停止会话
            self.session = nil
            self.output = nil
        }
    }
}
