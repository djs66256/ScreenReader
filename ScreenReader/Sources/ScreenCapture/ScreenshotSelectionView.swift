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
            let backgroundPath = NSBezierPath(rect: bounds)
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
            
            // 绘制尺寸信息
            drawSizeInfo(for: rect)
        } else {
            NSColor.black.withAlphaComponent(0.3).setFill()
            bounds.fill()
        }
    }
    
    // 添加尺寸信息显示
    private func drawSizeInfo(for rect: NSRect) {
        let sizeString = "\(Int(rect.width)) × \(Int(rect.height))"
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.7),
            .font: NSFont.systemFont(ofSize: 12)
        ]
        
        let stringSize = sizeString.size(withAttributes: attributes)
        var infoRect = NSRect(
            x: rect.midX - stringSize.width / 2,
            y: rect.maxY + 5,
            width: stringSize.width + 10,
            height: stringSize.height + 5
        )
        
        // 确保信息框在视图范围内
        if infoRect.maxY > bounds.maxY {
            infoRect.origin.y = rect.minY - infoRect.height - 5
        }
        
        // 绘制背景和文本
        NSBezierPath(roundedRect: infoRect, xRadius: 3, yRadius: 3).fill()
        sizeString.draw(
            at: NSPoint(x: infoRect.midX - stringSize.width / 2, y: infoRect.midY - stringSize.height / 2),
            withAttributes: attributes
        )
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
        
        // 计算选择区域，考虑多屏幕坐标
        let originX = min(start.x, currentPoint.x)
        let originY = min(start.y, currentPoint.y)
        let width = abs(currentPoint.x - start.x)
        let height = abs(currentPoint.y - start.y)
        
        currentRect = NSRect(x: originX, y: originY, width: width, height: height)
        
        // 确保选择区域在所有屏幕的总边界内
        if let window = self.window {
            let screenRect = NSScreen.screens.reduce(NSRect.zero) { result, screen in
                return result.union(screen.frame)
            }
            let windowRect = window.convertToScreen(self.convert(currentRect!, to: nil))
            
            // 如果选择区域超出屏幕边界，进行调整
            if !screenRect.contains(windowRect) {
                let adjustedRect = windowRect.intersection(screenRect)
                currentRect = self.convert(window.convertFromScreen(adjustedRect), from: nil)
            }
        }
        
        needsDisplay = true
    }
    
    override func keyDown(with event: NSEvent) {
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
    
}
