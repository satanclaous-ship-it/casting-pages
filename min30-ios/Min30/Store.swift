import Foundation
import Observation

/// Everything the app knows, held in memory and mirrored to one JSON file in
/// Application Support. A single file keeps notification-action writes (which
/// run in a briefly-woken background process) trivially correct — load, mutate,
/// save, done.
@Observable
final class Store {
    static let shared = Store()

    private(set) var entries: [String: [Int: Entry]] = [:]   // day -> slot -> entry
    var ideas: [Idea] = []
    var reviews: [String: DayReview] = [:]
    var oneThings: [String: String] = [:]      // 날짜 -> 그날의 원씽
    var settings = Settings()

    private let queue = DispatchQueue(label: "min30.store", qos: .userInitiated)

    // MARK: 저장

    private struct Snapshot: Codable {
        var entries: [String: [Int: Entry]]
        var ideas: [Idea]
        var reviews: [String: DayReview]
        var settings: Settings
        var oneThings: [String: String]?      // 날짜 → 그날의 원씽
    }

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("min30.json")
    }

    /// Set when the last write failed, so the UI can say so instead of
    /// silently claiming a save that never landed.
    private(set) var lastSaveFailed = false

    private init() { load() }

    func load() {
        guard let data = try? Data(contentsOf: Self.fileURL),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        entries = snap.entries
        ideas = snap.ideas
        reviews = snap.reviews
        oneThings = snap.oneThings ?? [:]
        settings = snap.settings
        stampLegacyIntervals()
    }

    /// Stamp the block length onto anything recorded before `iv` existed, using
    /// the interval in force right now — which is the one it was logged at,
    /// since this runs before the user can change it. Idempotent.
    private func stampLegacyIntervals() {
        var touched = false
        // Snapshot the keys before mutating — iterating a dictionary's own
        // key view while writing into it is undefined behaviour.
        for day in Array(entries.keys) {
            guard var slots = entries[day] else { continue }
            var changed = false
            for slot in Array(slots.keys) where slots[slot]?.iv == nil {
                slots[slot]?.iv = settings.interval
                changed = true
            }
            if changed {
                entries[day] = slots
                touched = true
            }
        }
        if touched { save() }
    }

    func save() {
        let snap = Snapshot(entries: entries, ideas: ideas, reviews: reviews,
                            settings: settings, oneThings: oneThings)
        queue.async { [weak self] in
            do {
                let data = try JSONEncoder().encode(snap)
                try data.write(to: Self.fileURL, options: .atomic)
                Task { @MainActor in self?.lastSaveFailed = false }
            } catch {
                Task { @MainActor in self?.lastSaveFailed = true }
            }
        }
    }

    /// A background launch (notification action) may have written while the
    /// foreground copy sat idle. Re-read before showing anything.
    func reloadFromDisk() { load() }

    // MARK: 시간 · 블록

    /// Minute offset inside the logical day; past-midnight hours read as > 1440
    /// so a 2am block still belongs to the day that started it.
    func offset(of date: Date = Date()) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        let m = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        let sp = settings.span
        return (sp.wraps && m < sp.end - 1440) ? m + 1440 : m
    }

    func logicalDay(_ date: Date = Date()) -> String {
        let sp = settings.span
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        let m = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        if sp.wraps && m < sp.end - 1440 {
            return Fmt.dayKey.string(from: Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date)
        }
        return Fmt.dayKey.string(from: date)
    }

    var slots: [Int] {
        let sp = settings.span
        let iv = max(5, settings.interval)
        var out: [Int] = []
        var m = sp.start
        while m + iv <= sp.end {
            out.append(m)
            m += iv
        }
        return out
    }

    func currentSlot(_ date: Date = Date()) -> Int {
        let all = slots
        guard let first = all.first, let last = all.last else { return 0 }
        let off = offset(of: date)
        if off < first { return first }
        if off >= last { return last }
        return first + ((off - first) / settings.interval) * settings.interval
    }

    func isWeekend(_ day: String) -> Bool {
        guard let d = Fmt.dayKey.date(from: day) else { return false }
        let wd = Calendar.current.component(.weekday, from: d)
        return wd == 1 || wd == 7
    }

    static func addDays(_ day: String, _ n: Int) -> String {
        guard let d = Fmt.dayKey.date(from: day),
              let moved = Calendar.current.date(byAdding: .day, value: n, to: d) else { return day }
        return Fmt.dayKey.string(from: moved)
    }

    // MARK: 읽기 · 쓰기

    func entry(_ day: String, _ slot: Int) -> Entry? { entries[day]?[slot] }

    func loggedEntries(_ day: String) -> [Entry] {
        (entries[day] ?? [:]).values.filter(\.isLogged).sorted { $0.slot < $1.slot }
    }

    @discardableResult
    func put(day: String, slot: Int, mutate: (inout Entry) -> Void) -> Entry {
        var e = entries[day]?[slot] ?? Entry(day: day, slot: slot)
        mutate(&e)
        if e.iv == nil { e.iv = settings.interval }   // 기록 당시 길이를 고정
        e.updatedAt = Date()
        entries[day, default: [:]][slot] = e
        save()
        return e
    }

    /// 이 블록이 실제로 몇 분이었나. iv 이전 데이터는 현재 설정으로 대체된다.
    func minutes(of e: Entry) -> Int { e.iv ?? settings.interval }

    func skip(day: String, slot: Int) {
        put(day: day, slot: slot) { $0.skipped = true; $0.activity = "" }
    }

    /// The most recent logged block strictly before `slot` on the same day.
    func previousEntry(day: String, before slot: Int) -> Entry? {
        loggedEntries(day).last { $0.slot < slot }
    }

    // MARK: 오늘의 원씽

    /// 『원씽』의 초점 질문에 대한 그날의 답. 이 문장과 맞아떨어지는 블록은
    /// 자동으로 원씽으로 분류된다 — 분류가 곧 임팩트 판정이 되는 지점.
    func oneThing(_ day: String) -> String { oneThings[day] ?? "" }

    func setOneThing(_ text: String, for day: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { oneThings.removeValue(forKey: day) } else { oneThings[day] = t }
        save()
    }

    // MARK: 자동 분류

    /// 무엇을 했는지만 쓰면 분류는 앱이 정한다. 순서가 중요하다 —
    /// 내가 고쳐준 것 > 오늘의 원씽 > 예전에 같은 걸 어떻게 넣었나 > 키워드.
    func autoClassify(_ text: String, day: String) -> Category {
        let n = AutoTag.norm(text)
        guard !n.isEmpty else { return AutoTag.fallback }

        if let learned = settings.learned[n] { return learned }

        let one = AutoTag.norm(oneThing(day))
        if !one.isEmpty, n.contains(one) || one.contains(n) { return .onething }

        // 같은 활동을 예전에 직접 분류한 적이 있으면 그걸 따른다
        if let past = mostRecentCategory(for: n) { return past }

        return AutoTag.classify(text)
    }

    private func mostRecentCategory(for normalized: String) -> Category? {
        for day in entries.keys.sorted(by: >).prefix(30) {
            for e in (entries[day] ?? [:]).values.sorted(by: { $0.updatedAt > $1.updatedAt })
            where e.isLogged && AutoTag.norm(e.activity) == normalized {
                if let c = e.category { return c }
            }
        }
        return nil
    }

    /// 자동 분류를 고쳤을 때만 부른다. 다음부터 같은 표현은 바로 맞춘다.
    func learnCorrection(_ text: String, _ category: Category) {
        let n = AutoTag.norm(text)
        guard !n.isEmpty else { return }
        settings.learned[n] = category
        // 같은 프로퍼티를 한 식 안에서 읽고 쓰면 배타적 접근 위반이다
        if settings.learned.count > 300, let oldest = settings.learned.keys.first {
            settings.learned.removeValue(forKey: oldest)
        }
        save()
    }

    /// 최근에 실제로 적은 활동들. 저장된 태그 목록이 아니라 기록에서 뽑는다 —
    /// 쓴 것이 그대로 다음번 후보가 되고, 관리할 목록이 따로 생기지 않는다.
    func recentActivities(limit: Int = 8) -> [(name: String, category: Category?)] {
        var seen = Set<String>()
        var out: [(String, Category?)] = []
        for day in entries.keys.sorted(by: >).prefix(14) {
            for e in (entries[day] ?? [:]).values.sorted(by: { $0.updatedAt > $1.updatedAt }) where e.isLogged {
                let key = AutoTag.norm(e.activity)
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                out.append((e.activity, e.category))
                if out.count >= limit { return out }
            }
        }
        return out
    }

    // MARK: 아이디어

    @discardableResult
    func addIdea(_ text: String, fromPing: Bool = false) -> Idea? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        let idea = Idea(text: t, day: logicalDay(), slot: currentSlot(), fromPing: fromPing)
        ideas.insert(idea, at: 0)
        save()
        return idea
    }

    func setIdeaStatus(_ id: UUID, _ status: IdeaStatus) {
        guard let i = ideas.firstIndex(where: { $0.id == id }) else { return }
        ideas[i].status = status
        save()
    }

    func deleteIdea(_ id: UUID) {
        ideas.removeAll { $0.id == id }
        save()
    }

    // MARK: 집계

    struct CategoryRow: Identifiable {
        var id: String { category?.rawValue ?? "other" }
        var category: Category?
        var title: String
        var blocks: Int
        var hours: Double
        var pct: Int
    }

    struct DaySummary {
        var blocks = 0
        var loggedHours = 0.0
        var impactHours = 0.0      // 원씽 + 레버리지
        var oneThingHours = 0.0
        var wasteHours = 0.0
        var recoverHours = 0.0
        var energy = 0.0
        var focus = 0.0
        var coverage = 0
        var ideaCount = 0
        var rows: [CategoryRow] = []

        var impactPct: Int {
            loggedHours > 0 ? Int((impactHours / loggedHours * 100).rounded()) : 0
        }
    }

    func hours(blocks: Int) -> Double { Double(blocks * settings.interval) / 60 }

    /// 기간 합계는 언제나 블록들의 실제 길이를 더해서 낸다 — 오늘의 설정으로
    /// 곱하면 간격을 바꾸는 순간 과거가 통째로 다시 환산된다.
    func hours(of list: [Entry]) -> Double {
        Double(list.reduce(0) { $0 + minutes(of: $1) }) / 60
    }

    func summarize(_ days: [String]) -> DaySummary {
        let all = days.flatMap { loggedEntries($0) }
        var minsByCat: [Category?: Int] = [:]
        var nByCat: [Category?: Int] = [:]
        var eSum = 0, eN = 0, fSum = 0, fN = 0
        var impactMins = 0, oneThingMins = 0, wasteMins = 0, recoverMins = 0, totalMins = 0
        for x in all {
            let m = minutes(of: x)
            minsByCat[x.category, default: 0] += m
            nByCat[x.category, default: 0] += 1
            totalMins += m
            if x.energy > 0 { eSum += x.energy; eN += 1 }
            if x.focus > 0 { fSum += x.focus; fN += 1 }
            // 분류가 곧 임팩트 판정이다 — 따로 묻지 않는다
            if x.buildsImpact { impactMins += m }
            if x.category == .onething { oneThingMins += m }
            if x.category == .waste { wasteMins += m }
            if x.category == .recover { recoverMins += m }
        }
        let total = all.count

        func row(_ c: Category?, _ title: String) -> CategoryRow? {
            let n = nByCat[c] ?? 0
            guard n > 0 else { return nil }
            let mins = minsByCat[c] ?? 0
            return CategoryRow(category: c, title: title, blocks: n,
                               hours: Double(mins) / 60,
                               pct: totalMins > 0 ? Int((Double(mins) / Double(totalMins) * 100).rounded()) : 0)
        }
        var rows = Category.allCases.compactMap { row($0, $0.title) }
        if let other = row(nil, "미분류") { rows.append(other) }
        rows.sort { $0.hours > $1.hours }

        let today = logicalDay()
        let nowOff = offset()
        // 나중에 기상 시간대를 좁히면 창 밖으로 밀려난 블록 때문에 분모가
        // 분자보다 작아진다. 실제 기록 수 밑으로는 내려가지 않게 한다.
        let possible = max(total, days.reduce(0) { acc, day in
            acc + slots.filter { day != today || $0 + settings.interval <= nowOff }.count
        })

        return DaySummary(
            blocks: total,
            loggedHours: Double(totalMins) / 60,
            impactHours: Double(impactMins) / 60,
            oneThingHours: Double(oneThingMins) / 60,
            wasteHours: Double(wasteMins) / 60,
            recoverHours: Double(recoverMins) / 60,
            energy: eN > 0 ? Double(eSum) / Double(eN) : 0,
            focus: fN > 0 ? Double(fSum) / Double(fN) : 0,
            coverage: possible > 0 ? Int((Double(total) / Double(possible) * 100).rounded()) : 0,
            ideaCount: ideas.filter { days.contains($0.day) }.count,
            rows: rows
        )
    }

    /// The run of consecutive blocks with the highest average focus — the
    /// window worth defending for tomorrow's most important work.
    func bestFocusWindow(_ day: String) -> (from: Int, to: Int, avg: Double, blocks: Int)? {
        let list = loggedEntries(day).filter { $0.focus > 0 }
        guard list.count >= 2 else { return nil }
        var best: (from: Int, to: Int, avg: Double, blocks: Int)?
        for i in list.indices {
            var sum = 0, n = 0
            for j in i..<min(i + 4, list.count) {
                // 연속 판정도 블록별 실제 길이를 쓴다
                if j > i, list[j].slot != list[j - 1].slot + minutes(of: list[j - 1]) { break }
                sum += list[j].focus
                n += 1
                if n >= 2 {
                    let avg = Double(sum) / Double(n)
                    // 평균이 같으면 더 오래 유지된 구간이 이긴다 — 30분짜리 반짝
                    // 몰입보다 두 시간 내리 이어진 구간이 내일 지킬 값어치가 있다
                    if best == nil || avg > best!.avg || (avg == best!.avg && n > best!.blocks) {
                        best = (list[i].slot, list[j].slot + minutes(of: list[j]), avg, n)
                    }
                }
            }
        }
        return best
    }

    /// Blocks worth going back for. A fresh install shouldn't open with a
    /// backlog, and nobody honestly remembers past ~2 hours.
    func catchUpSlots() -> [Int] {
        let day = logicalDay()
        let nowOff = offset()
        let past = slots.filter { $0 + settings.interval <= nowOff }
        guard !past.isEmpty else { return [] }
        let recall = max(2, 120 / max(5, settings.interval))
        // once the day has started, offer everything since the first log;
        // before that, only the couple of hours you could actually reconstruct
        let from = past.first { entry(day, $0) != nil } ?? past.suffix(recall).first!
        return past.filter { $0 >= from && entry(day, $0) == nil }
    }

    var hasLoggedToday: Bool {
        let day = logicalDay()
        return slots.contains { entry(day, $0) != nil }
    }

    // MARK: 내보내기

    func exportJSON() -> Data? {
        try? JSONEncoder().encode(Snapshot(entries: entries, ideas: ideas, reviews: reviews,
                                           settings: settings, oneThings: oneThings))
    }

    func exportMarkdown(day: String) -> String {
        let s = summarize([day])
        let r = reviews[day] ?? DayReview()
        var L = ["# \(day) 하루 기록", ""]
        L.append("- 임팩트 시간: **\(Fmt.hours(s.impactHours))** / 기록 \(Fmt.hours(s.loggedHours))")
        L.append(String(format: "- 평균 에너지 %.1f · 평균 집중력 %.1f · 기록률 %d%%", s.energy, s.focus, s.coverage))
        if let w = bestFocusWindow(day) {
            L.append(String(format: "- 최고 집중 구간: %@–%@ (평균 %.1f)", Fmt.hhmm(w.from), Fmt.hhmm(w.to), w.avg))
        }
        L.append(contentsOf: ["", "## 분류별"])
        L.append(contentsOf: s.rows.map { "- \($0.title): \(Fmt.hours($0.hours)) (\($0.pct)%)" })
        L.append(contentsOf: ["", "## 타임라인"])
        for e in loggedEntries(day) {
            var line = "- `\(Fmt.hhmm(e.slot))` \(e.activity)"
            if let c = e.category { line += " _(\(c.title))_" }
            line += " — E\(e.energy > 0 ? String(e.energy) : "–")/F\(e.focus > 0 ? String(e.focus) : "–")"
            if e.buildsImpact { line += " **임팩트**" }
            if !e.note.isEmpty { line += "\n    - " + e.note.replacingOccurrences(of: "\n", with: " ") }
            L.append(line)
        }
        let dayIdeas = ideas.filter { $0.day == day }
        if !dayIdeas.isEmpty {
            L.append(contentsOf: ["", "## 아이디어"])
            L.append(contentsOf: dayIdeas.map { "- [\($0.status.title)] " + $0.text.replacingOccurrences(of: "\n", with: " ") })
        }
        L.append(contentsOf: ["", "## 회고",
                              "- 임팩트: \(r.win.isEmpty ? "—" : r.win)",
                              "- 없앨 낭비: \(r.cut.isEmpty ? "—" : r.cut)",
                              "- 내일 우선순위: \(r.next.isEmpty ? "—" : r.next)"])
        return L.joined(separator: "\n")
    }

    func exportCSV() -> String {
        func q(_ s: String) -> String { "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        var lines = ["date,slot_start,slot_end,activity,category,energy,focus,impact,note"]
        for day in entries.keys.sorted() {
            for slot in (entries[day] ?? [:]).keys.sorted() {
                guard let e = entries[day]?[slot], e.isLogged else { continue }
                let impact = (e.category?.buildsImpact ?? false) ? "임팩트" : ""
                lines.append([
                    day, Fmt.hhmm(slot), Fmt.hhmm(slot + minutes(of: e)),
                    q(e.activity), e.category?.title ?? "",
                    e.energy > 0 ? String(e.energy) : "",
                    e.focus > 0 ? String(e.focus) : "",
                    impact, q(e.note),
                ].joined(separator: ","))
            }
        }
        return "\u{FEFF}" + lines.joined(separator: "\n")
    }

    func wipe() {
        entries = [:]
        ideas = []
        reviews = [:]
        oneThings = [:]
        settings = Settings()
        save()
    }
}
