import SwiftUI

@main
struct MeishuguanApp: App {
    @State private var session = SessionState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(session)
                .tint(.primary)
        }
    }
}
