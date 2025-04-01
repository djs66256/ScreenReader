import Foundation
import Cocoa

protocol ScreenCapture {
    func captureSelectedArea(_ rect: CGRect, completion: @escaping (NSImage?) -> Void)
}
