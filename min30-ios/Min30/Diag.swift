import Foundation
import os

/// 알림을 탭했을 때 앱이 굳는 문제를 실기기에서 추적하기 위한 흔적.
///
/// 멈춘 화면만 보고는 어디서 멈췄는지 알 수 없다. 이 로그는 맥에서
///
///     log stream --predicate 'subsystem == "com.satanclaous.min30"' --style compact
///
/// 로 실시간으로 볼 수 있고, Console.app 에서 기기를 골라도 보인다. 배너를 누른
/// 뒤 마지막으로 찍힌 줄이 곧 멈춘 지점이다.
///
/// os_log 는 잠금 없는 링버퍼에 쓰므로 메인 스레드를 붙잡지 않는다. 배포판에도
/// 그대로 두고 쓸 만큼 싸다.
enum Diag {
    private static let log = Logger(subsystem: "com.satanclaous.min30", category: "flow")

    static func mark(_ what: String) {
        log.notice("▶︎ \(what, privacy: .public)")
    }

    /// 시작과 끝을 짝지어 남긴다. 끝 줄이 없으면 거기서 멈춘 것이다.
    static func span<T>(_ what: String, _ body: () throws -> T) rethrows -> T {
        let t0 = DispatchTime.now().uptimeNanoseconds
        log.notice("┌ \(what, privacy: .public)")
        defer {
            let ms = Double(DispatchTime.now().uptimeNanoseconds - t0) / 1_000_000
            log.notice("└ \(what, privacy: .public) \(ms, format: .fixed(precision: 1))ms")
        }
        return try body()
    }

    @MainActor private static var counts: [String: Int] = [:]

    /// 화면은 굳었는데 프로세스는 살아 있으면 대개 뷰 갱신이 무한히 돈다.
    /// 매번 찍으면 로그가 잠기므로 N 번마다 한 줄만 남긴다 — 정상이면 몇 줄도
    /// 안 나오고, 루프가 돌면 폭포처럼 쏟아진다. 그 차이가 곧 진단이다.
    @MainActor static func beat(_ what: String, every n: Int = 200) {
        let c = (counts[what] ?? 0) + 1
        counts[what] = c
        if c % n == 0 { log.notice("↻ \(what, privacy: .public) ×\(c)") }
    }
}
