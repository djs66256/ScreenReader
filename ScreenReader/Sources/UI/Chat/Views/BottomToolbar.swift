import SwiftUI

struct BottomToolbar: View {
    @ObservedObject var viewModel: InputMessageViewModel
    var sendMessage: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // 图片按钮
            Button(action: {
                let openPanel = NSOpenPanel()
                openPanel.allowsMultipleSelection = true
                openPanel.canChooseFiles = true
                openPanel.canChooseDirectories = false
                openPanel.allowedContentTypes = [.image]
                
                if openPanel.runModal() == .OK {
                    for url in openPanel.urls {
                        if let image = NSImage(contentsOf: url) {
                            viewModel.addImage(image)
                        }
                    }
                }
            }) {
                Image(systemName: "photo")
                    .font(.system(size: 14))
                    .foregroundColor(Color(.secondaryLabelColor))
                    .padding(6)
            }
            .buttonStyle(.plain)
            
            // 截图按钮
            Button(action: {
                // TODO: 实现截图功能
            }) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 14))
                    .foregroundColor(Color(.secondaryLabelColor))
                    .padding(6)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // 模型选择
            Menu {
                ForEach(viewModel.chatModes, id: \.id) { mode in
                    Button(action: {
                        viewModel.selectedModel = mode
                    }) {
                        Text(mode.name)
                    }
                }
            } label: {
                ZStack {
                    Text(viewModel.selectedModel?.name ?? "选择模型")
                        .foregroundColor(Color(.labelColor))
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // 透明背景覆盖默认样式
                    Color.clear
                        .contentShape(Rectangle())
                }
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)
            }
            .frame(width: 120)
            .menuStyle(BorderlessButtonMenuStyle()) // 移除默认菜单样式
            .padding(6)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.separatorColor), lineWidth: 0.5)
            )
            
            // 发送按钮
            Button(action: sendMessage) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 12))
                    .padding(6)
                    .background(
                        Circle()
                            .fill(Color.accentColor)
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    )
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .background(Color(.windowBackgroundColor))
    }
}

struct BottomToolbar_Previews: PreviewProvider {
    static var previews: some View {
        let mockViewModel = InputMessageViewModel.mock()
        
        return Group {
            BottomToolbar(viewModel: mockViewModel, sendMessage: {})
                .previewDisplayName("默认状态")
        }
        .frame(width: 400)
        .previewLayout(.sizeThatFits)
    }
}
