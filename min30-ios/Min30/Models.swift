import Foundation
import SwiftUI
import UIKit

// MARK: - 분류

/// The eight buckets a block can fall into. The colors are a categorical
/// palette validated for colorblind separation in both light and dark; the
/// order is part of that validation, so don't reshuffle it casually.
enum Category: String, CaseIterable, Codable, Identifiable, Sendable {
    case deep, shallow, comm, learn, health, rest, social, waste

    var id: String { rawValue }

    var title: String {
        switch self {
        case .deep:    return "몰입 작업"
        case .shallow: return "잡무 처리"
        case .comm:    return "회의·소통"
        case .learn:   return "학습·인풋"
        case .health:  return "운동·건강"
        case .rest:    return "휴식·회복"
        case .social:  return "관계·사교"
        case .waste:   return "낭비·산만"
        }
    }

    /// Light / dark steps chosen per mode — not an automatic flip.
    var color: Color {
        switch self {
        case .deep:    return Color(light: 0x2A78D6, dark: 0x3987E5)
        case .shallow: return Color(light: 0xEB6834, dark: 0xD95926)
        case .comm:    return Color(light: 0x1BAF7A, dark: 0x199E70)
        case .learn:   return Color(light: 0xEDA100, dark: 0xC98500)
        case .health:  return Color(light: 0xE87BA4, dark: 0xD55181)
        case .rest:    return Color(light: 0x008300, dark: 0x008300)
        case .social:  return Color(light: 0x4A3AA7, dark: 0x9085E9)
        case .waste:   return Color(light: 0xE34948, dark: 0xE66767)
        }
    }

    /// Tapping one tag should fill in a believable impact, still one tap from
    /// being corrected. Impact is the number this whole ledger exists for.
    var defaultImpact: Int {
        switch self {
        case .deep:  return 2
        case .waste: return 0
        default:     return 1
        }
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
    var impact: Int = -1     // -1 = 미입력, 0 낮음 / 1 보통 / 2 높음
    var note: String = ""
    var skipped: Bool = false
    var createdAt = Date()
    var updatedAt = Date()

    var isLogged: Bool { !skipped && !activity.isEmpty }
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

// MARK: - 태그 · 회고 · 설정

struct Tag: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var category: Category
}

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
    var quickMode: Bool = true
    var tags: [Tag] = Tag.starter

    /// The waking window, with the end pushed past midnight when it wraps.
    var span: (start: Int, end: Int, wraps: Bool) {
        let s = dayStart
        var e = dayEnd
        let wraps = e <= s
        if wraps { e += 1440 }
        return (s, e, wraps)
    }
}

extension Tag {
    /// Usable on day one; anything typed in 자세히 모드 joins this automatically.
    static let starter: [Tag] = [
        Tag(name: "개발", category: .deep),
        Tag(name: "기획·설계", category: .deep),
        Tag(name: "글쓰기", category: .deep),
        Tag(name: "이메일·메시지", category: .shallow),
        Tag(name: "잡무 처리", category: .shallow),
        Tag(name: "미팅", category: .comm),
        Tag(name: "통화", category: .comm),
        Tag(name: "공부·리서치", category: .learn),
        Tag(name: "운동", category: .health),
        Tag(name: "산책", category: .health),
        Tag(name: "식사", category: .rest),
        Tag(name: "휴식", category: .rest),
        Tag(name: "이동", category: .rest),
        Tag(name: "사람 만남", category: .social),
        Tag(name: "SNS", category: .waste),
        Tag(name: "유튜브", category: .waste),
    ]
}

// MARK: - 라벨

enum Scale {
    static let energy = ["방전", "낮음", "보통", "좋음", "최상"]
    static let focus  = ["산만", "얕음", "보통", "깊음", "몰입"]
    static let impact = ["낮음", "보통", "높음"]
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

    /// Picks the step that was validated against the surface actually in use.
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
