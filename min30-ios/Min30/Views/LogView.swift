import SwiftUI
import Combine

/// 두 단계로 나뉜다. 한 화면에 다 넣으면 스크롤을 내려야 하고, 스크롤을
/// 내려야 하는 입력은 30분마다 하지 않게 된다.
///   1단계 — 무엇을 했나 (분류는 앱이 알아서 붙인다)
///   2단계 — 에너지 · 집중력
struct LogView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router

    private enum Step { case what, how }

    @State private var step: Step = .what
    @State private var editDay = Store.shared.logicalDay()
    @State private var editSlot = Store.shared.currentSlot()

    @State private var activity = ""
    @State private var level = 0
    @State private var note = ""

    @State private var showRecent = false
    @State private var showNote = false
    @State private var editingOneThing = false
    @State private var oneThingDraft = ""

    @State private var dictation = Dictation()
    @State private var toast: String?
    @FocusState private var activityFocused: Bool

    /// `@State` 여야 한다. `let` 으로 두면 뷰 구조체가 다시 만들어질 때마다 —
    /// SwiftUI 에서는 수시로 일어난다 — 새 타이머 퍼블리셔가 생기고 onReceive 가
    /// 매번 구독을 갈아치운다. 한 번 만들어 두고 계속 쓴다.
    @State private var tick = Timer.publish(every: 20, on: .main, in: .common).autoconnect()

    var body: some View {
        let _ = Diag.beat("LogView.body")
        ScrollView {
            VStack(spacing: 14) {
                catchUpCard
                switch step {
                case .what: whatCard
                case .how:  howCard
                }
                timelineCard
            }
            .cardStack()
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("기록")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) { toastView }
        .onAppear { seat(day: store.logicalDay(), slot: store.currentSlot()) }
        .onReceive(tick) { _ in followClock() }
        .onChange(of: router.pendingSlot) { _, new in
            if let new {
                Diag.span("pendingSlot→seat(\(new))") {
                    seat(day: store.logicalDay(), slot: new)
                }
                router.pendingSlot = nil
            }
        }
    }

    // MARK: 밀린 블록

    @ViewBuilder private var catchUpCard: some View {
        let missed = store.catchUpSlots()
        if !missed.isEmpty && step == .what {
            Card {
                HStack(alignment: .top, spacing: 9) {
                    Text("⏳")
                    VStack(alignment: .leading, spacing: 8) {
                        Text(store.hasLoggedToday
                             ? "밀린 블록 \(missed.count)개"
                             : "아직 오늘 기록이 없어요. 방금 지나간 \(missed.count)개부터?")
                            .font(.system(size: 13))
                        Button(store.hasLoggedToday ? "가장 오래된 것부터" : "지금부터 시작") {
                            seat(day: store.logicalDay(), slot: missed[0])
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    // MARK: 1단계 — 무엇을 했나

    private var whatCard: some View {
        Card {
            slotHeader
            oneThingRow

            VStack(alignment: .leading, spacing: 8) {
                FieldLabel(text: "무엇을 했나")
                TextField("예: 온보딩 화면 작업", text: $activity)
                    .textFieldStyle(.roundedBorder)
                    .focused($activityFocused)
                    .submitLabel(.next)
                    .onSubmit { advance() }
                MicButton(dictation: dictation, large: true, seed: { activity }) { activity = $0 }
            }

            recentToggle

            Button(action: advance) {
                HStack {
                    Text("다음")
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(activity.trimmingCharacters(in: .whitespaces).isEmpty)

            Button("이 블록 건너뛰기") { skip() }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(maxWidth: .infinity)
        }
    }

    /// 최근 것들은 접어 둔다 — 필요할 때만 편다.
    @ViewBuilder private var recentToggle: some View {
        let recent = store.recentActivities()
        if !recent.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { showRecent.toggle() }
                } label: {
                    HStack(spacing: 5) {
                        Text("최근에 한 것")
                        Image(systemName: showRecent ? "chevron.up" : "chevron.down")
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                if showRecent {
                    FlowLayout(spacing: 6) {
                        ForEach(recent, id: \.name) { r in
                            Button {
                                activity = r.name
                                activityFocused = false
                            } label: {
                                HStack(spacing: 6) {
                                    Circle().fill(r.category?.color ?? .secondary).frame(width: 7, height: 7)
                                    Text(r.name).font(.system(size: 13)).lineLimit(1)
                                }
                                .padding(.horizontal, 11)
                                .padding(.vertical, 8)
                                .background(Color(.secondarySystemBackground), in: Capsule())
                                .foregroundStyle(Color.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: 2단계 — 에너지 · 집중력

    private var howCard: some View {
        Card {
            HStack {
                Button {
                    withAnimation { step = .what }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("고치기")
                    }
                    .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                Spacer()
                Text("\(Fmt.hhmm(editSlot))–\(Fmt.hhmm(editSlot + editSlotLength))")
                    .font(.system(size: 13)).monospacedDigit().foregroundStyle(.tertiary)
            }

            // 분류는 여기서 안 묻는다. 저녁 리뷰에서 하루치를 한 번에 본다.
            Text(activity)
                .font(.system(size: 18, weight: .semibold))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                FieldLabel(text: "집중력")
                ScalePicker(labels: Scale.level, value: $level)
            }

            noteSection

            Button(action: saveEntry) {
                Text(store.entry(editDay, editSlot)?.isLogged == true ? "수정 저장" : "저장")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(showNote ? "－ 노트 접기" : "＋ 노트 · 아이디어") { withAnimation { showNote.toggle() } }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(maxWidth: .infinity)

            if showNote {
                TextField("이 순간 스친 생각, 막힌 지점…", text: $note, axis: .vertical)
                    .lineLimit(2...5)
                    .textFieldStyle(.roundedBorder)
                Text("“아이디어:” 로 시작하면 아이디어함에도 같이 들어가요")
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: 오늘의 원씽

    @ViewBuilder private var oneThingRow: some View {
        let current = store.oneThing(editDay)
        if editingOneThing {
            VStack(alignment: .leading, spacing: 8) {
                FieldLabel(text: "오늘의 원씽 — 이걸 하면 나머지가 쉬워지는 하나")
                TextField("예: 앱스토어 제출", text: $oneThingDraft)
                    .textFieldStyle(.roundedBorder)
                HStack(spacing: 6) {
                    Button("취소") { editingOneThing = false }
                        .buttonStyle(.bordered).controlSize(.small)
                    Button("저장") {
                        store.setOneThing(oneThingDraft, for: editDay)
                        editingOneThing = false
                    }
                    .buttonStyle(.borderedProminent).controlSize(.small)
                }
            }
        } else {
            Button {
                oneThingDraft = current
                editingOneThing = true
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "target").font(.system(size: 11))
                    Text(current.isEmpty ? "오늘의 원씽 정하기" : current)
                        .font(.system(size: 12))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(current.isEmpty ? Color.secondary : Category.onething.color)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: 오늘 타임라인

    private var timelineCard: some View {
        let day = store.logicalDay()
        let nowOff = store.offset()
        let nowSlot = store.currentSlot()
        let all = store.slots
        let done = all.filter { store.entry(day, $0) != nil }.count
        let past = all.filter { $0 + store.settings.interval <= nowOff }.count

        return Card(title: "오늘", subtitle: past > 0 ? "\(done)/\(past) 기록됨" : "아직 시작 전") {
            VStack(spacing: 5) {
                ForEach(all, id: \.self) { slot in
                    let e = store.entry(day, slot)
                    Button {
                        seat(day: day, slot: slot)
                    } label: {
                        HStack(spacing: 10) {
                            Text(Fmt.hhmm(slot))
                                .font(.system(size: 12)).monospacedDigit()
                                .foregroundStyle(.tertiary)
                                .frame(width: 44, alignment: .leading)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(e?.category?.color ?? Color.secondary.opacity(0.25))
                                .frame(width: 4, height: 24)
                            if let e, e.skipped {
                                Text("건너뜀").font(.system(size: 14)).foregroundStyle(.tertiary)
                            } else if let e, e.isLogged {
                                Text(e.activity).font(.system(size: 14)).lineLimit(1)
                            } else {
                                Text(slot > nowOff ? "—" : "비어 있음")
                                    .font(.system(size: 14)).foregroundStyle(.tertiary)
                            }
                            Spacer(minLength: 4)
                            if let e, e.isLogged {
                                Text(e.level > 0 ? "집중 \(e.level)" : "집중 –")
                                    .font(.system(size: 11)).monospacedDigit().foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color(.secondarySystemBackground).opacity(e == nil ? 0 : 1),
                                    in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(slot == nowSlot ? Color.accentColor : Color.primary.opacity(0.07),
                                              lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var slotHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Fmt.hhmm(editSlot))–\(Fmt.hhmm(editSlot + editSlotLength))")
                    .font(.system(size: 24, weight: .bold))
                Text(slotCaption).font(.system(size: 12)).foregroundStyle(.tertiary)
            }
            Spacer()
            Button { move(-1) } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.bordered).controlSize(.small)
            Button { move(1) } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.bordered).controlSize(.small)
        }
    }

    @ViewBuilder private var toastView: some View {
        if let toast {
            Text(toast)
                .font(.system(size: 13))
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, 12)
                .transition(.opacity)
        }
    }

    // MARK: 동작

    private var editSlotLength: Int {
        store.entry(editDay, editSlot).map { store.minutes(of: $0) } ?? store.settings.interval
    }

    private var slotCaption: String {
        if editDay != store.logicalDay() { return Fmt.pretty(editDay) }
        let now = store.currentSlot()
        if editSlot == now { return "지금 블록" }
        return editSlot < now ? "지난 블록" : "앞으로"
    }

    private func advance() {
        guard !activity.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        activityFocused = false
        dictation.stop()
        withAnimation(.easeInOut(duration: 0.2)) { step = .how }
    }

    /// 빈 블록이면 에너지·집중력을 직전 블록에서 이어받는다. 30분 사이엔 거의
    /// 안 변하는 값이고, 눌린 상태로 보이니 틀리면 한 번 탭해서 고치면 된다.
    private func seat(day: String, slot: Int) {
        dictation.stop()
        dictation.reset()
        editDay = day
        editSlot = slot
        step = .what
        showRecent = false
        editingOneThing = false

        let e = store.entry(day, slot)
        activity = e?.activity ?? ""
        note = e?.note ?? ""
        showNote = !(e?.note ?? "").isEmpty
        if let e {
            level = e.level
        } else if let prev = store.entry(day, slot - store.settings.interval), !prev.skipped {
            level = prev.level
        } else {
            level = 0
        }
    }

    private var draftIsClean: Bool {
        guard let e = store.entry(editDay, editSlot) else {
            return activity.trimmingCharacters(in: .whitespaces).isEmpty
                && note.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return activity == e.activity && note == e.note
            && level == e.level
    }

    /// 블록 경계를 넘어가면 편집 화면도 따라간다. 단 입력 중이면 건드리지 않는다.
    private func followClock() {
        let today = store.logicalDay()
        let now = store.currentSlot()
        guard editDay == today, editSlot != now, draftIsClean,
              !dictation.isRecording, !activityFocused, step == .what else { return }
        seat(day: today, slot: now)
    }

    private func move(_ dir: Int) {
        let all = store.slots
        guard let i = all.firstIndex(of: editSlot) else {
            seat(day: store.logicalDay(), slot: store.currentSlot())
            return
        }
        let j = i + dir
        if j < 0 {
            seat(day: Store.addDays(editDay, -1), slot: all[all.count - 1])
        } else if j >= all.count {
            seat(day: Store.addDays(editDay, 1), slot: all[0])
        } else {
            seat(day: editDay, slot: all[j])
        }
    }

    private func saveEntry() {
        let act = activity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !act.isEmpty else { return }
        let existing = store.entry(editDay, editSlot)
        // 분류는 제안만 넣어 두고 확정하지 않는다. 저녁 리뷰에서 하루치를 한 번에
        // 확인한다 — 30분마다 분류를 결정하게 하면 기록 자체를 안 하게 된다.
        let suggested = store.autoClassify(act, day: editDay)
        store.put(day: editDay, slot: editSlot) {
            $0.activity = act
            $0.focus = level
            $0.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            $0.skipped = false
            // 이미 리뷰에서 확정한 블록을 고치는 중이면 그 분류를 존중한다
            if existing?.categoryConfirmed != true {
                $0.category = suggested
                $0.categoryConfirmed = false
                $0.impact = suggested.legacyImpact
            }
        }

        var msg = "저장됐어요"
        if let range = note.range(of: #"^\s*아이디어\s*[:：]\s*"#, options: .regularExpression) {
            store.addIdea(String(note[range.upperBound...]), fromPing: true)
            msg = "저장 · 아이디어함에도"
        }
        flash(store.lastSaveFailed ? "저장 실패 — 기기 저장 공간을 확인해 주세요" : msg)
        Task { await Notifier.shared.reschedule() }
        advanceAfterSave()
    }

    private func advanceAfterSave() {
        let all = store.slots
        let isToday = editDay == store.logicalDay()
        let nowOff = store.offset()
        let next = all.first {
            $0 > editSlot && store.entry(editDay, $0) == nil
                && (!isToday || $0 + store.settings.interval <= nowOff)
        }
        seat(day: editDay, slot: next ?? (isToday ? store.currentSlot() : editSlot))
    }

    private func skip() {
        store.skip(day: editDay, slot: editSlot)
        flash("건너뛰었어요")
        let all = store.slots
        if let i = all.firstIndex(of: editSlot) {
            seat(day: editDay, slot: all[min(all.count - 1, i + 1)])
        }
    }

    private func flash(_ msg: String) {
        withAnimation { toast = msg }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { toast = nil }
        }
    }
}
