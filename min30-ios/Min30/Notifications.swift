import Foundation
import UserNotifications
import UIKit

/// Local notifications, scheduled by the OS. No server, no push certificate,
/// and — unlike the web — the notification itself can log a block: iOS wakes
/// the app in the background to run the action handler, so a tag button on the
/// lock screen writes straight to the store without ever opening the app.
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()

    private let center = UNUserNotificationCenter.current()

    /// iOS keeps at most 64 pending local notifications per app.
    private let pendingCap = 60

    private enum ID {
        static let pingCategory = "min30.ping"
        static let reviewCategory = "min30.review"
        static let repeatAction = "min30.repeat"
        static let ideaAction = "min30.idea"
        static let openAction = "min30.open"
        static let tagPrefix = "min30.tag."
    }

    // MARK: 권한

    func requestAuthorization() async -> Bool {
        center.delegate = self
        // `.timeSensitive` as an *authorization option* was deprecated in iOS 15 —
        // the level now comes from the entitlement plus the per-notification
        // `interruptionLevel` set in `content(...)`.
        let ok = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        if ok { await reschedule() }
        return ok
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func bootstrap() {
        center.delegate = self
    }

    // MARK: 카테고리 (알림 위에 뜨는 버튼)

    /// Rebuilt whenever the tag list changes, so the buttons on the lock screen
    /// are always the things you actually do.
    func registerCategories() {
        let store = Store.shared
        // 저장된 태그 목록이 아니라 실제로 최근에 적은 것들. 관리할 목록이
        // 따로 생기지 않고, 잠금화면 버튼이 늘 지금 하는 일을 가리킨다.
        let recent = store.recentActivities(limit: 3)

        var actions: [UNNotificationAction] = recent.map {
            UNNotificationAction(identifier: ID.tagPrefix + $0.name,
                                 title: $0.name,
                                 options: [])
        }
        actions.append(UNNotificationAction(identifier: ID.repeatAction, title: "직전과 동일", options: []))
        actions.append(UNTextInputNotificationAction(identifier: ID.ideaAction,
                                                     title: "아이디어 적기",
                                                     options: [],
                                                     textInputButtonTitle: "담기",
                                                     textInputPlaceholder: "지금 떠오른 것…"))

        let ping = UNNotificationCategory(identifier: ID.pingCategory,
                                         actions: actions,
                                         intentIdentifiers: [],
                                         options: [.customDismissAction])

        let review = UNNotificationCategory(
            identifier: ID.reviewCategory,
            actions: [UNNotificationAction(identifier: ID.openAction, title: "리뷰 열기", options: [.foreground])],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([ping, review])
    }

    // MARK: 예약

    func reschedule() async {
        Diag.mark("reschedule 시작")
        defer { Diag.mark("reschedule 끝") }
        Diag.span("registerCategories") { registerCategories() }
        center.removeAllPendingNotificationRequests()

        let s = Store.shared.settings
        let iv = max(5, s.interval)
        let span = s.span

        var requests: [UNNotificationRequest] = []

        if s.weekend {
            // Daily-repeating triggers never expire, so alarms keep firing even
            // if the app is never opened again. ~31 of them, well under the cap.
            for slot in Store.shared.slots {
                let ring = slot + iv
                requests.append(pingRequest(slot: slot, ring: ring, weekday: nil, date: nil))
            }
            requests.append(reviewRequest(minute: s.reviewAt, weekday: nil, date: nil))
        } else {
            // Weekday-only needs one trigger per (weekday × slot), which blows
            // past 64. So roll a concrete window instead and refresh it every
            // time the app runs — including the background launches that every
            // notification action causes.
            requests = weekdayWindow(span: span, interval: iv, reviewAt: s.reviewAt)
        }

        // 완료를 기다리지 않는다. 예약 31개를 메인 액터에서 순차로 await 하면,
        // 알림을 탭해 앱이 뜨는 순간(포그라운드 진입도 동시에 reschedule 한다)
        // 메인 액터가 그 사슬에 묶여 화면이 먹통처럼 보인다. add 는 실패해도
        // 다음 실행에서 다시 걸리므로 결과를 붙잡고 있을 이유가 없다.
        //
        // `withCompletionHandler:` 를 명시해야 콜백 버전이 잡힌다. 이 함수가
        // async 라 그냥 add(r) 이라고 쓰면 `async throws` 오버로드가 골라진다.
        for r in requests.prefix(pendingCap) {
            center.add(r, withCompletionHandler: nil)
        }
    }

    private func content(title: String, body: String, category: String, userInfo: [String: Any]) -> UNMutableNotificationContent {
        let c = UNMutableNotificationContent()
        c.title = title
        c.body = body
        c.categoryIdentifier = category
        c.userInfo = userInfo
        c.sound = Store.shared.settings.sound ? .default : nil
        // A 30-minute ledger is worthless if the ping arrives an hour late.
        // Breaking through Focus additionally needs the Time Sensitive
        // Notifications capability (Xcode → Signing & Capabilities → +).
        // Without it this is harmless — delivery is just normal priority.
        c.interruptionLevel = .timeSensitive
        c.relevanceScore = 1.0
        return c
    }

    private func pingRequest(slot: Int, ring: Int, weekday: Int?, date: Date?) -> UNNotificationRequest {
        let iv = Store.shared.settings.interval
        let c = content(
            title: "⏱ \(Fmt.hhmm(slot))–\(Fmt.hhmm(slot + iv))",
            body: "뭐 했어? 눌러서 기록하기",
            category: ID.pingCategory,
            userInfo: ["slot": slot]
        )
        var comps = DateComponents()
        comps.hour = (ring % 1440) / 60
        comps.minute = (ring % 1440) % 60
        if let weekday { comps.weekday = weekday }
        if let date {
            let d = Calendar.current.dateComponents([.year, .month, .day], from: date)
            comps.year = d.year; comps.month = d.month; comps.day = d.day
        }
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: date == nil)
        let id = date == nil ? "ping-\(slot)" : "ping-\(slot)-\(Int(date!.timeIntervalSince1970))"
        return UNNotificationRequest(identifier: id, content: c, trigger: trigger)
    }

    private func reviewRequest(minute: Int, weekday: Int?, date: Date?) -> UNNotificationRequest {
        let c = content(
            title: "🌙 하루 리뷰",
            body: "오늘 어디에 시간을 썼는지 5분만 돌아보기",
            category: ID.reviewCategory,
            userInfo: ["review": true]
        )
        var comps = DateComponents()
        comps.hour = (minute % 1440) / 60
        comps.minute = (minute % 1440) % 60
        if let weekday { comps.weekday = weekday }
        if let date {
            let d = Calendar.current.dateComponents([.year, .month, .day], from: date)
            comps.year = d.year; comps.month = d.month; comps.day = d.day
        }
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: date == nil)
        let id = date == nil ? "review" : "review-\(Int(date!.timeIntervalSince1970))"
        return UNNotificationRequest(identifier: id, content: c, trigger: trigger)
    }

    private func weekdayWindow(span: (start: Int, end: Int, wraps: Bool), interval: Int, reviewAt: Int) -> [UNNotificationRequest] {
        var out: [UNNotificationRequest] = []
        let cal = Calendar.current
        let now = Date()
        var dayOffset = 0
        while out.count < pendingCap && dayOffset < 10 {
            guard let day = cal.date(byAdding: .day, value: dayOffset, to: now) else { break }
            let wd = cal.component(.weekday, from: day)
            dayOffset += 1
            if wd == 1 || wd == 7 { continue }
            let midnight = cal.startOfDay(for: day)
            for slot in Store.shared.slots {
                let fireAt = midnight.addingTimeInterval(TimeInterval((slot + interval) * 60))
                guard fireAt > now.addingTimeInterval(60), out.count < pendingCap else { continue }
                out.append(pingRequest(slot: slot, ring: slot + interval, weekday: nil, date: fireAt))
            }
            let reviewFire = midnight.addingTimeInterval(TimeInterval(reviewAt * 60))
            if reviewFire > now, out.count < pendingCap {
                out.append(reviewRequest(minute: reviewAt, weekday: nil, date: reviewFire))
            }
        }
        return out.sorted { ($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? .distantFuture
            < ($1.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? .distantFuture }
    }

    func sendTest() {
        let slot = Store.shared.currentSlot()
        let c = content(title: "⏱ 테스트 알람", body: "이렇게 \(Store.shared.settings.interval)분마다 울려요",
                        category: ID.pingCategory, userInfo: ["slot": slot])
        let r = UNNotificationRequest(identifier: "test-\(UUID().uuidString)", content: c,
                                      trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false))
        center.add(r)
    }

    // MARK: 응답 처리

    /// Foreground: still show it. Missing a ping because the app happened to be
    /// open is exactly how a time ledger develops holes.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let action = response.actionIdentifier
        // userInfo 는 [AnyHashable: Any] 라 Sendable 이 아니다. 클로저 안으로
        // 들고 들어가면 Swift 6 에서 에러가 되므로, 필요한 값만 여기서 꺼낸다.
        let info = response.notification.request.content.userInfo
        let slot = info["slot"] as? Int
        let isReview = info["review"] as? Bool == true
        let text = (response as? UNTextInputNotificationResponse)?.userText

        Diag.mark("didReceive action=\(action)")

        await MainActor.run { Diag.span("didReceive.main") {
            let store = Store.shared
            // another background launch may have written since we last loaded
            store.reloadFromDisk()
            let day = store.logicalDay()
            let target = slot ?? store.currentSlot()

            switch action {
            case ID.ideaAction:
                if let text { store.addIdea(text, fromPing: true) }

            case ID.repeatAction:
                if let prev = store.previousEntry(day: day, before: target) {
                    store.put(day: day, slot: target) {
                        $0.activity = prev.activity
                        $0.category = prev.category
                        $0.energy = prev.energy
                        $0.focus = prev.focus
                        $0.impact = prev.impact
                        $0.skipped = false
                    }
                } else {
                    Router.shared.open(slot: target)
                }

            case let a where a.hasPrefix(ID.tagPrefix):
                // The whole point of going native: a lock-screen tap that
                // records the block without the app ever coming to the front.
                let name = String(a.dropFirst(ID.tagPrefix.count))
                let cat = store.autoClassify(name, day: day)
                let prev = store.previousEntry(day: day, before: target)
                store.put(day: day, slot: target) {
                    $0.activity = name
                    $0.category = cat
                    $0.impact = cat.legacyImpact
                    // energy/focus barely move in 30 minutes — carry them, and
                    // the review screen flags anything left unset
                    $0.energy = prev?.energy ?? 0
                    $0.focus = prev?.focus ?? 0
                    $0.skipped = false
                }

            case UNNotificationDefaultActionIdentifier:
                if isReview { Router.shared.openReview() }
                else { Router.shared.open(slot: target) }

            case ID.openAction:
                Router.shared.openReview()

            default:
                break
            }
        } }

        // 여기서 await 하지 않는다. iOS 는 이 async 메서드가 반환돼야 알림 처리가
        // 끝났다고 보는데, 탭으로 앱이 뜨는 중이라면 그 사이 앱이 응답 없는 것처럼
        // 보인다. 예약 갱신은 급하지 않으니 떼어 보낸다.
        Task { @MainActor in
            if !Store.shared.settings.weekend { await Notifier.shared.reschedule() }
        }
        Diag.mark("didReceive 끝")
    }
}

/// Lets a notification action steer the UI when the app does come forward.
@Observable
@MainActor
final class Router {
    static let shared = Router()
    var tab = 0
    var pendingSlot: Int?

    func open(slot: Int) {
        tab = 0
        pendingSlot = slot
    }

    func openReview() { tab = 2 }
}
