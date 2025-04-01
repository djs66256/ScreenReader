import ScreenCaptureKit
import Foundation
import Cocoa
import AVFoundation
import CoreGraphics
import os

/// 截图管理器，负责处理交互式屏幕截图功能
/// 主要功能包括：
/// 1. 创建跨屏的选择区域窗口
/// 2. 处理鼠标移动和键盘事件
/// 3. 协调截图流程
class ScreenshotManager: NSObject {
    /// 单例实例
    static let shared = ScreenshotManager()
    
    /// 选择区域窗口
    private var selectionWindow: NSWindow?
    /// 选择区域视图
    private var selectionView: ScreenshotSelectionView?
    /// 事件监听器
    private var eventMonitor: Any?
    /// 屏幕捕获实现
    private var screenCapture: ScreenCapture
    /// 是否启用详细日志
    private var verboseLogging = false

    override init() {
        // 默认使用AVFoundation实现的屏幕捕获
        screenCapture = AVScreenCapture()
        super.init()
    }

    /// 异步执行交互式截图
    /// - Returns: 截取的图像，如果取消则为nil
    func captureInteractive() async -> NSImage? {
        return await withCheckedContinuation { continuation in
            startInteractiveCapture { image in
                continuation.resume(returning: image)
            }
        }
    }

    /// 开始交互式截图流程
    /// - Parameter completion: 截图完成后的回调
    func startInteractiveCapture(completion: @escaping (NSImage?) -> Void) {
        DispatchQueue.main.async {
            // 设置鼠标为十字准星样式
            NSCursor.crosshair.push()
            NSCursor.current.set()

            // 获取鼠标当前位置
            let mouseLocation = NSEvent.mouseLocation
            if self.verboseLogging {
                os_log("初始鼠标位置: (%.1f, %.1f)", log: .default, type: .debug, mouseLocation.x, mouseLocation.y)
            }
            
            // 找到包含鼠标的屏幕
            let initialScreen = NSScreen.screens.first { screen in
                NSMouseInRect(mouseLocation, screen.frame, false)
            }
            os_log("初始屏幕: %{public}@ 分辨率: %.0fx%.0f", log: .default, type: .debug, 
                  initialScreen?.localizedName ?? "未知", 
                  initialScreen?.frame.width ?? 0, 
                  initialScreen?.frame.height ?? 0)
            
            // 在鼠标所在屏幕上创建选择窗口
            self.createSelectionWindow(on: initialScreen, completion: completion)

            // 添加标志位跟踪是否已点击
            var hasClicked = false

            // 监听鼠标移动、左键点击和键盘事件
            self.eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .keyDown]) { [weak self] event in
                guard let self = self else { return event }
                
                switch event.type {
                case .mouseMoved where !hasClicked:
                    // 处理鼠标移动事件
                    let mouseLocation = NSEvent.mouseLocation
                    if self.verboseLogging {
                        os_log("鼠标移动 - 位置: (%.1f, %.1f)", log: .default, type: .debug, mouseLocation.x, mouseLocation.y)
                    }
                    // 检查是否切换到新屏幕
                    if let currentScreen = NSScreen.screens.first(where: { screen in
                        NSMouseInRect(mouseLocation, screen.frame, false)
                    }), currentScreen != self.selectionWindow?.screen {
                        os_log("屏幕切换 - 新屏幕: %{public}@ 分辨率: %.0fx%.0f", log: .default, type: .info,
                              currentScreen.localizedName, 
                              currentScreen.frame.width, 
                              currentScreen.frame.height)
                        // 在新屏幕上创建选择窗口
                        self.createSelectionWindow(on: currentScreen, completion: completion)
                    }
                    
                case .leftMouseDown:
                    // 处理鼠标左键点击事件
                    if self.verboseLogging {
                        os_log("鼠标左键点击, 移除鼠标移动监听", log: .default, type: .debug)
                    }
                    hasClicked = true
                    // 移除事件监听器
                    if let monitor = self.eventMonitor {
                        NSEvent.removeMonitor(monitor)
                        self.eventMonitor = nil
                    }
                    
                case .keyDown:
                    // 处理键盘事件
                    if self.verboseLogging {
                        os_log("键盘事件: keyCode=%d", log: .default, type: .debug, event.keyCode)
                    }
                    switch event.keyCode {
                    case 53: // ESC键
                        if self.verboseLogging {
                            os_log("用户按下ESC键，取消截图", log: .default, type: .info)
                        }
                        // 取消截图流程
                        DispatchQueue.main.async {
                            self.cleanup()
                            completion(nil)
                        }
                    default:
                        break
                    }
                    
                default:
                    break
                }
                return event
            }
        }
    }

    /// 在选择屏幕上创建选择窗口
    /// - Parameters:
    ///   - screen: 目标屏幕
    ///   - completion: 截图完成回调
    @MainActor private func createSelectionWindow(on screen: NSScreen?, completion: @escaping (NSImage?) -> Void) {
        // 如果窗口已存在，先移除
        selectionWindow?.orderOut(nil)
        
        // 使用指定屏幕的frame
        let windowFrame = screen?.frame ?? NSScreen.main?.frame ?? .zero
        
        // 创建无边框透明窗口
        selectionWindow = CustomBorderlessWindow(
            contentRect: windowFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        // 配置窗口属性
        selectionWindow?.level = .screenSaver  // 设置窗口层级高于普通窗口
        selectionWindow?.isOpaque = false
        selectionWindow?.backgroundColor = NSColor.clear
        selectionWindow?.ignoresMouseEvents = false
        selectionWindow?.isReleasedWhenClosed = false
        selectionWindow?.acceptsMouseMovedEvents = true

        // 创建选择区域视图
        selectionView = ScreenshotSelectionView(frame: windowFrame)
        selectionWindow?.contentView = selectionView
        
        // 设置选择完成回调
        selectionView?.selectionHandler = { [weak self] rect in
            guard let self = self else { return }
            self.cleanup()
            
            if let screen = screen ?? NSScreen.main {
                // 捕获选定区域的图像
                self.screenCapture.captureSelectedArea(rect, in: screen) { image in
                    DispatchQueue.main.async {
                        completion(image)
                    }
                }
            } else {
                // 当无法获取屏幕时的错误处理
                DispatchQueue.main.async {
                    completion(nil)
                }
                if self.verboseLogging {
                    os_log("无法获取屏幕信息，截图失败", log: .default, type: .error)
                }
            }
        }
        
        // 设置取消选择回调
        selectionView?.cancelHandler = { [weak self] in
            guard let self = self else { return }
            self.cleanup()
            DispatchQueue.main.async {
                completion(nil)
            }
        }
        
        // 显示窗口并获取焦点
        selectionWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        selectionWindow?.makeFirstResponder(selectionView)
    }
    
    /// 清理资源
    private func cleanup() {
        // 移除事件监听器
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        // 关闭并清理窗口
        selectionWindow?.orderOut(nil)
        selectionWindow = nil
        selectionView = nil
        // 恢复鼠标样式
        NSCursor.pop()
    }
}

