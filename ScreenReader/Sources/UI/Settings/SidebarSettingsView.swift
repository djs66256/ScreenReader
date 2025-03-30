import SwiftUI

struct SidebarSettingsView<Item: Identifiable & Hashable, LeftContent: View, RightContent: View, BottomContent: View>: View {
    @Binding var items: [Item]
    @Binding var selection: Item?  // 改为绑定
    let leftContent: (Item) -> LeftContent
    let rightContent: (Item) -> RightContent
    let bottomContent: () -> BottomContent
    
    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                List(selection: $selection) {
                    ForEach(items) { item in
                        leftContent(item)
                            .tag(item)
                    }
                }
                .listStyle(.sidebar)
                .frame(width: 200)

                Spacer()
                
                bottomContent()
                    .frame(width: 200)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
            }

            Divider()
            
            if let selectedItem = selection {
                rightContent(selectedItem)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(selectedItem.id)
            } else {
                Text("请选择设置项")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

#if DEBUG
struct SidebarSettingsView_Previews: PreviewProvider {
    struct PreviewItem: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let icon: String
    }

    static var previews: some View {
        @State var items = [
            PreviewItem(name: "API设置", icon: "cloud"),
            PreviewItem(name: "聊天模式", icon: "message"),
            PreviewItem(name: "系统规则", icon: "gear")
        ]
        
        @State var selection: PreviewItem? = items.first

        return Group {
            SidebarSettingsView(
                items: $items,
                selection: $selection,
                leftContent: { item in
                    HStack {
                        Image(systemName: item.icon)
                        Text(item.name)
                    }
                },
                rightContent: { item in
                    VStack {
                        Text(item.name)
                            .font(.title)
                        Text("这是\(item.name)的详细设置内容")
                    }
                    .padding()
                },
                bottomContent: {
                    Button(action: {}) {
                        Image(systemName: "plus")
                            .frame(width: 40)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                }
            )
            .previewDisplayName("默认选中第一个")
        }
        .frame(width: 800, height: 600)
    }
}
#endif
