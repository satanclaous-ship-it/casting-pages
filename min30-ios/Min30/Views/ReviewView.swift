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
                    heroCard(s)
                    tiles(s)
                    if weekScope {
                        heatmapCard
                    } else {
                        timelineCard(s)
                        energyFocusCard
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

    // MARK: 히어로 — 이 시스템이 존재하는 이유인 숫자 하나

    private func heroCard(_ s: Store.DaySummary) -> some View {
        Card {
            VStack(spacing: 4) {
                Text(Fmt.hours(s.impactHours))
                    .font(.system(size: 52, weight: .bold))
                Text("임팩트 높은 일에 쓴 시간")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Text("전체 기록 \(Fmt.hours(s.loggedHours)) 중 \(s.impactPct)%"
                     + (s.wasteHours > 0 ? " · 낭비로 표시한 시간 \(Fmt.hours(s.wasteHours))" : ""))
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
            StatTile(label: "평균 에너지", value: s.energy > 0 ? String(format: "%.1f", s.energy) : "–", unit: "/5")
            StatTile(label: "평균 집중력", value: s.focus > 0 ? String(format: "%.1f", s.focus) : "–", unit: "/5")
            StatTile(label: "아이디어", value: "\(s.ideaCount)", unit: "개")
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
            if e.impact == 2 {
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
                             "E\(e.energy > 0 ? String(e.energy) : "–") F\(e.focus > 0 ? String(e.focus) : "–")")
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

    // MARK: 에너지 · 집중력 — 같은 1–5 척도라 한 축에 두 계열

    private struct Point: Identifiable {
        let id: String
        let x: Int
        let y: Int
        let series: String
    }

    private var efPoints: [Point] {
        var out: [Point] = []
        for e in store.loggedEntries(day) {
            let mid = e.slot + store.minutes(of: e) / 2   // 블록마다 자기 길이의 중앙
            if e.energy > 0 { out.append(Point(id: "e\(e.slot)", x: mid, y: e.energy, series: "에너지")) }
            if e.focus > 0 { out.append(Point(id: "f\(e.slot)", x: mid, y: e.focus, series: "집중력")) }
        }
        return out
    }

    private var energyFocusCard: some View {
        let pts = efPoints
        let energyColor = Color(light: 0x2A78D6, dark: 0x3987E5)
        let focusColor = Color(light: 0xEB6834, dark: 0xD95926)

        return Card(title: "에너지 · 집중력", subtitle: "1–5") {
            if pts.count < 4 {
                Text("기록이 조금 더 쌓이면 그려져요")
                    .font(.system(size: 13)).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
            } else {
                Chart(pts) { p in
                    LineMark(x: .value("시각", p.x), y: .value("값", p.y))
                        .foregroundStyle(by: .value("계열", p.series))
                        .lineStyle(.init(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    PointMark(x: .value("시각", p.x), y: .value("값", p.y))
                        .foregroundStyle(by: .value("계열", p.series))
                        .symbolSize(56)
                }
                .chartForegroundStyleScale(["에너지": energyColor, "집중력": focusColor])
                .chartLegend(position: .bottom, alignment: .leading)
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
            let logged = store.loggedEntries(d).filter { $0.focus > 0 }
            for h in heatHours {
                let inHour = logged.filter { $0.slot / 60 == h }
                let avg = inHour.isEmpty ? 0
                    : Double(inHour.reduce(0) { $0 + $1.focus }) / Double(inHour.count)
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
                    let en = l.filter { $0.energy > 0 }
                    let fo = l.filter { $0.focus > 0 }
                    tableRow(
                        String(d.suffix(5)),
                        "\(l.count)블록",
                        String(format: "E %.1f · F %.1f",
                               en.isEmpty ? 0 : Double(en.reduce(0) { $0 + $1.energy }) / Double(en.count),
                               fo.isEmpty ? 0 : Double(fo.reduce(0) { $0 + $1.focus }) / Double(fo.count))
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
            items.append(("🧹", "낭비·산만이 \(Fmt.hours(waste.hours)) (\(waste.pct)%). 여기서 한 블록만 줄여도 \(store.settings.interval)분이 돌아와요."))
        }
        if !weekScope, let w = store.bestFocusWindow(day) {
            items.append(("🎯", String(format: "최고 집중 구간은 %@–%@ (평균 %.1f). 내일 가장 중요한 일을 이 시간에 두세요.",
                                       Fmt.hhmm(w.from), Fmt.hhmm(w.to), w.avg)))
        }
        if !weekScope {
            let lows = store.loggedEntries(day).filter { $0.energy > 0 && $0.energy <= 2 }
            if let first = lows.first {
                items.append(("🔋", "에너지가 바닥난 블록 \(lows.count)개 — 가장 이른 건 \(Fmt.hhmm(first.slot)). 회복 루틴을 그 앞에 넣어 보세요."))
            }
        }
        if s.impactHours == 0 && s.blocks >= 4 {
            items.append(("⚠️", "임팩트 높음으로 표시한 블록이 없어요. 우선순위가 실제 시간으로 안 옮겨졌다는 신호일 수 있어요."))
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
