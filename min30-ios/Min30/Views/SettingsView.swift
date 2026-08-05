import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(Store.self) private var store

    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var showWipeConfirm = false
    @State private var trace = ""

    var body: some View {
        Form {
            Section("알람") {
                HStack {
                    Circle()
                        .fill(authStatus == .authorized ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(statusText).font(.system(size: 13))
                }
                if authStatus != .authorized {
                    Button("알림 권한 켜기") {
                        Task { _ = await Notifier.shared.requestAuthorization(); await refresh() }
                    }
                }
                Button("테스트 알람 보내기 (3초 뒤)") { Notifier.shared.sendTest() }

                Picker("알람 간격", selection: intervalBinding) {
                    ForEach([15, 20, 25, 30, 45, 60], id: \.self) { Text("\($0)분").tag($0) }
                }
                timeRow("깨어있는 시작", \.dayStart)
                timeRow("종료", \.dayEnd)
                timeRow("저녁 리뷰 알람", \.reviewAt)

                Toggle("알람 소리", isOn: boolBinding(\.sound))
                Toggle("주말도 알람", isOn: boolBinding(\.weekend))
            }

            Section {
                Text("""
                알림을 길게 누르면 자주 쓰는 태그 3개와 “직전과 동일”, “아이디어 적기”가 \
                바로 떠요. 거기서 누르면 **앱을 열지 않고** 그 자리에서 기록돼요.
                """)
                .font(.system(size: 12)).foregroundStyle(.secondary)
                if !store.settings.weekend {
                    Text("""
                    주말 알람을 끄면 iOS의 예약 알림 64개 한도 때문에 앞으로 며칠치만 미리 \
                    걸어둬요. 앱을 며칠씩 한 번도 안 열면 알람이 끊길 수 있어요 — 주말도 \
                    켜두면 영구 반복이라 그럴 일이 없어요.
                    """)
                    .font(.system(size: 12)).foregroundStyle(.orange)
                }
            } header: {
                Text("알림에서 바로 기록")
            }

            Section("시간 분류 — 『원씽』 기준") {
                ForEach(Category.allCases) { c in
                    HStack(spacing: 11) {
                        Image(systemName: c.symbol).frame(width: 20).foregroundStyle(c.color)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(c.title).font(.system(size: 14, weight: .medium))
                            Text(c.blurb).font(.system(size: 11.5)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if c.buildsImpact {
                            Text("임팩트").font(.system(size: 10))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(c.color.opacity(0.18), in: Capsule())
                                .foregroundStyle(c.color)
                        }
                    }
                    .padding(.vertical, 2)
                }
                Text("""
                무엇을 했는지만 적으면 분류는 앱이 붙여요. 틀리면 한 번 고쳐 주세요 — \
                그 표현은 다음부터 기억합니다. 관리할 태그 목록은 따로 없어요.
                """)
                .font(.system(size: 11.5)).foregroundStyle(.tertiary)

                if !store.settings.learned.isEmpty {
                    Button("배운 분류 \(store.settings.learned.count)개 지우기", role: .destructive) {
                        store.settings.learned.removeAll()
                        store.save()
                    }
                    .font(.system(size: 13))
                }
            }

            Section("데이터") {
                Text("전부 이 기기 안에만 저장돼요. 서버로 아무것도 안 나가요.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                if let data = store.exportJSON(), let json = String(data: data, encoding: .utf8) {
                    ShareLink(item: json, preview: SharePreview("min30-backup.json")) {
                        Label("JSON 백업 내보내기", systemImage: "square.and.arrow.up")
                    }
                }
                ShareLink(item: store.exportCSV(), preview: SharePreview("min30.csv")) {
                    Label("CSV 내보내기", systemImage: "tablecells")
                }
                Text(storageLine).font(.system(size: 12)).foregroundStyle(.tertiary)
                Button("전체 초기화", role: .destructive) { showWipeConfirm = true }
            }

            traceSection

            Section("왜 이걸 쓰나") {
                Text("""
                ① 하루에서 **낭비 블록**을 눈에 보이게 만들어 제거하고
                ② 실제로 **임팩트 있는 일**에 시간을 썼는지 매일 확인하고
                ③ 스쳐 지나갈 **아이디어**를 잡아 콘텐츠·아이디어뱅크로 승격시키는 것.
                """)
                .font(.system(size: 12.5))
            }
        }
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refresh(); trace = Diag.trace }
        .confirmationDialog("모든 기록과 아이디어가 지워집니다.", isPresented: $showWipeConfirm, titleVisibility: .visible) {
            Button("전부 지우기", role: .destructive) {
                store.wipe()
                Task { await Notifier.shared.reschedule() }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("되돌릴 수 없어요. 먼저 내보내기를 권해요.")
        }
    }

    // MARK: 마지막 흔적

    /// 앱이 죽거나 굳었을 때, 죽기 직전까지 어디를 지나갔는지. 크래시는 메모리를
    /// 가져가지만 이미 디스크에 쓴 것은 못 가져간다 — 그래서 맥 없이도 원인을
    /// 넘겨줄 수 있다. 아무 일 없으면 이 칸은 아예 안 보인다.
    @ViewBuilder private var traceSection: some View {
        if !trace.isEmpty {
            Section("마지막 흔적") {
                Text("앱이 갑자기 꺼지거나 멈췄다면, 아래를 통째로 복사해서 보내 주세요. 어디서 그랬는지가 여기 남아 있어요.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)

                Text(trace)
                    .font(.system(size: 10.5, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ShareLink(item: trace, preview: SharePreview("min30-trace.txt")) {
                    Label("흔적 내보내기", systemImage: "square.and.arrow.up")
                }
                Button("흔적 지우기") {
                    Diag.clearTrace()
                    trace = ""
                }
            }
        }
    }

    // MARK: 바인딩

    private var intervalBinding: Binding<Int> {
        Binding(get: { store.settings.interval },
                set: { store.settings.interval = $0; store.save(); Task { await Notifier.shared.reschedule() } })
    }

    private func boolBinding(_ key: WritableKeyPath<Settings, Bool>) -> Binding<Bool> {
        Binding(get: { store.settings[keyPath: key] },
                set: { store.settings[keyPath: key] = $0; store.save(); Task { await Notifier.shared.reschedule() } })
    }

    /// Stored as minutes-from-midnight; surfaced as a normal time picker.
    private func timeRow(_ label: String, _ key: WritableKeyPath<Settings, Int>) -> some View {
        let binding = Binding<Date>(
            get: {
                let m = store.settings[keyPath: key]
                return Calendar.current.date(bySettingHour: (m / 60) % 24, minute: m % 60, second: 0, of: Date()) ?? Date()
            },
            set: { d in
                let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                store.settings[keyPath: key] = (c.hour ?? 0) * 60 + (c.minute ?? 0)
                store.save()
                Task { await Notifier.shared.reschedule() }
            }
        )
        return DatePicker(label, selection: binding, displayedComponents: .hourAndMinute)
    }

    private var statusText: String {
        switch authStatus {
        case .authorized, .provisional, .ephemeral: return "알림 켜짐 — \(store.settings.interval)분마다 울립니다"
        case .denied: return "알림이 꺼져 있어요 — 설정 앱에서 켜 주세요"
        default: return "알림 권한이 아직 없어요"
        }
    }

    private var storageLine: String {
        let blocks = store.entries.values.reduce(0) { $0 + $1.count }
        return "블록 \(blocks)개 · 아이디어 \(store.ideas.count)개"
    }

    private func refresh() async {
        authStatus = await Notifier.shared.authorizationStatus()
    }
}
