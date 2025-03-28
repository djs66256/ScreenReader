import AppKit

public class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController()
    }
}
