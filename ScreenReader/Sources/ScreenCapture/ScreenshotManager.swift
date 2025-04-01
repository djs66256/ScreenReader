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
    private var verboseLogging = false

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
                        os_log("鼠标左键点击, 移除鼠标移动监听", log: .default, type: .debug)
                    }
                    hasClicked = true
                    if let monitor = self.eventMonitor {
                        NSEvent.removeMonitor(monitor)
                        self.eventMonitor = nil
                    }
                case .keyDown:
                    if self.verboseLogging {
                        os_log("键盘事件: keyCode=%d", log: .default, type: .debug, event.keyCode)
                    }
                    switch event.keyCode {
                    case 53: // ESC键
                        if self.verboseLogging {
                            os_log("用户按下ESC键，取消截图", log: .default, type: .info)
                        }
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

    @MainActor private func createSelectionWindow(on screen: NSScreen?, completion: @escaping (NSImage?) -> Void) {
        // 如果窗口已存在，先移除
        selectionWindow?.orderOut(nil)
        
        // 使用指定屏幕的frame
        let windowFrame = screen?.frame ?? NSScreen.main?.frame ?? .zero
        
        // 创建新窗口
        selectionWindow = CustomBorderlessWindow(
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
            self.cleanup()
            
            if let screen = screen ?? NSScreen.main {
                self.screenCapture.captureSelectedArea(rect, in: screen) { image in
                    DispatchQueue.main.async {
                        completion(image)
                    }
                }
            } else {
                // 当无法获取任何屏幕时的处理逻辑
                DispatchQueue.main.async {
                    completion(nil)
                }
                if self.verboseLogging {
                    os_log("无法获取屏幕信息，截图失败", log: .default, type: .error)
                }
            }
        }
        
        selectionView?.cancelHandler = { [weak self] in
            guard let self = self else { return }
            self.cleanup()
            DispatchQueue.main.async {
                completion(nil)
            }
        }
        
        selectionWindow?.makeKeyAndOrderFront(nil)
        
        // 确保窗口获得焦点
        NSApp.activate(ignoringOtherApps: true)
        selectionWindow?.makeFirstResponder(selectionView)
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

