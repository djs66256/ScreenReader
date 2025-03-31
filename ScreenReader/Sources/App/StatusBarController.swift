import AppKit
import SwiftUI

public class StatusBarController: NSObject {
    private var statusItem: NSStatusItem!
    
    public override init() {
        super.init()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "Screen Reader")
        
        let menu = NSMenu()
        
        // 新增打开聊天按钮
        let chatItem = NSMenuItem(title: "打开聊天", action: #selector(openChat), keyEquivalent: "c")
        chatItem.target = self
        menu.addItem(chatItem)
        
        let captureItem = NSMenuItem(title: "截图分析", action: #selector(captureScreen), keyEquivalent: "s")
        captureItem.target = self
        menu.addItem(captureItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(title: "设置", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    @objc func captureScreen() {
        Task {
            if let image = await ScreenshotManager.shared.captureInteractive() {
                // 获取图片数据
                guard let imageData = image.tiffRepresentation else { return }
                
                // 在主线程打开窗口
                await MainActor.run {
                    NSApp.activate(ignoringOtherApps: true)
                    let chatWindow = NSWindow(
                        contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                        styleMask: [.titled, .closable, .miniaturizable, .resizable],
                        backing: .buffered,
                        defer: false
                    )
                    chatWindow.title = "截图分析"
                    chatWindow.center()
                    
                    // 创建 ChatViewModel 和 InputMessageViewModel
                    let chatViewModel = ChatViewModel()
                    let inputViewModel = InputMessageViewModel()
                    
                    // 将截图添加到输入视图模型
                    inputViewModel.addImage(image)
                    
                    // 创建 ChatView 并传递视图模型
                    let chatView = ChatView(viewModel: chatViewModel, inputViewModel: inputViewModel)
                    
                    chatWindow.contentView = NSHostingView(rootView: chatView)
                    chatWindow.makeKeyAndOrderFront(nil)
                    
                    // 保持窗口引用，防止被释放
                    chatWindow.isReleasedWhenClosed = false
                }
            }
        }
    }
    
    @objc func openSettings() {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            let settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow.title = "设置"
            settingsWindow.center()
            
            let settingsView = SettingsContainer()
            settingsWindow.contentView = NSHostingView(rootView: settingsView)
            settingsWindow.makeKeyAndOrderFront(nil)
            
            // 保持窗口引用，防止被释放
            settingsWindow.isReleasedWhenClosed = false
        }
    }
    
    @objc func quitApp() {
        NSApp.terminate(nil)
    }
    
    @objc func openChat() {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            let chatWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            chatWindow.title = "聊天"
            chatWindow.center()
            
            let chatView = ChatView()
            chatWindow.contentView = NSHostingView(rootView: chatView)
            chatWindow.makeKeyAndOrderFront(nil)
            
            // 保持窗口引用，防止被释放
            chatWindow.isReleasedWhenClosed = false
        }
    }
}
