import Cocoa

class CustomBorderlessWindow: NSWindow {
    override var canBecomeMain: Bool {
        return true
    }
    
    override var canBecomeKey: Bool {
        return true
    }
}