import SwiftUI
import Combine

struct LogView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router

    @State private var editDay = Store.shared.logicalDay()
    @State private var editSlot = Store.shared.currentSlot()

    @State private var activity = ""
    @State private var category: Category?
    @State private var energy = 0
    @State private var focus = 0
    @State private var impact = -1
    @State private var note = ""
    @State private var showNote = false

    @State private var dictation = Dictation()
    @State private var toast: String?

    private let tick = Timer.publish(every: 20, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                catchUpCard
                logCard
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
                seat(day: store.logicalDay(), slot: new)
                router.pendingSlot = nil
            }
        }
    }

    // MARK: 밀린 블록

    @ViewBuilder private var catchUpCard: some View {
        let missed = store.catchUpSlots()
        if !missed.isEmpty {
            Card {
                HStack(alignment: .top, spacing: 9) {
                    Text("⏳")
                    VStack(alignment: .leading, spacing: 8) {
                        Text(store.hasLoggedToday
                             ? "밀린 블록 \(missed.count)개 — 기억나는 만큼만 채워도 그래프는 살아나요."
                             : "아직 오늘 기록이 없어요. 방금 지나간 \(missed.count)개 블록부터 채워 볼까요?")
                            .font(.system(size: 13))
                        Button(store.hasLoggedToday ? "가장 오래된 것부터 채우기" : "지금부터 시작하기") {
                            seat(day: store.logicalDay(), slot: missed[0])
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    // MARK: 입력

    // Kept under SwiftUI's 10-child ViewBuilder limit by grouping.
    private var logCard: some View {
        Card {
            slotHeader
            modePicker
            if store.settings.quickMode { quickSection } else { detailSection }
            ratingsSection
            noteSection
            actionsSection
        }
    }

    private var slotHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                // 이미 기록된 블록이면 그때의 길이로 표시한다
                Text("\(Fmt.hhmm(editSlot))–\(Fmt.hhmm(editSlot + editSlotLength))")
                    .font(.system(size: 26, weight: .bold))
                Text(slotCaption).font(.system(size: 12)).foregroundStyle(.tertiary)
            }
            Spacer()
            Button { step(-1) } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.bordered).controlSize(.small)
            Button { step(1) } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.bordered).controlSize(.small)
        }
    }

    private var modePicker: some View {
        Picker("", selection: quickModeBinding) {
            Text("간편 — 태그 탭").tag(true)
            Text("자세히 — 직접 쓰기").tag(false)
        }
        .pickerStyle(.segmented)
    }

    private var ratingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FieldLabel(text: "에너지")
            ScalePicker(labels: Scale.energy, value: $energy)
            FieldLabel(text: "집중력")
            ScalePicker(labels: Scale.focus, value: $focus)
            FieldLabel(text: "임팩트 — 이게 우선순위였나")
            SegPicker(labels: Scale.impact, value: $impact)
        }
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(showNote ? "－ 노트 접기" : "＋ 노트 · 아이디어") { showNote.toggle() }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(maxWidth: .infinity)

            if showNote {
                TextField("이 순간 스친 생각, 막힌 지점, 아이디어…", text: $note, axis: .vertical)
                    .lineLimit(3...8)
                    .textFieldStyle(.roundedBorder)
                MicButton(dictation: dictation, seed: { note }) { note = $0 }
                Text("노트를 “아이디어:” 로 시작하면 아이디어함에도 같이 들어가요")
                    .font(.system(size: 11.5)).foregroundStyle(.tertiary)
            }
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 8) {
            Button(action: saveEntry) {
                Text(store.entry(editDay, editSlot)?.isLogged == true ? "수정 저장" : "저장")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            HStack(spacing: 6) {
                Button("건너뛰기") { skip() }
                Button("직전과 동일") { pullPrevious() }
                Button("직전과 동일로 바로 저장") { saveAsPrevious() }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .font(.system(size: 12))
        }
    }

    @ViewBuilder private var quickSection: some View {
        MicButton(dictation: dictation, large: true, seed: { "" }) { text in
            activity = text
            if impact == -1 { impact = 1 }
        }

        let tags = store.quickTags()
        if !tags.contains(where: { $0.name == activity }) && !activity.isEmpty {
            HStack(spacing: 9) {
                Circle().fill(category?.color ?? Color.accentColor).frame(width: 10, height: 10)
                Text(activity).font(.system(size: 14))
                Spacer()
                Button { activity = ""; category = nil } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 13).padding(.vertical, 11)
            .background(Color.accentColor.opacity(0.16), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.accentColor, lineWidth: 1))
        }

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 7)], spacing: 7) {
            ForEach(tags) { tag in
                TagButton(name: tag.name, category: tag.category, selected: activity == tag.name) {
                    if activity == tag.name {
                        activity = ""
                        category = nil
                    } else {
                        activity = tag.name
                        category = tag.category
                        // one tap carries a category and a believable impact
                        if impact == -1 { impact = tag.category.defaultImpact }
                    }
                }
            }
        }

        Text("자세히 모드에서 새로 적은 활동은 여기 태그로 자동 등록돼요.")
            .font(.system(size: 11.5)).foregroundStyle(.tertiary)
    }

    @ViewBuilder private var detailSection: some View {
        FieldLabel(text: "무엇을 했나")
        TextField("예: 캐스팅 온보딩 화면 작업", text: $activity)
            .textFieldStyle(.roundedBorder)
        MicButton(dictation: dictation, seed: { activity }) { activity = $0 }

        FieldLabel(text: "분류")
        FlowLayout {
            ForEach(Category.allCases) { c in
                Button {
                    category = (category == c) ? nil : c
                    if impact == -1, let cat = category { impact = cat.defaultImpact }
                } label: {
                    HStack(spacing: 6) {
                        Circle().fill(c.color).frame(width: 8, height: 8)
                        Text(c.title).font(.system(size: 13))
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(category == c ? Color.accentColor.opacity(0.16) : Color(.secondarySystemBackground),
                                in: Capsule())
                    .overlay(Capsule().strokeBorder(category == c ? Color.accentColor : .clear, lineWidth: 1))
                    .foregroundStyle(category == c ? Color.primary : Color.secondary)
                }
                .buttonStyle(.plain)
            }
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

        return Card(title: "오늘 타임라인", subtitle: past > 0 ? "\(done)/\(past) 블록 기록됨" : "아직 시작 전") {
            VStack(spacing: 6) {
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
                                .frame(width: 4, height: 26)
                            if let e, e.skipped {
                                Text("건너뜀").font(.system(size: 14)).foregroundStyle(.tertiary)
                            } else if let e, e.isLogged {
                                Text(e.activity).font(.system(size: 14)).lineLimit(1)
                                if e.impact == 2 {
                                    Text("임팩트").font(.system(size: 10))
                                        .padding(.horizontal, 6).padding(.vertical, 1)
                                        .background(Color.green.opacity(0.18), in: Capsule())
                                        .foregroundStyle(.green)
                                }
                            } else {
                                Text(slot > nowOff ? "—" : "비어 있음")
                                    .font(.system(size: 14)).foregroundStyle(.tertiary)
                            }
                            Spacer(minLength: 4)
                            if let e, e.isLogged {
                                Text("E\(e.energy > 0 ? String(e.energy) : "–") · F\(e.focus > 0 ? String(e.focus) : "–")")
                                    .font(.system(size: 11)).monospacedDigit().foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 9)
                        .frame(maxWidth: .infinity)
                        .background(Color(.secondarySystemBackground).opacity(e == nil ? 0 : 1),
                                    in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(slot == nowSlot ? Color.accentColor : Color.primary.opacity(0.08),
                                              lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
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

    private var quickModeBinding: Binding<Bool> {
        Binding(get: { store.settings.quickMode },
                set: { store.settings.quickMode = $0; store.save() })
    }

    private var editSlotLength: Int {
        store.entry(editDay, editSlot).map { store.minutes(of: $0) } ?? store.settings.interval
    }

    private var slotCaption: String {
        if editDay != store.logicalDay() { return Fmt.pretty(editDay) }
        let now = store.currentSlot()
        if editSlot == now { return "지금 블록" }
        return editSlot < now ? "지난 블록" : "앞으로"
    }

    /// Empty block: carry energy/focus from the block right before it. They
    /// barely move in 30 minutes, and it shows as selected — one tap to fix.
    private func seat(day: String, slot: Int) {
        dictation.stop()
        dictation.reset()
        editDay = day
        editSlot = slot
        let e = store.entry(day, slot)
        activity = e?.activity ?? ""
        category = e?.category
        note = e?.note ?? ""
        impact = e?.impact ?? -1
        showNote = !(e?.note ?? "").isEmpty
        if let e {
            energy = e.energy
            focus = e.focus
        } else if let prev = store.entry(day, slot - store.settings.interval), !prev.skipped {
            energy = prev.energy
            focus = prev.focus
        } else {
            energy = 0
            focus = 0
        }
    }

    /// Nothing here the user would lose by moving off it.
    private var draftIsClean: Bool {
        guard let e = store.entry(editDay, editSlot) else {
            return activity.trimmingCharacters(in: .whitespaces).isEmpty
                && note.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return activity == e.activity && note == e.note && category == e.category
            && energy == e.energy && focus == e.focus && impact == e.impact
    }

    /// Leaving the app open past a block boundary must not strand the form on
    /// a block that already ended — but never yank it out from under typing.
    private func followClock() {
        let today = store.logicalDay()
        let now = store.currentSlot()
        guard editDay == today, editSlot != now, draftIsClean, !dictation.isRecording else { return }
        seat(day: today, slot: now)
    }

    private func step(_ dir: Int) {
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
        guard !act.isEmpty else {
            flash(store.settings.quickMode ? "태그를 하나 골라 주세요" : "무엇을 했는지 한 줄만 적어 주세요")
            return
        }
        store.put(day: editDay, slot: editSlot) {
            $0.activity = act
            $0.category = category
            $0.energy = energy
            $0.focus = focus
            $0.impact = impact
            $0.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            $0.skipped = false
        }
        store.rememberTag(act, category)

        var msg = "저장됐어요"
        if let range = note.range(of: #"^\s*아이디어\s*[:：]\s*"#, options: .regularExpression) {
            store.addIdea(String(note[range.upperBound...]), fromPing: true)
            msg = "저장 · 아이디어함에도 담았어요"
        }
        // Never let a failed write pass for a successful one.
        flash(store.lastSaveFailed ? "저장 실패 — 기기 저장 공간을 확인해 주세요" : msg)
        Task { await Notifier.shared.reschedule() }   // tags changed → refresh buttons
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

    private func pullPrevious() {
        guard let prev = store.previousEntry(day: editDay, before: editSlot) else {
            flash("직전에 기록된 블록이 없어요")
            return
        }
        activity = prev.activity
        category = prev.category
        impact = prev.impact
        flash("직전 블록을 불러왔어요 — 에너지·집중력만 확인해 주세요")
    }

    private func saveAsPrevious() {
        guard let prev = store.previousEntry(day: editDay, before: editSlot) else {
            flash("직전에 기록된 블록이 없어요")
            return
        }
        store.put(day: editDay, slot: editSlot) {
            $0.activity = prev.activity
            $0.category = prev.category
            $0.energy = prev.energy
            $0.focus = prev.focus
            $0.impact = prev.impact
            $0.note = ""
            $0.skipped = false
        }
        flash("\(prev.activity) — 그대로 저장했어요")
        let all = store.slots
        if let i = all.firstIndex(of: editSlot) {
            seat(day: editDay, slot: all[min(all.count - 1, i + 1)])
        }
    }

    private func flash(_ msg: String) {
        withAnimation { toast = msg }
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            withAnimation { toast = nil }
        }
    }
}
