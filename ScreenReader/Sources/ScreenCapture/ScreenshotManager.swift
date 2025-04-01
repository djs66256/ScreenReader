import ScreenCaptureKit
import Foundation
import Cocoa
import AVFoundation
import CoreGraphics
import os

class ScreenshotManager: NSObject {
    static let shared = ScreenshotManager()
    private var selectionWindow: NSWindow?
    private var selectionView: ScreenshotSelectionView?
    private var eventMonitor: Any?
    private var screenCapture: ScreenCapture
    private var verboseLogging = true

    override init() {
        screenCapture = AVScreenCapture()
        super.init()
    }

    func captureInteractive() async -> NSImage? {
        return await withCheckedContinuation { continuation in
            startInteractiveCapture { image in
                continuation.resume(returning: image)
            }
        }
    }

    func startInteractiveCapture(completion: @escaping (NSImage?) -> Void) {
        DispatchQueue.main.async {
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
            
            // 统一处理键盘事件
            let keyHandler: (NSEvent) -> Void = { [weak self] event in
                guard let self = self else { return }
                if self.verboseLogging {
                    os_log("键盘事件: keyCode=%d", log: .default, type: .debug, event.keyCode)
                }
                switch event.keyCode {
                case 53: // ESC键
                    if self.verboseLogging {
                        os_log("用户按下ESC键，取消截图", log: .default, type: .info)
                    }
                    self.handleCancel(completion: completion)
                case 36: // Enter键
                    if self.verboseLogging {
                        os_log("用户按下Enter键，确认截图", log: .default, type: .info)
                    }
                    if let rect = self.selectionView?.currentRect {
                        self.handleSelection(rect: rect, completion: completion)
                    }
                default:
                    break
                }
            }

            // 修改鼠标移动事件处理
            // 添加标志位跟踪是否已点击
            var hasClicked = false

            self.eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .keyDown]) { [weak self] event in
                guard let self = self else { return event }
                
                switch event.type {
                case .mouseMoved where !hasClicked:
                    let mouseLocation = NSEvent.mouseLocation
                    if self.verboseLogging {
                        os_log("鼠标移动 - 位置: (%.1f, %.1f)", log: .default, type: .debug, mouseLocation.x, mouseLocation.y)
                    }
                    if let currentScreen = NSScreen.screens.first(where: { screen in
                        NSMouseInRect(mouseLocation, screen.frame, false)
                    }), currentScreen != self.selectionWindow?.screen {
                        os_log("屏幕切换 - 新屏幕: %{public}@ 分辨率: %.0fx%.0f", log: .default, type: .info,
                              currentScreen.localizedName, 
                              currentScreen.frame.width, 
                              currentScreen.frame.height)
                        self.createSelectionWindow(on: currentScreen, completion: completion)
                    }
                    
                case .leftMouseDown:
                    if self.verboseLogging {
                        os_log("鼠标左键点击", log: .default, type: .info)
                        os_log("移除鼠标移动监听，仅保留键盘监听", log: .default, type: .debug)
                    }
                    hasClicked = true
                    if let monitor = self.eventMonitor {
                        NSEvent.removeMonitor(monitor)
                    }
                    if self.verboseLogging {
                        os_log("移除鼠标移动监听，仅保留键盘监听", log: .default, type: .debug)
                    }
                    self.eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: keyHandler)
                    
                case .keyDown:
                    if self.verboseLogging {
                        os_log("键盘按下事件", log: .default, type: .debug)
                    }
                    keyHandler(event)
                    
                default:
                    break
                }
                return event
            }

            // 设置选择视图的回调
            self.selectionView?.selectionHandler = { rect in
                // 隐藏并销毁窗口
                self.selectionWindow?.orderOut(nil)
                self.selectionWindow = nil
                self.selectionView = nil

                NSCursor.pop()
                NSCursor.current.set()

                // 判断是否选择了有效区域(宽高都大于0)
                let captureRect = (rect.width > 0 && rect.height > 0) ? rect : NSScreen.main?.frame ?? .zero

                self.screenCapture.captureSelectedArea(captureRect) { image in
                    completion(image)
                }
            }

            // 设置取消处理逻辑
            self.selectionView?.cancelHandler = {
                self.selectionWindow?.orderOut(nil)
                self.selectionWindow = nil
                self.selectionView = nil
                NSCursor.pop()
                completion(nil)
            }
        }
    }

    @MainActor private func createSelectionWindow(on screen: NSScreen?, completion: @escaping (NSImage?) -> Void) {
        // 如果窗口已存在，先移除
        selectionWindow?.orderOut(nil)
        
        // 使用指定屏幕的frame
        let windowFrame = screen?.frame ?? NSScreen.main?.frame ?? .zero
        
        // 创建新窗口
        selectionWindow = NSWindow(
            contentRect: windowFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        selectionWindow?.level = .screenSaver
        selectionWindow?.isOpaque = false
        selectionWindow?.backgroundColor = NSColor.clear
        selectionWindow?.ignoresMouseEvents = false
        selectionWindow?.isReleasedWhenClosed = false
        selectionWindow?.acceptsMouseMovedEvents = true

        selectionView = ScreenshotSelectionView(frame: windowFrame)
        selectionWindow?.contentView = selectionView
        
        // 设置选择视图的回调
        selectionView?.selectionHandler = { [weak self] rect in
            guard let self = self else { return }
            self.selectionWindow?.orderOut(nil)
            self.selectionWindow = nil
            self.selectionView = nil
            NSCursor.pop()
            NSCursor.current.set()

            let captureRect = (rect.width > 0 && rect.height > 0) ? rect : NSScreen.main?.frame ?? .zero
            self.screenCapture.captureSelectedArea(captureRect) { image in
                DispatchQueue.main.async {
                    completion(image)
                }
            }
        }
        
        selectionView?.cancelHandler = { [weak self] in
            guard let self = self else { return }
            self.selectionWindow?.orderOut(nil)
            self.selectionWindow = nil
            self.selectionView = nil
            NSCursor.pop()
            DispatchQueue.main.async {
                completion(nil)
            }
        }
        
        selectionWindow?.makeKeyAndOrderFront(nil)
        
        // 确保窗口获得焦点
        NSApp.activate(ignoringOtherApps: true)
        selectionWindow?.makeFirstResponder(selectionView)
    }
    
    private func handleCancel(completion: @escaping (NSImage?) -> Void) {
        DispatchQueue.main.async {
            self.cleanup()
            completion(nil)
        }
    }
    
    private func handleSelection(rect: CGRect, completion: @escaping (NSImage?) -> Void) {
        DispatchQueue.main.async {
            self.cleanup()
            
            // 确保选择区域有效
            let captureRect = (rect.width > 0 && rect.height > 0) ? rect : NSScreen.screens.reduce(NSRect.zero) { result, screen in
                return result.union(screen.frame)
            }
            
            self.screenCapture.captureSelectedArea(captureRect, completion: completion)
        }
    }
    
    private func cleanup() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        selectionWindow?.orderOut(nil)
        selectionWindow = nil
        selectionView = nil
        NSCursor.pop()
    }
}

