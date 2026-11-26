import SwiftUI

@main
struct MonicaApp: App {
    var body: some Scene {
        WindowGroup {
            Greeting()
        }
    }
}

struct Greeting: View {
    var body: some View {
        Text("welcome")
    }
}

#Preview {
    Greeting()
}
