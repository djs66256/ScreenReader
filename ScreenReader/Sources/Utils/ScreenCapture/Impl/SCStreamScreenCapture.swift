import ScreenCaptureKit
import Foundation
import Cocoa
import AVFoundation
import CoreGraphics

class SCStreamScreenCapture: NSObject, ScreenCapture, SCStreamOutput {
    func captureSelectedArea(_ rect: CGRect?, in screen: NSScreen, completion: @escaping (NSImage?) -> Void) {
        Task {
            do {
                // 获取共享内容
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

                // 获取屏幕的displayID
                guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                    completion(nil)
                    return
                }
                let displayID = screenNumber.uint32Value

                // 通过displayID查找匹配的显示器
                guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
                    completion(nil)
                    return
                }

                // 创建内容过滤器
                let filter = SCContentFilter(display: display, excludingWindows: [])

                // 配置截图参数
                let scale = screen.backingScaleFactor  // 统一使用backingScaleFactor
                let config = SCStreamConfiguration()
                config.width = Int(filter.contentRect.width * scale)  // 考虑显示器的缩放因子
                config.height = Int(filter.contentRect.height * scale)
                config.scalesToFit = false
                config.pixelFormat = kCVPixelFormatType_32BGRA
                config.showsCursor = false

                // 使用SCScreenshotManager进行截图
                let image: NSImage? = try await withCheckedThrowingContinuation { continuation in
                    SCScreenshotManager.captureImage(contentFilter: filter, configuration: config) { cgImage, error in
                        if let cgImage = cgImage {
                            var nsImage: NSImage?

                            // 如果有指定区域，进行裁剪
                            if let rect = rect {
                                let cropRect = CGRect(
                                    x: rect.origin.x * scale,
                                    y: (screen.frame.height - rect.origin.y - rect.height) * scale,
                                    width: rect.width * scale,
                                    height: rect.height * scale
                                )

                                if let croppedCGImage = cgImage.cropping(to: cropRect) {
                                    nsImage = NSImage(
                                        cgImage: croppedCGImage,
                                        size: NSSize(width: croppedCGImage.width, height: croppedCGImage.height)
                                    )
                                }
                            }
                            // 如果没有指定区域，直接使用原始CGImage
                            if nsImage == nil {
                                nsImage = NSImage(
                                    cgImage: cgImage,
                                    size: NSSize(width: cgImage.width, height: cgImage.height)
                                )
                            }

                            continuation.resume(returning: nsImage)
                        } else if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: nil)
                        }
                    }
                }

                completion(image)
            } catch {
                completion(nil)
            }
        }
    }

}
