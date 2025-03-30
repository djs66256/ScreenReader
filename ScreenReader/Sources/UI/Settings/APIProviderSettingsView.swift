import SwiftUI

struct APIProviderSettingsView: View {
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("API Providers")
               .font(.title)
               .fontWeight(.bold)
        }
    }
    
}

// 预览
struct APIProviderSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        APIProviderSettingsView()
    }
}
