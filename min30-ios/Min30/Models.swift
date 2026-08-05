import Foundation
import SwiftUI
import UIKit

// MARK: - 분류 (『원씽』 기준)

/// 게리 켈러의 『원씽』이 시간을 보는 방식을 그대로 옮긴 것.
///
/// 책의 핵심은 "많이 한 것"과 "성과를 만든 것"은 다르다는 것, 그리고 결과의
/// 대부분은 소수의 행동에서 나온다는 것. 그래서 분류 자체가 곧 임팩트 판정이
/// 된다 — 별도로 "이게 임팩트였나?" 를 다시 물을 필요가 없다.
///
/// 회복이 낭비와 분리돼 있는 것도 책을 따른 것이다. 켈러는 휴식을 먼저
/// 캘린더에 박아두라고 한다. 의도한 쉼은 성과의 반대가 아니라 조건이다.
enum Category: String, CaseIterable, Identifiable, Sendable {
    case onething   // 오늘 이것만 하면 나머지가 쉬워지거나 필요 없어지는 그 하나
    case leverage   // 성과로 이어지는 일. 그날의 원씽은 아니지만 20% 쪽
    case learn      // 미래의 레버리지를 만드는 투입
    case maintain   // 해야 하지만 성과를 만들지는 않는 80% — 메일, 행정, 잡무
    case recover    // 의도한 회복. 잠, 운동, 식사, 사람
    case waste      // 원치 않았는데 빨려 들어간 시간. 둠스크롤

    var id: String { rawValue }

    var title: String {
        switch self {
        case .onething: return "원씽"
        case .leverage: return "레버리지"
        case .learn:    return "배움"
        case .maintain: return "유지"
        case .recover:  return "회복"
        case .waste:    return "낭비"
        }
    }

    var blurb: String {
        switch self {
        case .onething: return "이것만 하면 나머지가 쉬워지는 그 하나"
        case .leverage: return "성과로 이어지는 일"
        case .learn:    return "나중에 레버리지가 될 인풋"
        case .maintain: return "해야 하지만 성과는 아닌 것"
        case .recover:  return "의도한 쉼 · 몸 · 사람"
        case .waste:    return "빨려 들어간 시간"
        }
    }

    var symbol: String {
        switch self {
        case .onething: return "target"
        case .leverage: return "arrow.up.right"
        case .learn:    return "book"
        case .maintain: return "tray.full"
        case .recover:  return "leaf"
        case .waste:    return "arrow.down.right"
        }
    }

    /// 색각이상 분리를 양쪽 모드에서 검증한 순서 — 임의로 섞지 말 것.
    var color: Color {
        switch self {
        case .onething: return Color(light: 0x2A78D6, dark: 0x3987E5)
        case .leverage: return Color(light: 0x1BAF7A, dark: 0x199E70)
        case .learn:    return Color(light: 0xEDA100, dark: 0xC98500)
        case .maintain: return Color(light: 0x4A3AA7, dark: 0x9085E9)
        case .recover:  return Color(light: 0x008300, dark: 0x008300)
        case .waste:    return Color(light: 0xE34948, dark: 0xE66767)
        }
    }

    /// 이 시간이 성과를 만들었나. 대시보드의 히어로 숫자가 이걸로 계산된다.
    var buildsImpact: Bool { self == .onething || self == .leverage }

    /// 예전 모델의 0…2 임팩트 필드와 호환시키기 위한 값.
    var legacyImpact: Int {
        switch self {
        case .onething, .leverage: return 2
        case .learn:               return 1
        case .maintain, .recover:  return 1
        case .waste:               return 0
        }
    }
}

/// 예전 8개 분류로 저장된 데이터를 조용히 받아준다. 이게 없으면 디코딩이
/// 통째로 실패해서 기록이 다 날아간다.
extension Category: Codable {
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "deep":                      self = .leverage
        case "shallow", "comm":           self = .maintain
        case "health", "rest", "social":  self = .recover
        default:                          self = Category(rawValue: raw) ?? .maintain
        }
    }
}

// MARK: - 자동 분류

enum AutoTag {
    /// 표현이 조금씩 달라도 걸리도록 공백과 대소문자를 지운다.
    static func norm(_ s: String) -> String {
        s.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
    }

