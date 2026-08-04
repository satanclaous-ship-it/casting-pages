import SwiftUI
import AppIntents

@main
struct Min30App: App {
    @State private var store = Store.shared
    @State private var router = Router.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        Notifier.shared.bootstrap()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(router)
                .task {
                    // A notification action may have written from a background
                    // launch since this process last read the file.
                    store.reloadFromDisk()
                    await Notifier.shared.reschedule()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        store.reloadFromDisk()
                        Task { await Notifier.shared.reschedule() }
                    }
                }
        }
    }
}

struct RootView: View {
    @Environment(Router.self) private var router
    @State private var showCapture = false

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.tab) {
            NavigationStack { LogView() }
                .tabItem { Label("기록", systemImage: "square.and.pencil") }
                .tag(0)

            NavigationStack { IdeasView() }
                .tabItem { Label("아이디어", systemImage: "lightbulb") }
                .tag(1)

            NavigationStack { ReviewView() }
                .tabItem { Label("리뷰", systemImage: "chart.bar.xaxis") }
                .tag(2)

            NavigationStack { SettingsView() }
                .tabItem { Label("설정", systemImage: "gearshape") }
                .tag(3)
        }
        .overlay(alignment: .bottomTrailing) {
            // Ideas don't wait for the alarm — reachable from every tab.
            Button { showCapture = true } label: {
                Label("아이디어", systemImage: "lightbulb.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 18)
                    .frame(height: 50)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(.white)
                    .shadow(radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 16)
            .padding(.bottom, 66)
        }
        .sheet(isPresented: $showCapture) { CaptureSheet() }
    }
}

// MARK: - Siri · 단축어

/// "시리야, 아이디어 담아" — the capture path that needs no screen at all.
struct CaptureIdeaIntent: AppIntent {
    static var title: LocalizedStringResource = "아이디어 담기"
    static var description = IntentDescription("떠오른 아이디어를 30분 기록의 수집함에 넣습니다.")
    static var openAppWhenRun = false

    @Parameter(title: "아이디어", requestValueDialog: "무엇이 떠올랐나요?")
    var text: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        Store.shared.reloadFromDisk()
        Store.shared.addIdea(text)
        return .result(dialog: "수집함에 담았어요.")
    }
}

/// "시리야, 개발 기록해" — logs the current block without opening anything.
struct LogBlockIntent: AppIntent {
    static var title: LocalizedStringResource = "지금 블록 기록"
    static var description = IntentDescription("지금 30분 블록에 활동을 기록합니다.")
    static var openAppWhenRun = false

    @Parameter(title: "무엇을 했나", requestValueDialog: "뭐 하고 있었어요?")
    var activity: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = Store.shared
        store.reloadFromDisk()
        let day = store.logicalDay()
        let slot = store.currentSlot()
        let cat = store.quickTags(limit: 40).first { $0.name == activity }?.category
        let prev = store.previousEntry(day: day, before: slot)
        store.put(day: day, slot: slot) {
            $0.activity = activity
            $0.category = cat
            $0.impact = cat?.defaultImpact ?? 1
            $0.energy = prev?.energy ?? 0
            $0.focus = prev?.focus ?? 0
            $0.skipped = false
        }
        store.rememberTag(activity, cat)
        return .result(dialog: "\(Fmt.hhmm(slot)) 블록에 기록했어요.")
    }
}

struct Min30Shortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CaptureIdeaIntent(),
            phrases: ["\(.applicationName)에 아이디어 담아", "\(.applicationName) 아이디어"],
            shortTitle: "아이디어 담기",
            systemImageName: "lightbulb"
        )
        AppShortcut(
            intent: LogBlockIntent(),
            phrases: ["\(.applicationName)에 기록해", "\(.applicationName) 기록"],
            shortTitle: "지금 블록 기록",
            systemImageName: "square.and.pencil"
        )
    }
}
