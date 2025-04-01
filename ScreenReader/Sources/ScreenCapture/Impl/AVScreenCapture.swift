import ScreenCaptureKit
import Foundation
import Cocoa
import AVFoundation
import CoreGraphics

class AVScreenCapture: NSObject, ScreenCapture {
    private var session: AVCaptureSession?
    private var output: AVCaptureVideoDataOutput?
    private var completion: ((NSImage?) -> Void)?
    
    func captureSelectedArea(_ rect: CGRect, completion: @escaping (NSImage?) -> Void) {
        self.completion = completion
        
        let session = AVCaptureSession()
        session.sessionPreset = .high
        
        // 获取包含指定区域的显示器
        let displayID = getDisplayIDContainingRect(rect)
        
        /*
         if let cgImage = CGWindowListCreateImage(rect, .optionOnScreenOnly, kCGNullWindowID, .bestResolution) {
                     let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                     completion(nsImage)
                     return
                 }
         */
        
        // 设置屏幕输入
        guard let screenInput = AVCaptureScreenInput(displayID: displayID) else {
            completion(nil)
            return
        }
        
        // 转换为显示器坐标系中的相对位置
        let displayBounds = getDisplayBounds(displayID)
        let relativeRect = CGRect(
            x: rect.origin.x - displayBounds.origin.x,
            y: rect.origin.y - displayBounds.origin.y,
            width: rect.width,
            height: rect.height
        )
        
        screenInput.cropRect = relativeRect
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
    
    // 获取包含指定区域的显示器ID
    private func getDisplayIDContainingRect(_ rect: CGRect) -> CGDirectDisplayID {
        var displayCount: UInt32 = 0
        var result = CGGetActiveDisplayList(0, nil, &displayCount)
        
        if result != CGError.success {
            return CGMainDisplayID()
        }
        
        let allocated = Int(displayCount)
        let activeDisplays = UnsafeMutablePointer<CGDirectDisplayID>.allocate(capacity: allocated)
        result = CGGetActiveDisplayList(displayCount, activeDisplays, &displayCount)
        
        if result != CGError.success {
            activeDisplays.deallocate()
            return CGMainDisplayID()
        }
        
        // 查找包含指定区域的显示器
        for i in 0..<Int(displayCount) {
            let displayID = activeDisplays[i]
            let displayBounds = getDisplayBounds(displayID)
            print("display => \(displayID): \(displayBounds)")
//            if displayBounds.contains(rect.origin) {
//                activeDisplays.deallocate()
//                return displayID
//            }
        }
        
        activeDisplays.deallocate()
        return CGMainDisplayID() // 如果没找到，返回主显示器
    }
    
    // 获取显示器的边界
    private func getDisplayBounds(_ displayID: CGDirectDisplayID) -> CGRect {
        return CGDisplayBounds(displayID)
    }
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
        }
    }
}
