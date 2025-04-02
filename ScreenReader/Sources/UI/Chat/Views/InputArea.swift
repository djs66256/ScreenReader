import SwiftUI

struct InputArea: View {
    @ObservedObject var viewModel: InputMessageViewModel
    var sendMessage: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.displayedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.displayedImages.indices, id: \.self) { index in
                            let image = viewModel.displayedImages[index]
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 60, height: 60)
                                .cornerRadius(4)
                                .overlay(
                                    Button(action: {
                                        viewModel.removeImage(at: index)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(.white)
                                            .background(Color.black.opacity(0.6))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .padding(2),
                                    alignment: .topTrailing
                                )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                }
                .background(Color(.windowBackgroundColor))
            }
            
            HStack(alignment: .bottom, spacing: 8) {
                TextEditor(text: $viewModel.textInput)
                    .frame(minHeight: 40, maxHeight: 16 * 4 + 2 * 5)
                    .padding(8)
                    .font(.system(size: 16))
                    .lineSpacing(2)
                    .scrollIndicators(.never)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.controlBackgroundColor))
                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.separatorColor).opacity(0.5), lineWidth: 1)
                    )
//                    .focused($viewModel.isInputFocused)
                    .scrollContentBackground(.hidden)
                    .onSubmit {
                        if !isShiftKeyPressed() {
                            sendMessage()
                        }
                    }
                    .onChange(of: viewModel.textInput) { _ in
                        DispatchQueue.main.async {
                            if viewModel.textInput.last == "\n" && !isShiftKeyPressed() {
                                viewModel.textInput.removeLast()
                                sendMessage()
                            }
                        }
                    }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(Color(.windowBackgroundColor))
            .onAppear {
                viewModel.isInputFocused = true
            }
        }
    }
    
    private func isShiftKeyPressed() -> Bool {
        #if os(macOS)
        return NSEvent.modifierFlags.contains(.shift)
        #else
        return false
        #endif
    }
}

struct InputArea_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            InputArea(viewModel: .mock(), sendMessage: {})
                .previewDisplayName("默认状态")
        }
        .frame(width: 400)
        .previewLayout(.sizeThatFits)
    }
}
