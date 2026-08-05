import SwiftUI
import Charts

struct ReviewView: View {
    @Environment(Store.self) private var store

    @State private var day = Store.shared.logicalDay()
    @State private var weekScope = false

    private var days: [String] {
        weekScope ? (0..<7).map { Store.addDays(day, -6 + $0) } : [day]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                dayPicker

                let s = store.summarize(days)
                if s.blocks == 0 {
                    emptyCard
                } else {
                    if !weekScope { classifyCard }
                    heroCard(s)
                    tiles(s)
                    if weekScope {
                        heatmapCard
                    } else {
                        timelineCard(s)
                        levelCard
                    }
                    categoryCard(s)
                    insightsCard(s)
                    if !weekScope {
                        retroCard
                        triageCard
                    }
                }
            }
            .cardStack()
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("리뷰")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: store.exportMarkdown(day: day),
                          preview: SharePreview("\(day) 하루 기록")) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }

    // MARK: 날짜

    private var dayPicker: some View {
        VStack(spacing: 10) {
            HStack {
                Button { day = Store.addDays(day, -1) } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.bordered)
                Spacer()
                Text(Fmt.pretty(day)).font(.system(size: 15, weight: .semibold))
                Spacer()
                Button { day = Store.addDays(day, 1) } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(.bordered)
                    .disabled(day >= store.logicalDay())
            }
            Picker("", selection: $weekScope) {
                Text("하루").tag(false)
                Text("최근 7일").tag(true)
            }
            .pickerStyle(.segmented)
        }
    }

    private var emptyCard: some View {
        Card {
            VStack(spacing: 6) {
                Text("이 \(weekScope ? "주" : "날")엔 기록이 없어요.")
                Text("기록 탭에서 지난 블록도 채울 수 있어요.").foregroundStyle(.tertiary)
            }
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
    }

    // MARK: 하루치 분류 — 낮에 미뤄둔 결정을 여기서 한 번에

    /// 30분마다 "이게 무슨 분류지?" 를 묻지 않는 대신, 저녁에 하루를 통째로
    /// 놓고 훑는다. 하루 전체가 보일 때라야 무엇이 진짜 레버리지였는지
    /// 판단할 수 있고, 결정 한 번의 비용도 그만큼 싸다.
    @ViewBuilder private var classifyCard: some View {
        let pending = store.unconfirmed(day)
        if !pending.isEmpty {
            Card(title: "분류하기", subtitle: "\(pending.count)개 남음") {
                Text("낮에는 기록만 했어요. 제안이 맞으면 그대로 넘기고, 아니면 탭해서 바꾸세요.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)

                ForEach(pending) { e in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text(Fmt.hhmm(e.slot))
                                .font(.system(size: 12)).monospacedDigit()
                                .foregroundStyle(.tertiary)
                                .frame(width: 44, alignment: .leading)
                            Text(e.activity).font(.system(size: 14)).lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        FlowLayout(spacing: 6) {
                            ForEach(Category.allCases) { c in
                                let isSuggested = e.category == c
                                Button {
                                    store.confirmCategory(day: day, slot: e.slot, as: c)
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: c.symbol).font(.system(size: 10))
                                        Text(c.title).font(.system(size: 12.5))
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 7)
                                    .background(isSuggested ? c.color.opacity(0.18) : Color(.secondarySystemBackground),
                                                in: Capsule())
                                    .overlay(Capsule().strokeBorder(isSuggested ? c.color : .clear, lineWidth: 1))
                                    .foregroundStyle(isSuggested ? c.color : Color.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                    Divider()
                }

                Button {
                    store.confirmAllSuggestions(day)
                } label: {
                    Text("제안대로 \(pending.count)개 전부 확인")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    // MARK: 히어로 — 이 시스템이 존재하는 이유인 숫자 하나

    private func heroCard(_ s: Store.DaySummary) -> some View {
        Card {
            VStack(spacing: 4) {
                Text(Fmt.hours(s.impactHours))
                    .font(.system(size: 52, weight: .bold))
                Text("임팩트를 만든 시간 — 원씽 + 레버리지")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Text("전체 기록 \(Fmt.hours(s.loggedHours)) 중 \(s.impactPct)%"
                     + (s.oneThingHours > 0 ? " · 그중 원씽 \(Fmt.hours(s.oneThingHours))" : "")
                     + (s.wasteHours > 0 ? " · 낭비 \(Fmt.hours(s.wasteHours))" : ""))
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func tiles(_ s: Store.DaySummary) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 8)], spacing: 8) {
            StatTile(label: "기록률", value: "\(s.coverage)", unit: "%")
            StatTile(label: "평균 집중력", value: s.level > 0 ? String(format: "%.1f", s.level) : "–", unit: "/5")
            StatTile(label: "회복", value: Fmt.hours(s.recoverHours))
        }
    }

    // MARK: 하루 타임라인 — 블록마다 한 칸

    private struct Band: Identifiable {
        let id: Int          // slot
        let start: Int
        let end: Int
        let color: Color
        let row: String
    }

    /// Marks come from the blocks themselves, each at its own recorded length,
    /// so a day logged at a different interval — or before the waking window
    /// was narrowed — still draws where it actually happened.
    private var bands: [Band] {
        let iv = store.settings.interval
        var out: [Band] = []

        for e in store.loggedEntries(day) {
            let len = store.minutes(of: e)
            out.append(Band(id: e.slot, start: e.slot, end: e.slot + len - 2,   // 2분 = 마크 사이 여백
                            color: e.category?.color ?? Color.secondary, row: "활동"))
            if e.buildsImpact {
                out.append(Band(id: e.slot + 100_000, start: e.slot, end: e.slot + len - 2,
                                color: .green, row: "임팩트"))
            }
        }
        // an unlogged block must read as a hole, not blend into the card
        for slot in store.slots where store.entry(day, slot) == nil {
            out.append(Band(id: slot + 200_000, start: slot, end: slot + iv - 2,
                            color: Color.secondary.opacity(0.22), row: "활동"))
        }
        return out.sorted { $0.start < $1.start }
    }

    private func timelineCard(_ s: Store.DaySummary) -> some View {
        Card(title: "하루 타임라인", subtitle: "아래 초록선 = 임팩트") {
            Chart(bands) { b in
                BarMark(
                    xStart: .value("시작", b.start),
                    xEnd: .value("끝", b.end),
                    y: .value("행", b.row),
                    height: b.row == "활동" ? .fixed(46) : .fixed(4)
                )
                .foregroundStyle(b.color)
                .cornerRadius(3)
            }
            .chartYScale(domain: ["임팩트", "활동"])
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: hourTicks) { v in
                    AxisTick()
                    AxisValueLabel {
                        if let m = v.as(Int.self) { Text(Fmt.hhmm(m)).font(.system(size: 10)) }
                    }
                }
            }
            .frame(height: 96)

            legend(s.rows)
            LegendChip(color: .green, label: "아래 얇은 선 = 임팩트 높음")

            tableDisclosure("표로 보기") {
                ForEach(store.loggedEntries(day)) { e in
                    tableRow(Fmt.hhmm(e.slot), e.activity,
                             e.level > 0 ? "집중 \(e.level)" : "집중 –")
                }
            }
        }
    }

    private var hourTicks: [Int] {
        let sp = store.settings.span
        let startH = Int(ceil(Double(sp.start) / 60))
        let endH = sp.end / 60
        guard endH > startH else { return [startH * 60] }
        let step = (endH - startH) > 9 ? 2 : 1
        return stride(from: startH, through: endH, by: step).map { $0 * 60 }
    }

    // MARK: 집중력 — 하루 동안 어떻게 오르내렸나

    private struct Point: Identifiable {
        let id: String
        let x: Int
        let y: Int
    }

    private var levelPoints: [Point] {
        store.loggedEntries(day).compactMap { e in
            guard e.level > 0 else { return nil }
            // 블록마다 자기 길이의 중앙에 찍는다
            return Point(id: "l\(e.slot)", x: e.slot + store.minutes(of: e) / 2, y: e.level)
        }
    }

    private var levelCard: some View {
        let pts = levelPoints
        let lineColor = Color(light: 0x2A78D6, dark: 0x3987E5)

        return Card(title: "집중력", subtitle: "1 산만 – 5 몰입") {
            // 예전엔 두 계열이라 4점이 블록 2개였다. 이제 1점이 곧 1블록이니
            // 같은 4를 두면 그려지기까지 두 배로 기다리게 된다. 선은 2점이면 된다.
            if pts.count < 2 {
                Text("기록이 조금 더 쌓이면 그려져요")
                    .font(.system(size: 13)).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
            } else {
                // 계열이 하나뿐이니 범례도 색 구분도 필요 없다. 눈이 볼 게 줄었다.
                Chart(pts) { p in
                    LineMark(x: .value("시각", p.x), y: .value("집중력", p.y))
                        .lineStyle(.init(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    PointMark(x: .value("시각", p.x), y: .value("집중력", p.y))
                        .symbolSize(56)
                }
                .foregroundStyle(lineColor)
                .chartYScale(domain: 1...5)
                .chartYAxis {
                    AxisMarks(values: [1, 2, 3, 4, 5]) { v in
                        AxisGridLine()
                        AxisValueLabel {
                            if let i = v.as(Int.self) { Text("\(i)").font(.system(size: 10)) }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: hourTicks) { v in
                        AxisValueLabel {
                            if let m = v.as(Int.self) { Text(Fmt.hhmm(m)).font(.system(size: 10)) }
                        }
                    }
                }
                .frame(height: 190)
            }
        }
    }

    // MARK: 주간 히트맵 — 한 색조, 5단계

    private struct Cell: Identifiable {
        let id: String
        let hour: String        // 정렬이 시각 순서와 같도록 "08" 형태로
        let day: String
        let avg: Double
    }

    /// Hour labels in *window* order, not alphabetical — a wake window that
    /// wraps past midnight (14:00–03:00) must not put 00–02 at the far left.
    private var heatHours: [Int] {
        let sp = store.settings.span
        return Array((sp.start / 60)..<Int(ceil(Double(sp.end) / 60)))
    }

    private var heatCells: [Cell] {
        var out: [Cell] = []
        for d in days {
            let logged = store.loggedEntries(d).filter { $0.level > 0 }
            for h in heatHours {
                let inHour = logged.filter { $0.slot / 60 == h }
                let avg = inHour.isEmpty ? 0
                    : Double(inHour.reduce(0) { $0 + $1.level }) / Double(inHour.count)
                out.append(Cell(id: "\(d)-\(h)",
                                hour: String(format: "%02d", h % 24),
                                day: Fmt.pretty(d),
                                avg: avg))
            }
        }
        return out
    }

    private var heatmapCard: some View {
        let cells = heatCells
        let hours = heatHours.map { String(format: "%02d", $0 % 24) }
        let labelled = hours.enumerated().filter { $0.offset % 2 == 0 }.map(\.element)

        return Card(title: "시간대별 집중력", subtitle: "진할수록 몰입") {
            Chart(cells) { c in
                RectangleMark(
                    x: .value("시", c.hour),
                    y: .value("날짜", c.day),
                    width: .ratio(0.9),
                    height: .ratio(0.84)
                )
                .foregroundStyle(Self.focusStep(c.avg))
                .cornerRadius(3)
            }
            .chartXScale(domain: hours)
            .chartYScale(domain: Array(days.map(Fmt.pretty).reversed()))
            .chartXAxis {
                AxisMarks(values: labelled) { AxisValueLabel().font(.system(size: 10)) }
            }
            .chartYAxis {
                AxisMarks(preset: .aligned, position: .leading) {
                    AxisValueLabel().font(.system(size: 10))
                }
            }
            .frame(height: 240)

            FlowLayout(spacing: 10) {
                ForEach(1...5, id: \.self) { v in
                    LegendChip(color: Self.focusStep(Double(v)),
                               label: v == 1 ? "1 산만" : v == 5 ? "5 몰입" : "\(v)")
                }
                LegendChip(color: Color.secondary.opacity(0.22), label: "기록 없음")
            }

            tableDisclosure("표로 보기") {
                ForEach(days, id: \.self) { d in
                    let l = store.loggedEntries(d)
                    let rated = l.filter { $0.level > 0 }
                    tableRow(
                        String(d.suffix(5)),
                        "\(l.count)블록",
                        rated.isEmpty ? "집중 –"
                            : String(format: "집중 %.1f",
                                     Double(rated.reduce(0) { $0 + $1.level }) / Double(rated.count))
                    )
                }
            }
        }
    }

    /// One hue, five ordinal steps — dark→light on a dark surface, light→dark
    /// on a light one. Validated for monotone lightness and step gaps in both.
    static func focusStep(_ avg: Double) -> Color {
        guard avg > 0 else { return Color.secondary.opacity(0.22) }
        let i = min(4, max(0, Int(avg.rounded()) - 1))
        let light = [0x86B6EF, 0x5598E7, 0x2A78D6, 0x1C5CAB, 0x0D366B]
        let dark  = [0x184F95, 0x256ABF, 0x3987E5, 0x6DA7EC, 0x9EC5F4]
        return Color(light: light[i], dark: dark[i])
    }

    // MARK: 분류별 — 파이가 아니라 막대. 비교가 요점이니까

    private func categoryCard(_ s: Store.DaySummary) -> some View {
        Card(title: "분류별 시간", subtitle: "\(Fmt.hours(s.loggedHours)) 기록됨") {
            Chart(s.rows) { row in
                BarMark(
                    x: .value("시간", row.hours),
                    y: .value("분류", row.title)
                )
                .foregroundStyle(row.category?.color ?? Color.secondary)
                .cornerRadius(4)
                .annotation(position: .trailing, alignment: .leading) {
                    Text("\(Fmt.hours(row.hours)) · \(row.pct)%")
                        .font(.system(size: 11))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .chartXAxis(.hidden)
            .chartXScale(domain: 0...(max(s.rows.first?.hours ?? 1, 0.5) * 1.28))
            .chartYScale(domain: Array(s.rows.map(\.title).reversed()))   // 큰 것이 위
            .chartYAxis {
                AxisMarks(preset: .aligned, position: .leading) {
                    AxisValueLabel().font(.system(size: 11.5))
                }
            }
            .frame(height: CGFloat(s.rows.count) * 34 + 12)

            tableDisclosure("표로 보기") {
                ForEach(s.rows) { r in
                    tableRow(r.title, "\(r.blocks)블록", "\(Fmt.hours(r.hours)) · \(r.pct)%")
                }
            }
        }
    }

    private func legend(_ rows: [Store.CategoryRow]) -> some View {
        FlowLayout(spacing: 12) {
            ForEach(rows) { r in
                LegendChip(color: r.category?.color ?? Color.secondary, label: r.title)
            }
        }
    }

    // MARK: 읽어낸 것

    private func insightsCard(_ s: Store.DaySummary) -> some View {
        var items: [(String, String)] = []
        if let top = s.rows.first {
            items.append(("📌", "가장 많이 한 건 \(top.title) — \(Fmt.hours(top.hours)), 전체의 \(top.pct)%."))
        }
        if let waste = s.rows.first(where: { $0.category == .waste }) {
            items.append(("🧹", "낭비가 \(Fmt.hours(waste.hours)) (\(waste.pct)%). 여기서 한 블록만 줄여도 \(store.settings.interval)분이 돌아와요."))
        }
        if s.oneThingHours == 0 && s.blocks >= 4 {
            items.append(("🎯", "오늘 원씽으로 분류된 블록이 없어요. 『원씽』의 질문은 이거예요 — 이것만 하면 나머지가 쉬워지거나 필요 없어지는 그 하나는?"))
        }
        if s.recoverHours == 0 && s.blocks >= 8 {
            items.append(("🌱", "회복 블록이 하나도 없어요. 원씽은 휴식을 먼저 캘린더에 박으라고 해요 — 성과의 반대가 아니라 조건이라서."))
        }
        if !weekScope, let w = store.bestFocusWindow(day) {
            items.append(("🎯", String(format: "최고 집중 구간은 %@–%@ (평균 %.1f). 내일 가장 중요한 일을 이 시간에 두세요.",
                                       Fmt.hhmm(w.from), Fmt.hhmm(w.to), w.avg)))
        }
        if !weekScope {
            let lows = store.loggedEntries(day).filter { $0.level > 0 && $0.level <= 2 }
            if let first = lows.first {
                items.append(("🔋", "집중이 흐트러진 블록 \(lows.count)개 — 가장 이른 건 \(Fmt.hhmm(first.slot)). 회복 루틴을 그 앞에 넣어 보세요."))
            }
        }
        if s.impactHours == 0 && s.blocks >= 4 {
            items.append(("⚠️", "원씽도 레버리지도 없는 하루였어요. 우선순위가 실제 시간으로 옮겨지지 않았다는 신호일 수 있어요."))
        }

        return Group {
            if !items.isEmpty {
                Card(title: "읽어낸 것") {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, it in
                        Insight(icon: it.0, text: it.1)
                    }
                }
            }
        }
    }

    // MARK: 마감 회고 · 아이디어 정리

    private var retroCard: some View {
        Card(title: "하루 마감 회고") {
            retroField("오늘 가장 임팩트 있었던 행동 하나", \.win)
            retroField("내일 없앨 낭비 하나", \.cut)
            retroField("내일의 우선순위 1가지", \.next)
            Text("입력하면 자동 저장돼요.").font(.system(size: 11.5)).foregroundStyle(.tertiary)
        }
    }

    private func retroField(_ label: String, _ key: WritableKeyPath<DayReview, String>) -> some View {
        let binding = Binding<String>(
            get: { store.reviews[day]?[keyPath: key] ?? "" },
            set: {
                var r = store.reviews[day] ?? DayReview()
                r[keyPath: key] = $0
                store.reviews[day] = r
                store.save()
            }
        )
        return VStack(alignment: .leading, spacing: 6) {
            FieldLabel(text: label)
            TextField("", text: binding, axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var triageCard: some View {
        let inbox = store.ideas.filter { $0.status == .inbox && days.contains($0.day) }
        return Card(title: "아이디어 정리", subtitle: "\(inbox.count)개 대기") {
            if inbox.isEmpty {
                Text("정리할 아이디어가 없어요")
                    .font(.system(size: 13)).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
            } else {
                ForEach(inbox) { idea in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(idea.text).font(.system(size: 14))
                        Text(Fmt.hhmm(idea.slot)).font(.system(size: 11)).foregroundStyle(.tertiary)
                        FlowLayout(spacing: 6) {
                            ForEach([IdeaStatus.content, .bank, .vault, .dropped]) { s in
                                Button(s.title) { store.setIdeaStatus(idea.id, s) }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .font(.system(size: 12))
                            }
                        }
                    }
                    .padding(.vertical, 6)
                    Divider()
                }
            }
        }
    }

    // MARK: 표 보기 — 어떤 차트도 색만으로 값을 전달하지 않도록

    /// DisclosureGroup stores its content closure, so a non-escaping parameter
    /// can't be handed straight to it. Build the view value up front instead —
    /// it's a struct, so there's nothing left to escape.
    private func tableDisclosure<C: View>(_ title: String, @ViewBuilder rows: () -> C) -> some View {
        let content = rows()
        return DisclosureGroup(title) {
            VStack(spacing: 0) { content }
        }
        .font(.system(size: 12))
        .tint(.secondary)
    }

    private func tableRow(_ a: String, _ b: String, _ c: String) -> some View {
        HStack {
            Text(a).monospacedDigit().foregroundStyle(.secondary).frame(width: 58, alignment: .leading)
            Text(b).lineLimit(1)
            Spacer()
            Text(c).monospacedDigit().foregroundStyle(.secondary)
        }
        .font(.system(size: 12))
        .padding(.vertical, 5)
        .overlay(alignment: .bottom) { Divider() }
    }
}
