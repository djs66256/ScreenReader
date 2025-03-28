import Cocoa
import AppKit

class ScreenshotSelectionView: NSView {
    var selectionHandler: ((CGRect) -> Void)?
    var cancelHandler: (() -> Void)?  // 新增取消回调
    private var startPoint: NSPoint?
    var currentRect: NSRect?
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // 绘制选择框
        if let rect = currentRect {
            // 创建挖孔效果
            let backgroundPath = NSBezierPath(rect: dirtyRect)
            let selectionPath = NSBezierPath(rect: rect)
            backgroundPath.append(selectionPath)
            backgroundPath.windingRule = .evenOdd
            
            // 填充挖孔区域
            NSColor.black.withAlphaComponent(0.3).setFill()
            backgroundPath.fill()
            
            // 绘制白色边框
            NSColor.white.setStroke()
            selectionPath.lineWidth = 2.0
            selectionPath.stroke()
        } else {
            NSColor.black.withAlphaComponent(0.3).setFill()
            dirtyRect.fill()
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        print("Global key pressed: \(event.keyCode)")
        
        switch event.keyCode {
        case 53: // ESC键
            print("ESC pressed globally")
            currentRect = nil
            cancelHandler?()
            needsDisplay = true
            
        case 36: // Enter键
            print("Enter pressed globally")
            if let rect = currentRect {
                selectionHandler?(rect)
                currentRect = nil
                needsDisplay = true
            }
            
        default:
            break
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 && currentRect != nil {
            // 双击确认选择
            if let rect = currentRect {
                selectionHandler?(rect)
                currentRect = nil
                needsDisplay = true
            }
        } else if event.clickCount == 1 {
            // 单击开始新选择
            startPoint = convert(event.locationInWindow, from: nil)
            // currentRect = NSRect(origin: startPoint!, size: .zero)
            // needsDisplay = true
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        // 第一次鼠标抬起时不处理，等待双击
        // 仅更新显示状态
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        let currentPoint = convert(event.locationInWindow, from: nil)
        
        let originX = min(start.x, currentPoint.x)
        let originY = min(start.y, currentPoint.y)
        let width = abs(currentPoint.x - start.x)
        let height = abs(currentPoint.y - start.y)
        
        currentRect = NSRect(x: originX, y: originY, width: width, height: height)
        needsDisplay = true
    }
    
}
