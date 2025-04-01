import Foundation
import Cocoa

protocol ScreenCapture {
    func captureSelectedArea(_ rect: CGRect?, in screen: NSScreen, completion: @escaping (NSImage?) -> Void)
}