    /// 키워드는 "포함" 으로 본다. 한국어는 조사가 붙어도 어간이 남기 때문에
    /// 접두 매칭보다 포함 매칭이 훨씬 잘 맞는다.
    ///
    /// 순서가 결과를 바꾼다. **낭비를 맨 마지막에 본다** — 낭비 키워드는 대부분
    /// 플랫폼 이름(유튜브·인스타)이고 나머지는 행동 이름(강의·개발·식사)이다.
    /// 무엇을 했는지가 어디서 했는지를 이겨야 "유튜브 강의 시청" 이 배움으로 잡힌다.
    /// 플랫폼 이름만 덩그러니 있으면 그때는 낭비가 맞다.
    static let keywords: [(Category, [String])] = [
        (.learn, [
            // "책" 단독은 금지 — "산책" 이 배움으로 잡힌다. 한글은 부분 문자열
            // 충돌이 잦아서, 짧은 낱말은 반드시 더 긴 형태로 적어야 한다.
            "공부", "학습", "study", "강의", "lecture", "course", "독서", "책읽", "read",
            "논문", "paper", "문서", "docs", "튜토리얼", "tutorial", "스터디", "세미나",
            "컨퍼런스", "conference", "리서치", "research", "조사",
        ]),
        (.leverage, [
            "개발", "코딩", "코드", "code", "dev", "빌드", "build", "구현", "리팩",
            "버그", "수정", "개선", "테스트", "디버", "배포", "deploy", "ship",
            "디자인", "design", "설계", "기획", "시안", "초안", "프로토타입",
            "글쓰기", "집필", "원고", "write", "제작", "편집", "촬영", "녹음",
            "영상", "콘텐츠", "content", "마케팅", "marketing", "세일즈", "영업",
            "sales", "제안", "피칭", "pitch", "투자", "심사", "출시", "앱스토어",
            "전략", "strategy", "작업", "만들", "분석", "실험",
        ]),
        (.maintain, [
            "이메일", "메일", "email", "메시지", "슬랙", "slack", "카톡", "답장", "회신",
            "reply", "정리", "잡무", "행정", "admin", "서류", "인보이스", "invoice",
            // "통화" 는 뺀다 — 업무 통화도 가족 통화도 되는 말이라, 넣어 두면
            // "가족과 통화" 가 유지로 잡힌다. 애매한 건 제안하지 않는 게 낫다.
            "정산", "세금", "회계", "미팅", "회의", "meeting", "콜", "call",
            "스탠드업", "standup", "청소", "빨래", "장보기", "은행", "예약", "문의",
            "고객", "cs", "지원", "support", "계획",
            // 이동은 회복이 아니다. 통근은 쉬는 게 아니라 치러야 하는 비용이다.
            "이동", "출근", "퇴근", "통근", "commute", "운전",
        ]),
        (.recover, [
            "휴식", "쉬", "낮잠", "잠", "수면", "sleep", "nap", "산책", "walk",
            "운동", "헬스", "gym", "요가", "yoga", "스트레칭", "러닝", "조깅",
            "명상", "meditat", "샤워", "목욕", "식사", "밥", "점심", "저녁", "아침",
            "lunch", "dinner", "breakfast", "커피", "coffee", "가족", "친구", "데이트",
            "약속", "사람", "대화", "rest",
        ]),
        (.waste, [
            "유튜브", "youtube", "인스타", "instagram", "틱톡", "tiktok", "릴스", "reels",
            "쇼츠", "shorts", "트위터", "twitter", "페북", "페이스북", "facebook",
            "레딧", "reddit", "커뮤니티", "디시", "스크롤", "scroll", "둠스크롤", "doomscroll",
            "눈팅", "알고리즘", "웹서핑", "서핑", "딴짓", "멍때", "뉴스", "news", "쇼핑",
            "넷플릭스", "netflix", "게임", "game",
        ]),
    ]

    /// 매칭이 없으면 유지로 둔다. 성과 쪽으로 기울여 두면 스스로를 속이게 되고,
    /// 낭비 쪽으로 기울여 두면 억울해진다. 유지가 가장 정직한 기본값이다.
    static let fallback: Category = .maintain

    /// 어차피 저녁 리뷰에서 한 번에 확인하므로, 여기서는 완벽할 필요가 없다.
    /// 손이 덜 가는 출발점이면 된다.
    static func classify(_ text: String) -> Category {
        let n = norm(text)
        guard !n.isEmpty else { return fallback }
        for (cat, words) in keywords where words.contains(where: { n.contains($0) }) {
            return cat
        }
        return fallback
    }
}

// MARK: - 기록

