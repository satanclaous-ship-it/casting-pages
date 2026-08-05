import Foundation
import os

/// 알림을 탭했을 때 앱이 죽거나 굳는 문제를 실기기에서 추적하기 위한 흔적.
///
/// 두 군데에 남긴다.
///
/// 1. **콘솔** — 맥이 있으면 실시간으로 본다.
///
///        log stream --predicate 'subsystem == "com.satanclaous.min30"' --style compact
///
/// 2. **파일** — 맥이 없어도 된다. 앱이 죽고 나서 다시 열어 `설정 → 마지막 흔적`
///    을 보면 죽기 직전까지 어디를 지나갔는지 그대로 남아 있다. 크래시는 로그를
///    가져가지만 이미 디스크에 쓴 것은 못 가져간다.
///
/// 읽는 법은 두 가지뿐이다.
/// - `┌` 에 짝이 되는 `└` 가 없다 → 거기서 막혔거나 거기서 죽었다.
/// - `↻ ... ×200 ×400` 이 쏟아진다 → 화면 갱신이 무한히 돌고 있다.
///
/// os_log 는 잠금 없는 링버퍼라 메인 스레드를 붙잡지 않고, 파일 쓰기도 수백
/// 바이트다. 배포판에 그대로 두고 쓸 만큼 싸다.
enum Diag {
    private static let log = Logger(subsystem: "com.satanclaous.min30", category: "flow")

    private static let lock = NSLock()
    private static var ring: [String] = []
    private static let cap = 40

    private static let clock: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    static var traceURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("min30-trace.log")
    }

    /// 앱이 죽고 나서 읽는다. 비어 있으면 아직 아무 일도 없었다는 뜻.
    static var trace: String { (try? String(contentsOf: traceURL, encoding: .utf8)) ?? "" }

    static func clearTrace() {
        lock.lock(); ring = []; lock.unlock()
        try? FileManager.default.removeItem(at: traceURL)
    }

    static func mark(_ what: String) {
        log.notice("▶︎ \(what, privacy: .public)")
        append("▶︎ " + what)
    }

    /// 시작과 끝을 짝지어 남긴다. 끝 줄이 없으면 거기서 멈췄거나 거기서 죽었다.
    static func span<T>(_ what: String, _ body: () throws -> T) rethrows -> T {
        let t0 = DispatchTime.now().uptimeNanoseconds
        log.notice("┌ \(what, privacy: .public)")
        append("┌ " + what)
        defer {
            let ms = Double(DispatchTime.now().uptimeNanoseconds - t0) / 1_000_000
            let tail = String(format: "%@ %.1fms", what, ms)
            log.notice("└ \(tail, privacy: .public)")
            append("└ " + tail)
        }
        return try body()
    }

    /// 크래시 직전 줄까지 디스크에 있어야 쓸모가 있으므로 그 자리에서 바로 쓴다.
    /// 큐에 넘기면 정작 마지막 한 줄을 잃는다 — 그 한 줄이 답인데.
    private static func append(_ line: String) {
        let stamped = clock.string(from: Date()) + "  " + line
        lock.lock()
        ring.append(stamped)
        if ring.count > cap { ring.removeFirst(ring.count - cap) }
        let snapshot = ring.joined(separator: "\n")
        lock.unlock()
        try? Data(snapshot.utf8).write(to: traceURL, options: .atomic)
    }

    @MainActor private static var counts: [String: Int] = [:]

    /// 화면은 굳었는데 프로세스는 살아 있으면 대개 뷰 갱신이 무한히 돈다.
    /// 매번 찍으면 로그가 잠기므로 N 번마다 한 줄만 남긴다 — 정상이면 몇 줄도
    /// 안 나오고, 루프가 돌면 폭포처럼 쏟아진다. 그 차이가 곧 진단이다.
    @MainActor static func beat(_ what: String, every n: Int = 200) {
        let c = (counts[what] ?? 0) + 1
        counts[what] = c
        if c % n == 0 { mark("↻ \(what) ×\(c)") }
    }
}
