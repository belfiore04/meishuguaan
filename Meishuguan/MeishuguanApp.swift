import SwiftUI

@main
struct MeishuguanApp: App {
    @State private var session = SessionState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(session)
                .preferredColorScheme(.light)
                .tint(.primary)
                .task {
                    // 内存版还没持久化，每次启动空状态都注入 mock 展品。
                    // 等持久化做完，改成"首次启动才 seed"。
                    if session.exhibits.isEmpty {
                        session.exhibits = SeedData.makeMockExhibits()
                    }
                }
        }
    }
}