struct Entry: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var day: String          // 논리적 하루 "yyyy-MM-dd"
    var slot: Int            // 그 하루의 자정 기준 분 오프셋 (자정을 넘기면 1440 초과 가능)
    var activity: String = ""
    var category: Category?
    var energy: Int = 0      // 0 = 미입력, 1...5
    var focus: Int = 0
    var impact: Int = -1     // 예전 모델 호환용. 이제 분류에서 파생된다.
    /// 분류를 사람이 확인했나. 낮에 기록할 때는 자동 분류가 제안으로만 들어가고
    /// 이 값이 false 로 남는다. 저녁 리뷰에서 한 번에 확인하면 true 가 된다.
    /// 30분마다 분류를 결정하게 하면 결정 피로로 기록 자체를 안 하게 된다.
    var categoryConfirmed: Bool = false
    var note: String = ""
    var skipped: Bool = false
    /// 기록 당시의 블록 길이(분). 이걸 저장해 두지 않으면 나중에 간격을 바꿀 때
    /// 과거 기록이 통째로 다시 환산된다.
    var iv: Int?
    var createdAt = Date()
    var updatedAt = Date()

    var isLogged: Bool { !skipped && !activity.isEmpty }
    var buildsImpact: Bool { category?.buildsImpact ?? false }
}

// MARK: - 아이디어

enum IdeaStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case inbox, content, bank, vault, dropped

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inbox:   return "수집함"
        case .content: return "콘텐츠감"
        case .bank:    return "아이디어뱅크"
        case .vault:   return "창고"
        case .dropped: return "버림"
        }
    }

    var blurb: String {
        switch self {
        case .inbox:   return "아직 분류 안 함"
        case .content: return "글·영상으로 뽑을 것"
        case .bank:    return "더 키워볼 것"
        case .vault:   return "일단 보관"
        case .dropped: return ""
        }
    }
}

struct Idea: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var text: String
    var status: IdeaStatus = .inbox
    var day: String
    var slot: Int
    var fromPing: Bool = false
    var createdAt = Date()
}

// MARK: - 회고 · 설정

struct DayReview: Codable, Hashable, Sendable {
    var win = ""
    var cut = ""
    var next = ""

    var isEmpty: Bool { win.isEmpty && cut.isEmpty && next.isEmpty }
}

struct Settings: Codable, Sendable {
    var interval: Int = 30
    var dayStart: Int = 8 * 60
    var dayEnd: Int = 23 * 60
    var reviewAt: Int = 21 * 60 + 30
    var weekend: Bool = true
    var sound: Bool = true
    /// 자동 분류를 고쳤을 때 그 표현을 기억한다. 다음부터는 바로 맞춘다.
    var learned: [String: Category] = [:]

    /// 깨어 있는 창. 자정을 넘기면 끝을 24시간 뒤로 민다.
    var span: (start: Int, end: Int, wraps: Bool) {
        let s = dayStart
        var e = dayEnd
        let wraps = e <= s
        if wraps { e += 1440 }
        return (s, e, wraps)
    }

    enum CodingKeys: String, CodingKey {
        case interval, dayStart, dayEnd, reviewAt, weekend, sound, learned
    }

    init() {}

    /// 없는 키는 기본값으로 채운다. 합성된 디코더는 키가 하나만 빠져도
    /// 통째로 실패하는데, 그러면 설정 하나 늘리거나 줄일 때마다 사용자의
    /// 기록 전체가 날아간다.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings()
        interval = try c.decodeIfPresent(Int.self, forKey: .interval) ?? d.interval
        dayStart = try c.decodeIfPresent(Int.self, forKey: .dayStart) ?? d.dayStart
        dayEnd   = try c.decodeIfPresent(Int.self, forKey: .dayEnd) ?? d.dayEnd
        reviewAt = try c.decodeIfPresent(Int.self, forKey: .reviewAt) ?? d.reviewAt
        weekend  = try c.decodeIfPresent(Bool.self, forKey: .weekend) ?? d.weekend
        sound    = try c.decodeIfPresent(Bool.self, forKey: .sound) ?? d.sound
        learned  = try c.decodeIfPresent([String: Category].self, forKey: .learned) ?? [:]
    }
}

// MARK: - 라벨

enum Scale {
    static let energy = ["방전", "낮음", "보통", "좋음", "최상"]
    static let focus  = ["산만", "얕음", "보통", "깊음", "몰입"]
}

// MARK: - 헬퍼

extension Color {
    init(hex: Int) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    /// 실제로 쓰이는 배경에 맞춰 검증된 단계를 고른다.
    init(light: Int, dark: Int) {
        self.init(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(Color(hex: dark))
            : UIColor(Color(hex: light)) })
    }
}

enum Fmt {
    static func hhmm(_ minutes: Int) -> String {
        let m = ((minutes % 1440) + 1440) % 1440
        return String(format: "%02d:%02d", m / 60, m % 60)
    }

    static func hours(_ h: Double) -> String {
        h >= 1 ? String(format: "%.1fh", h) : "\(Int((h * 60).rounded()))m"
    }

    static let dayKey: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func pretty(_ dayKey: String) -> String {
        guard let d = Fmt.dayKey.date(from: dayKey) else { return dayKey }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 (E)"
        return f.string(from: d)
    }
}
