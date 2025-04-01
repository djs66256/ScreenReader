import ScreenCaptureKit
import Foundation
import Cocoa
import AVFoundation
import CoreGraphics

class SCStreamScreenCapture: NSObject, ScreenCapture, SCStreamOutput {
    func captureSelectedArea(_ rect: CGRect?, in screen: NSScreen, completion: @escaping (NSImage?) -> Void) {
        
    }
    
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
                // 获取所有可共享内容，包括所有显示器
                let content = try await SCShareableContent.excludingDesktopWindows(false,
                                                                                   onScreenWindowsOnly: true)
                
                // 查找包含选择区域的显示器
                let screenFrame = NSScreen.main?.frame ?? .zero
                let displayScale = NSScreen.main?.backingScaleFactor ?? 1.0
                
                // 确定要捕获的显示器
                guard let display = findDisplayForRect(rect, in: content.displays) else {
                    print("无法找到匹配的显示器")
                    completion(nil)
                    return
                }
                
                // 计算显示器的物理像素与逻辑像素的比例
                let scale = CGFloat(display.width) / (screenFrame.width * displayScale)
                
                // 计算在显示器坐标系中的选择区域
                let scaledRect: CGRect
                
                if rect.equalTo(screenFrame) {
                    // 全屏截图特殊处理
                    scaledRect = CGRect(origin: .zero, size: CGSize(width: display.width, height: display.height))
                } else {
                    // 找到包含选择区域的NSScreen
                    var targetScreen = NSScreen.main!
                    for screen in NSScreen.screens {
                        if screen.frame.contains(rect) || screen.frame.intersects(rect) {
                            targetScreen = screen
                            break
                        }
                    }
                    
                    // 计算选择区域相对于目标屏幕的位置
                    let relativeX = rect.origin.x - targetScreen.frame.origin.x
                    let relativeY = rect.origin.y - targetScreen.frame.origin.y
                    
                    // 计算缩放因子
                    let displayScale = targetScreen.backingScaleFactor
                    let scale = CGFloat(display.width) / (targetScreen.frame.width * displayScale)
                    
                    // 将坐标转换为显示器的物理像素坐标
                    scaledRect = CGRect(
                        x: relativeX * scale,
                        y: (targetScreen.frame.height - relativeY - rect.height) * scale,
                        width: rect.width * scale,
                        height: rect.height * scale
                    )
                    
                    print("原始区域: \(rect)")
                    print("目标屏幕: \(targetScreen.frame)")
                    print("相对位置: x=\(relativeX), y=\(relativeY)")
                    print("缩放后区域: \(scaledRect)")
                }
                
                // 创建内容过滤器，只包含选定的显示器
                let filter = SCContentFilter(display: display, excludingWindows: [])
                
                // 配置流参数
                let config = SCStreamConfiguration()
                config.sourceRect = scaledRect
                config.width = Int(scaledRect.width)
                config.height = Int(scaledRect.height)
                
                // 设置高质量参数
                config.pixelFormat = kCVPixelFormatType_32BGRA
                config.scalesToFit = false  // 不缩放以保持原始分辨率
                config.showsCursor = false
                config.queueDepth = 5
                config.minimumFrameInterval = CMTime(value: 1, timescale: 60) // 60fps
                
                // 创建并配置流
                let stream = SCStream(filter: filter, configuration: config, delegate: nil)
                try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: nil)
                
                // 开始捕获
                try await stream.startCapture()
                
                // 增加延迟时间到1秒确保完整捕获
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    stream.stopCapture()
                    completion(self?.capturedImage)
                }
            } catch {
                print("截图错误: \(error)")
                completion(nil)
            }
        }
    }
    
    // 查找包含指定区域的显示器
    private func findDisplayForRect(_ rect: CGRect, in displays: [SCDisplay]) -> SCDisplay? {
        // 如果只有一个显示器，直接返回
        if displays.count == 1 {
            return displays.first
        }
        
        // 对于多显示器，我们需要更精确地确定正确的显示器
        let screens = NSScreen.screens
        
        // 打印调试信息
        print("选择区域: \(rect)")
        for (index, screen) in screens.enumerated() {
            print("屏幕 \(index): frame=\(screen.frame), visibleFrame=\(screen.visibleFrame)")
        }
        
        // 首先尝试找到完全包含选择区域的屏幕
        for (index, screen) in screens.enumerated() {
            if screen.frame.contains(rect) {
                print("区域完全在屏幕 \(index) 内")
                
                // 找到对应的SCDisplay
                for display in displays {
                    let displayFrame = CGRect(x: 0, y: 0, width: display.width, height: display.height)
                    print("检查显示器: width=\(display.width), height=\(display.height)")
                    
                    // 通过比较尺寸和位置来匹配SCDisplay和NSScreen
                    let screenSize = CGSize(
                        width: screen.frame.width * screen.backingScaleFactor,
                        height: screen.frame.height * screen.backingScaleFactor
                    )
                    
                    if abs(CGFloat(display.width) - screenSize.width) < 10.0 &&
                        abs(CGFloat(display.height) - screenSize.height) < 10.0 {
                        print("找到匹配显示器: \(display.width)x\(display.height)")
                        return display
                    }
                }
            }
        }
        
        // 如果没有完全包含的，查找相交最多的屏幕
        var bestScreen: NSScreen? = nil
        var largestIntersection: CGFloat = 0
        
        for screen in screens {
            let intersection = screen.frame.intersection(rect)
            if !intersection.isNull && !intersection.isEmpty {
                let area = intersection.width * intersection.height
                if area > largestIntersection {
                    largestIntersection = area
                    bestScreen = screen
                }
            }
        }
        
        if let screen = bestScreen {
            print("找到最佳相交屏幕: \(screen.frame)")
            
            // 找到对应的SCDisplay
            for display in displays {
                // 通过比较尺寸来匹配
                let screenSize = CGSize(
                    width: screen.frame.width * screen.backingScaleFactor,
                    height: screen.frame.height * screen.backingScaleFactor
                )
                
                if abs(CGFloat(display.width) - screenSize.width) < 10.0 &&
                    abs(CGFloat(display.height) - screenSize.height) < 10.0 {
                    return display
                }
            }
        }
        
        // 如果上述方法都失败，尝试直接使用包含点击位置的屏幕
        let clickPoint = CGPoint(x: rect.midX, y: rect.midY)
        for screen in screens {
            if screen.frame.contains(clickPoint) {
                print("点击位置在屏幕: \(screen.frame)")
                
                // 找到对应的SCDisplay
                for display in displays {
                    let screenSize = CGSize(
                        width: screen.frame.width * screen.backingScaleFactor,
                        height: screen.frame.height * screen.backingScaleFactor
                    )
                    
                    if abs(CGFloat(display.width) - screenSize.width) < 10.0 &&
                        abs(CGFloat(display.height) - screenSize.height) < 10.0 {
                        return display
                    }
                }
            }
        }
        
        // 如果仍然没有找到，使用主屏幕
        if let mainScreen = NSScreen.main {
            print("使用主屏幕: \(mainScreen.frame)")
            
            for display in displays {
                let mainScreenSize = CGSize(
                    width: mainScreen.frame.width * mainScreen.backingScaleFactor,
                    height: mainScreen.frame.height * mainScreen.backingScaleFactor
                )
                
                if abs(CGFloat(display.width) - mainScreenSize.width) < 10.0 &&
                    abs(CGFloat(display.height) - mainScreenSize.height) < 10.0 {
                    return display
                }
            }
        }
        
        // 最后的后备方案
        print("使用第一个可用显示器")
        return displays.first
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
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
