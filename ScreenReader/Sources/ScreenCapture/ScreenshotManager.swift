import ScreenCaptureKit
import Foundation
import Cocoa
import AVFoundation
import CoreGraphics

class ScreenshotManager: NSObject {
    static let shared = ScreenshotManager()
    private var selectionWindow: NSWindow?
    private var selectionView: ScreenshotSelectionView?
    private var eventMonitor: Any?
    private var screenCapture: ScreenCapture

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
            self.createSelectionWindow()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                NSCursor.crosshair.push()
                NSCursor.current.set()

                // 添加全局键盘事件监听
                self.eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                    switch event.keyCode {
                    case 53: // ESC键
                        self?.handleCancel(completion: completion)
                    case 36: // Enter键
                        if let rect = self?.selectionView?.currentRect {
                            self?.handleSelection(rect: rect, completion: completion)
                        }
                    default:
                        break
                    }
                }

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

                // 添加取消处理逻辑
                self.selectionView?.cancelHandler = {
                    self.selectionWindow?.orderOut(nil)
                    self.selectionWindow = nil
                    self.selectionView = nil
                    NSCursor.pop()
                    completion(nil)
                }
            }
        }
    }

    @MainActor private func createSelectionWindow() {
        guard let screen = NSScreen.main else { return }
        
        selectionWindow = NSWindow(
            contentRect: screen.frame,
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

        selectionView = ScreenshotSelectionView(frame: screen.frame)
        selectionWindow?.contentView = selectionView
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
            self.selectionView?.selectionHandler = { [weak self] rect in
                    guard let self = self else { return }
                    self.cleanup()
                    
                    let captureRect = (rect.width > 0 && rect.height > 0) ? rect : NSScreen.main?.frame ?? .zero
                    self.screenCapture.captureSelectedArea(captureRect, completion: completion)
                }
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

